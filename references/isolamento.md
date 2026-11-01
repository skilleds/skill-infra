<!-- cross-skill: runtime.md, dockerfile.md, check-dockerfile.sh, check-compose.sh -> schematize-docker -->
# Isolamento por aplicação — blast radius mínimo por design

> A casa **não** roda dois serviços no mesmo saco. Cada serviço vive **confinado** — user Linux
> dedicado + systemd unit hardened + container não-root — para que um comprometimento não vaze
> para os vizinhos nem para o host. Este reference é o *como* do isolamento que a
> `schematize-engineering` (ops.md §3) exige; o control plane que o provisiona é o
> **`<projeto>_ops`** (`iac.md`).

Isolamento não é um enfeite de segurança que se liga depois: é **pré-condição** de rodar em
produção. O objetivo é **blast radius contido** — se o atacante ganha um serviço, ele mexe **só
naquele**, e os outros seguem protegidos. Defesa em profundidade por design.

> **Gate:** `scripts/check-isolamento.sh` (comando `/infra-check`) cobra este capítulo nos artefatos
> versionados — unit sem `User=` ou com root, sem `NoNewPrivileges`/`ProtectSystem`/`PrivateTmp`/
> `ProtectHome`, `Dockerfile` sem `USER`, banco publicado no host. E repo **sem nenhum artefato**
> sai `2`, não `0`: ausência não é conformidade, é provisionamento à mão (§6).

## 1. Um user Linux dedicado por serviço

- **Um usuário Linux por serviço/repo.** `payle_core` roda como user `payle_core`; `payle_storage`
  como user `payle_storage`. **Nunca** dois serviços no mesmo user; **nunca** `root`.
- A **pasta de cada repo pertence ao user do serviço** — isolamento a nível de usuário no
  filesystem. Um serviço não lê nem escreve o diretório do outro.
- User de serviço é **sem shell de login** (`/usr/sbin/nologin`) e sem `sudo`. Ele existe pra
  rodar o processo, não pra alguém entrar com ele.

## 2. Um systemd unit hardened por serviço

Cada serviço sobe por um **systemd unit isolado**, rodando como o user dedicado, com hardening
**explícito** (não default):

```ini
[Service]
User=payle_core
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
PrivateDevices=yes
ReadWritePaths=/payle/payle_core/var      # só o necessário
CapabilityBoundingSet=                    # zero capability por padrão
AmbientCapabilities=                      # concede só a que o serviço realmente precisa
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
SystemCallFilter=@system-service
MemoryMax=…  TasksMax=…                    # limite de recurso (evita um serviço derrubar o host)
```

- **`NoNewPrivileges`** — o processo nunca ganha privilégio (bloqueia setuid).
- **`ProtectSystem=strict` + `ProtectHome`** — o filesystem é read-only fora do `ReadWritePaths`
  mínimo; `/home` invisível.
- **`CapabilityBoundingSet=` vazio** — deny-by-default de capabilities; concede só o que o serviço
  exige (ex.: `CAP_NET_BIND_SERVICE` pra bindar porta < 1024, e olhe lá — prefira porta alta +
  proxy).
- **Limite de recurso** (`MemoryMax`, `TasksMax`, `CPUQuota`) — um serviço em loop não estrangula
  os vizinhos.

## 3. Container por serviço — ponteiro

Onde há container (o padrão), o mesmo princípio vale em outra camada (defesa em profundidade): não-root,
filesystem read-only, `no-new-privileges`, `drop ALL`, imagem mínima, **um serviço por container**.
A **configuração** do container e da imagem (Dockerfile, flags de runtime, limites, rootless) é da
**`schematize-docker`**: `schematize-docker -> references/runtime.md` e
`schematize-docker -> references/dockerfile.md`. Daqui continuam o **user Linux dedicado** e o
**unit systemd hardened** do host (§1–§2) — a docker não os substitui, e eles não substituem o
container não-root. O gate `scripts/check-isolamento.sh` segue cobrando `USER` e banco publicado;
`schematize-docker -> scripts/check-dockerfile.sh` e `schematize-docker -> scripts/check-compose.sh`
cobrem o resto da imagem e do compose.

## 4. Isolamento de rede — deny-by-default

Isolar processo sem isolar rede é meio isolamento:

- **NetworkPolicy / security group / firewall começa fechado.** O serviço só fala com quem
  **precisa** (banco daquele serviço, fila, o gateway) — nada de "aberto pra rede interna inteira".
- **Sem `0.0.0.0/0`** em ingress a não ser no ponto de entrada público (e mesmo esse atrás de
  WAF/proxy). Egress também restrito onde der (bloqueia exfiltração e SSRF de saída).
- **Egress SMTP (25/465/587/2525) bloqueado em dev/hml** — a camada de rede do piso "efeito externo
  nunca sai de não-produção": ela pega o bypass que o guard de aplicação não pega (script solto,
  `sendmail` do host, SDK chamado direto). `reject`, não `drop` (falha rápida e legível). Receita
  em IaC — NetworkPolicy/SG/NACL/nftables — em `iac-efeitos-externos.md` §7.3.
- **mTLS interno** entre serviços quando a malha permite (`resiliencia.md`) — identidade de
  serviço, não confiança por estar na mesma sub-rede.
- **Um banco/schema por serviço** — o serviço não alcança o dado do vizinho (casa com o
  isolamento de dados da arquitetura). Cross-service é por **API/evento**, nunca por tabela
  compartilhada.

## 5. Layout no servidor — `/<app>/` e o seed

Espelhando a contenção de workspace da engenharia (ops.md §2):

- **`/<app>/` é a raiz da aplicação no servidor.** O ops cria a pasta e clona os repos dentro:
  `/<app>/<app>_<contexto>` (ex.: `/payle/payle_core`, `/payle/payle_ops`). Nada de repo
  espalhado pelo host.
- **`/<app>/.env` é o seed global** — fonte única de config em runtime; **nenhum serviço tem
  config à parte**. Segredo real via cofre **referenciado** pelo seed, nunca versionado
  (`segredos.md`).
- **Redeploy é destrutivo na aplicação, do seed** (apaga o clone, recria do zero, idempotente) —
  **mas nunca destrói dados**. Apagar dado é comando separado e gated, só dev/hml (`iac.md`,
  `resiliencia.md`).

## 6. Provisionamento é do ops — SEMPRE, nunca à mão

- Criar o user, ajustar permissão da pasta, gerar o systemd unit hardened, aplicar a NetworkPolicy
  e fazer o wiring é **feito pelo `<projeto>_ops`** (`ops install`/`ops redeploy`) — **nunca à
  mão**. É parte do provisionamento, não um passo manual esquecível.
- **Falha no paralelo = bug de independência (prioridade máxima).** Se subir os serviços em
  paralelo (= `nproc`) quebra por race/porta/lock/ordem implícita, isso **prova** que os serviços
  não são independentes. O ops **expõe** a colisão; a correção real é feita (cada serviço sobe
  sozinho, com degradação graciosa) — **não** se serializa pra mascarar (ops.md §6).

## 7. Modelo de acesso da IA à VPS — piso 24 (`schematize-engineering`)

O ops é o **GATE da IA**. Normativa: `schematize-engineering` → `assets/CLAUDE.md` piso 24 e
`references/ops.md`; aqui está o que a infra provê.

- **A IA é VETADA de alterar a VPS diretamente**, com **duas exceções**: **(a)** atualizações
  automáticas do SO (`unattended-upgrades`/`apt`) e **(b)** instalar o **mínimo para rodar o ops**
  (`git`) e fazer o **`git clone` do ops**. Terminado o bootstrap, a IA conversa **só com o ops
  dentro da VPS**: usa **operações nomeadas e tipadas**; **nunca** escreve SQL, script ou comando
  mutável próprio. **Sem `ssh` mutável** para a IA.
- **Guardrails auditáveis do ops:** allowlist tipada e deny-by-default · dry-run/`plan` · confirmação
  humana para destrutivo · rate-limit/blast radius · escopo por ambiente · identidade
  **agente ≠ humano** · log **append-only** · kill-switch · rollback.
- **Interface completa (leitura):** `logs`, `status`/`health`, métricas, info de sistema, `config`
  com **segredo mascarado**, **drift vs git**, consulta de banco **SOMENTE-LEITURA** por queries
  **nomeadas** (nunca SQL livre). **Escrita:** `deploy`/`rollback`/`restart`/`migrate`/`backup`/
  `restore`/rotacionar segredo.
- **Falta comando → implementa no repo do ops, via git** (PR, review, deploy do ops por pull) —
  **nunca contorna por ssh**.
- **Break-glass humano** auditado existe (acesso de emergência, com registro de quem/por quê/quando);
  **nunca para a IA**. Uso gera achado e entra no postmortem.

### 7.1 Máquina de build/teste dev/hml — isolamento de recursos (piso 29)

A exceção do piso 29 vale **só** na máquina de build/teste dev/hml (não no ambiente de implantação,
onde o §7 segue integral; não em prd). Ponte direta (`rsync`/`scp`/`ssh`) é permitida só p/
build/teste, dentro do workspace remoto (ex.: `/var/tmp/schematize-build/<projeto>/`). Para que a
máquina não vire ponto cego nem derrube o vizinho:

- **Usuário dedicado de build** (ex.: `schematize-build`), sem shell de login interativo p/ humanos,
  sem sudo, **sem acesso a segredo, dado ou volume de prd** (a máquina não os tem; policy do cofre
  nega o path). Workspace próprio, `umask 077`; efeito externo real bloqueado (egress SMTP/PSP,
  piso 10).
- **Cgroups/systemd slices:** builds rodam em `build.slice` (ou `systemd-run --slice=build.slice
  --scope`) com `CPUQuota=` (ex.: 300%), `MemoryMax=`/`MemoryHigh=`, `IOWeight=` baixo (ex.: 50),
  `TasksMax=` — o build satura a fatia, não a máquina nem os serviços de dev/hml vizinhos.
- **Limpeza agendada:** `schematize-build-clean.service` + `.timer` (`OnCalendar=daily`,
  `Persistent=true`, `RandomizedDelaySec`) que roda **somente** a higiene do piso 29 (builds inúteis
  e caches; escopo = workspace + allowlist; nunca dado persistente), com `User=` de build e unit
  hardened (`ProtectSystem=strict`, `ReadWritePaths=` só o workspace). Política do projeto decide:
  **dry-run + aviso** (default; lista o que apagaria e o espaço liberável) ou **apply**. Mede disco
  antes/depois e registra no log/archive.
- **Alerta de disco > 80%** no filesystem do workspace (e de `/var/tmp`): alerta versionado
  (`observabilidade.md`) que dispara a limpeza em dry-run+aviso e pagina se persistir.
- Nada disso é artefato de deploy: a imagem/binário de lá não é promovível (`entrega.md` §8.1).

> Regra de bolso: **um serviço, um user, um unit hardened, um container não-root, uma fatia de
> rede.** Se um serviço cai comprometido, o estrago para nele. Isolamento é o que transforma "um
> serviço furado" em "um incidente contido" em vez de "o host inteiro é do atacante".
