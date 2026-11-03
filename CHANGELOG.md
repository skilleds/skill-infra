# Changelog — schematize-infra

Todas as mudanças relevantes deste pacote, no formato [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
com versionamento [SemVer](https://semver.org/lang/pt-BR/).


## [0.10.0] — 2026-11-03
### Corrigido
- P0-4 `references/resiliencia.md` §7: o exemplo de chaos deixou de usar `systemctl stop/start`; agora é
  experimento versionado executado por **operação tipada do ops** (`ops chaos run`) com `ttl`, allowlist,
  auditoria, kill-switch e abort automático; ponte direta só na máquina dev/hml de build (piso 29).
- P1-8 CI: `entrega.md`, `segredos.md`, `infra-drill.md`, `SKILL.md`, `assets/CLAUDE.md` e comandos trocam
  "CI constrói sozinho / trava o merge" por gate local por commit + "trava a promoção"; nova `entrega.md` §9
  com o gatilho padrão (`workflow_dispatch` + tags `hml-*`/`v*`, `concurrency`) e `check-ci-triggers.sh`.
- P1-9 novo `scripts/check-deploy-git.sh` (+ teste vermelho->verde): reprova scp/rsync/tar|ssh/docker
  save|load/ssh mutável em pipeline, Makefile, `*.sh` e blocos de código de runbook `.md`; delega ao gate da
  `schematize-engineering` (uma regra só; exit 2 se ausente).
- P1-10 `scripts/dr-drill.sh`: sem `eval`/`bash -c` (operações do ops como argv no JSON, schema `drill@2`);
  idade do backup por arquivo OU manifesto (pgBackRest/PITR/bucket); drill é `ops drill`; relatório com
  commit+push no archive (reprova se não publicar) e campo `custos`; 24 casos.
- P1-11 `resiliencia.md` §6: ponteiro ao piso 28 (`check-resilience.sh`, 7 testes, M == N); item de custos no
  relatório do drill.
- P1-12 `check-isolamento.sh` chama `check-dockerfile.sh`/`check-compose.sh` da `schematize-docker` quando
  presentes (mínimo local + aviso quando não); fixtures de teste ajustadas ao gate do docker.
- P2-1 cabeçalho `[0.7.1]` duplicado; P2-2 nota editorial removida de `entrega.md` §5.

### Adicionado
- Bloco herdado "Herda os pisos 22–29 da `schematize-engineering`" em `SKILL.md` e `assets/CLAUDE.md`.

## [0.9.0] — 2026-11-01
Alinha a skill ao piso 29 da `schematize-engineering` v0.34.0 (referenciado, não duplicado): máquina
de build/teste dev/hml com ponte direta ESCOPADA.

### Adicionado
- `references/entrega.md` §8.1: separa "máquina de build/teste dev/hml (ponte direta permitida)" de
  "ambiente de implantação (deploy só do git via ops)"; build por ponte não é artefato promovível;
  higiene obrigatória (dry-run por padrão, workspace+allowlist, disco antes/depois).
- `references/isolamento.md` §7.1: usuário de build sem segredo de prd, `build.slice` (CPUQuota/
  MemoryMax/IOWeight), timer systemd de limpeza (dry-run+aviso ou apply), alerta de disco > 80%.
- `/infra-deploy` §3c e `/infra-check` cobram "build testado na dev/hml quando existe", "higiene
  feita" e "artefato promovido vem do git, não do build por ponte".

### Alterado
- Pisos 11 e 12 (`SKILL.md`, `assets/CLAUDE.md`) citam a exceção escopada do piso 29, sem alargá-los
  e explicitando o que segue vetado (prd, promoção por ponte, dado/segredo de prd, efeito externo).

### Mantido
- Demais pisos, gates e scripts; `description` inalterada.

## [0.8.0] — 2026-10-31
Alinha a skill aos pisos 22-24 da `schematize-engineering` (referenciados, não duplicados).

### Adicionado
- `references/entrega.md` §8: tudo vai pro git (trava de conclusão) e deploy SOMENTE do git; VETADO
  `scp`/`rsync`/`tar|ssh`/`docker save|load`/editar remoto; o ops na VPS clona/atualiza e verifica SHA/tag.
- `references/isolamento.md` §7: modelo de acesso da IA à VPS (bootstrap mínimo + ops como gate),
  guardrails e interface completa do ops, falta de comando vira PR no repo do ops, break-glass humano.
- Pisos 11 e 12 em `SKILL.md` e `assets/CLAUDE.md`; `/infra-deploy` (§3b) e `/infra-check` cobram
  "SHA do git", "IA sem ssh mutável" e "ops com auditoria".

### Mantido (piso inalterado)
- Pisos 1-10, gates e scripts; `description` inalterada.

## [0.7.1] — 2026-10-14
Ponteiro para a skill nova `schematize-bots` (piso curto, sem duplicar).

### Alterado
- /infra-secrets cita token de bot.

## [0.7.0] — 2026-10-14
Fecha o gate da skill-dev e aponta para as irmãs novas.

### Adicionado
- `scripts/check-isolamento.test.sh` e `scripts/check-observabilidade.test.sh`: vermelho plantado por regra (unit sem `User=`/root/sem hardening, Dockerfile sem `USER`/root, banco com `ports:`, sem liveness/readiness, readiness apelido, PII em log) mais o fail-closed (exit 2). Motivo: gate sem vermelho visto é decoração.
- Blocos herdados `engineering/orquestracao` e `engineering/precedencia` no `SKILL.md` e `assets/CLAUDE.md`.

### Alterado
- `description` reduzida a <=190 caracteres (orçamento do catálogo).
- Ponteiros em vez de detalhe: backup/PITR de Postgres -> `schematize-postgres → references/backup-e-pitr.md`; resposta a incidente/postmortem -> `schematize-incident`; segredo commitado (purga, rotação) -> `schematize-git → references/segredos.md`. O piso fica aqui; o mecanismo mora na dona.

## [0.6.0] — 2026-10-14
Paridade OpenTofu/Terraform: a infra não prefere nenhuma das duas ferramentas.

### Alterado
- `references/iac.md` e `SKILL.md`: a escolha da ferramenta (OpenTofu e Terraform em paridade, uma por repo, sem default nem ADR obrigatório) é da `schematize-terraform`; o piso de state diz que state em claro é vetado nas duas (OpenTofu cifra no cliente; Terraform exige backend com KMS e acesso restrito). Motivo: decisão de paridade; o texto anterior nomeava só a criptografia do OpenTofu.

## [0.5.1] — 2026-10-14
A observabilidade ganhou dona (`schematize-observability`).

### Alterado
- Description reduzida (≤235 chars) para caber no orçamento de listagem de skills (soma ≤8300); mesmo território, fronteiras com as irmãs preservadas.
- `references/observabilidade.md` §1, §5 e §6 viram ponteiros para `schematize-observability` (padrão OTel, SLO/burn-rate, alertas com runbook, healthchecks); ficam só o encanamento de infra, §7, §8 e §9 (métrica e alerta de reputação de envio). Motivo: o mesmo tema vivia em quatro lugares com versões diferentes.

A skill nova `schematize-docker` passa a ser dona do artefato/imagem e do runtime de container.

### Alterado
- `references/entrega.md` §4 (imagem de container), `references/isolamento.md` §3 (container por serviço), `references/resiliencia.md` §5 (imagem/hardening) e `references/segredos.md` §1 (segredo em camada) viram **ponteiro** para `schematize-docker -> references/dockerfile.md`, `-> supply-chain.md` e `-> runtime.md`; ficam aqui só o user Linux + systemd do host, o deploy consumindo imagem assinada por digest e a verificação na admissão.
- `SKILL.md`: entrada da `schematize-docker` na "Relação com as outras skills" e no mapa de references.

Entrada pendente (sem bump): a IaC específica de Terraform/OpenTofu ganha dona.

### Alterado
- `references/iac.md`: o que era específico de Terraform/OpenTofu (backend `s3`, lock, criptografia, `state` manual, drift com `plan` agendado) virou princípio agnóstico de ferramenta + ponteiro para a nova `schematize-terraform` (`references/state.md`, `references/fluxo.md`). Mantido o que vale para qualquer ferramenta declarativa: declarativa/idempotente/revisável, plan-before-apply, state protegido, drift, GitOps, ops como interface única.
- `references/iac-efeitos-externos.md`: nota de fronteira (o piso de efeito externo fica aqui; o *como* escrever e aplicar o HCL é da `schematize-terraform`).
- `SKILL.md`, `assets/commands/infra-iac.md` e `references/stack-versoes.md`: ponteiros para a `schematize-terraform`; os números de Terraform/OpenTofu passam a ser mantidos lá.


## [0.5.0] — 2026-10-14
Gates com nome honesto, observabilidade sem duplicar a base, IaC dividido.

### Corrigido
- `scripts/check-infra.test.sh` não tinha `check-infra.sh` (testa `check-isolamento.sh` e `check-observabilidade.sh`): renomeado para `check-gates.test.sh`, referências atualizadas (`SKILL.md`, `assets/commands/infra-check.md`).
- `SKILL.md`: "sem /metrics + dashboard + alerta" repetido; agora uma vez (piso 6).
- `references/observabilidade.md`: stack LGTM, logs, RED/USE, tracing e auditoria viraram ponteiro para `schematize-engineering → references/observabilidade.md`; ficou o que é de infra (healthchecks, SLO/alertas, efeito externo).
- `references/iac.md` (295 linhas) dividido: o §7 (DNS/rede/SMTP como código) foi para `references/iac-efeitos-externos.md`, mantendo a numeração §7.x; links atualizados.
- `description` com 350 caracteres ou menos (era 1021).
- **Description** reduzida (~270 chars) para caber no orçamento de listagem (soma das 31 skills ≤ 8500; o Claude Code corta a listagem acima disso).
- `order` do `skill.toml` 16 → 24 (colidia com schematize-desktop).

### Alterado
- `scripts/check-external-effects{,.test}.sh` viram arquivos herdados da engineering (cabeçalho "herdado de schematize-engineering — não edite aqui"); conteúdo inalterado.

## [0.4.0] — 2026-08-21
Segunda leva do saneamento (inventário da vistoria).

### Corrigido
- **Kubernetes deixou de ser o ponto de partida.** `entrega.md` §5 dizia "Kubernetes + Helm" enquanto `isolamento.md` descrevia bare-metal/systemd como padrão. Agora a ordem é uma: o **default é o `<projeto>_ops` sobre systemd/container**, e K8s é **decisão com ADR** — *você troca "um systemd que você entende" por um plano de controle inteiro para manter, atualizar e depurar às 3h da manhã*. E ficou dito que a estratégia de deploy (rolling/blue-green/canário) **independe do alvo**, que era o que fazia as duas frases parecerem incompatíveis.
- **Tabela de metas de performance deixou de existir em dois lugares**: os números vivem na base (`schematize-engineering` §30) e esta skill aponta. *A mesma tabela em dois lugares significa que, no dia em que um alvo mudar, um dos dois passa a mentir.* (A duplicação geral, medida hoje bloco a bloco, é de **2/49** em `observabilidade.md` e **0/41** em `entrega.md` — bem menor que os ~60% estimados na vistoria.)

## [0.3.0] — 2026-08-21
Os dois buracos que esta skill acusava nos outros. A vistoria de 2026-08-21: o piso 7 diz *"backup cujo restore nunca foi provado não é backup — é esperança"* e **não havia drill**; `isolamento.md`, `observabilidade.md` e `resiliencia.md` — os pisos 1, 6 e 7 — eram **normativa órfã**, sem comando nem gate.

### Adicionado
- **`scripts/dr-drill.sh`** + **`/infra-drill`** — o DR drill executável: acha o backup, mede a **idade contra o RPO**, restaura num ambiente limpo, **cronometra contra o RTO** (em segundos — arredondar para minuto faria um RTO de 0 nunca ser estourado) e exige o **canário**. Grava `drill-<timestamp>.json` no archive. **Sem `comandos.verificar` não roda** (exit 2): *"o restore não deu erro"* é a esperança que o piso proíbe — restore que termina bem com o banco vazio é o caso que aparece de verdade.
- **`dr-drill.sh --frescor`** — o drill que envelheceu deixa de valer. Reprova em três estados, incluindo o mais fácil de confundir com "tudo certo": **nenhum relatório**, isto é, restore nunca provado.
- **`scripts/check-isolamento.sh`** e **`scripts/check-observabilidade.sh`** + **`/infra-check`** — os gates das duas normativas órfãs. Isolamento: unit sem `User=`/com root, hardening ausente, `Dockerfile` sem `USER`, banco com `ports:` publicado no host; **repo sem nenhum artefato sai `2`, não `0`** (ausência não é conformidade). Observabilidade: liveness e readiness ausentes ou **apontando para o mesmo handler** — o healthcheck vacuamente verdadeiro que manda tráfego para processo sem banco —, e PII/segredo dentro de chamada de log.
- **`scripts/dr-drill.test.sh` (14 casos)** e **`scripts/check-infra.test.sh` (13 casos)** — os vermelhos. O principal é o `restore-ok-canario-ausente`: exit 0 do comando de restore, dado que não voltou.
- **`assets/templates/drill.exemplo.json`** — os comandos são do projeto; a skill não conhece o banco, e não deve conhecer.

### Mudado
- `references/resiliencia.md` §1, `references/isolamento.md` e `references/observabilidade.md` abrem apontando para o gate que os executa.

## [0.2.0] — 2026-08-20

Propagação do piso **"efeito externo NUNCA sai de não-produção"** no recorte de INFRA: esta skill
assume as **camadas 1 (DNS), 3 (rede/segredo) e 4 (provedor)** da defesa em profundidade definida
na `schematize-engineering` (`references/efeitos-externos.md`) e as escreve como **IaC verificável**
— origem: um laço de teste disparou **>5.000 e-mails reais**, queimou reputação de IP/domínio e
derrubaria o **OTP de login** de produção.

### Adicionado
- **SKILL.md** — piso inegociável **10** ("Efeito externo NUNCA sai de não-produção — as camadas
  de infra"): DNS em rota nula provado por `dig`, egress SMTP bloqueado em dev/hml, chave sandbox
  por ambiente, subdomínio de envio separado e alerta de reputação; 3 linhas novas no mapa de
  references; menção ao piso na `description` do frontmatter.
- **references/iac.md** §7 — o *como* concreto: **Terraform/Cloudflare** do domínio de teste
  (**null MX `MX 0 .` RFC 7505 + SPF `v=spf1 -all` + DMARC `p=reject`**) com verificação por `dig`;
  **subdomínio de envio por ambiente** (`mail.<domain>` prd vs `mail-hml.<domain>` hml, DKIM/SPF
  próprios, sandbox/configuration set separados); **egress SMTP 25/465/587/2525 bloqueado** em
  dev/hml com receita para **NetworkPolicy (allowlist)**, **security group + NACL** e **nftables**
  (`reject` e não `drop`, com counter exportado); gate de prova das camadas.
- **references/segredos.md** §7 — **segredo por ambiente**: chave **sandbox** em não-prd, chave de
  prd **inexistente** fora de prd via policy do cofre (exemplo Vault), seed/`.env.example` sem
  credencial de provedor, regra de secret scan por prefixo (`SG.`/`re_`/`sk_live_`) e chave de prd
  em artefato de não-prd tratada como **incidente com rotação imediata**; extensão a PSP/SMS/push/
  webhook.
- **references/observabilidade.md** §9 — **métrica de envio e alerta de reputação**: contadores
  `mail_sent_total`/`mail_bounce_total`/`mail_complaint_total` (destinatário **hasheado**, nunca em
  claro), regras Prometheus prontas para **bounce > 2%**, **complaint > 0,1%** e **envio real fora
  de prd (página imediata)**, runbook de contenção (matar o job → revogar a chave → medir → pausar
  → warm-up) e consumo do webhook de bounce/complaint do provedor.
- **assets/CLAUDE.md** — piso sempre-on **10** com as quatro frentes de infra (DNS, rede, segredo,
  provedor) e os vetos.

### Mudado
- **references/isolamento.md** §4 — o egress deny-by-default agora nomeia explicitamente o
  **bloqueio de SMTP em dev/hml** (o bypass que o guard de aplicação não pega), apontando para
  `iac.md` §7.3.
- **references/entrega.md** §3 — config por ambiente passa a exigir **provider de efeito externo
  resolvido na composição** (sink por default fora de prd, chave sandbox, remetente separado);
  chave/remetente de prd nunca são promovidos junto com o artefato.

## [0.1.0] — 2026-08-15

Primeira versão da skill de **infra/DevOps/SRE** da casa — a disciplina de operar sistema em
produção com **blast radius mínimo, tudo declarado e tudo auditado**, deny-by-default, extraindo o
*como* de infra do que a `schematize-engineering` normatiza (ops §2/§3, deploy §21, observabilidade
§16, cadeia de suprimentos) pra rodar solta e agnóstica de linguagem.

### Adicionado
- **SKILL.md** com 9 pisos inegociáveis (isolamento por app, deny-by-default/least-privilege, infra
  é código/nada de mão no servidor, deploy gated onde a casa exige, segredo nunca no repo,
  observabilidade integrada, backup com restore testado, cadeia de suprimentos de primeira classe,
  tudo auditado) + mapa de references + relação com engineering/pentest.
- **references/**:
  - `isolamento.md` — isolamento por aplicação: user Linux dedicado + systemd unit hardened +
    container não-root/read-only por serviço, blast radius mínimo, isolamento de rede
    deny-by-default, layout `/<app>/` + seed, provisionamento pelo ops (nunca à mão).
  - `iac.md` — infra é código: declarativa/idempotente/revisável, plan-before-apply, state seguro,
    drift detection, artefato imutável com proveniência git, o `<projeto>_ops` como interface única.
  - `entrega.md` — CI/CD gated: fluxo fixo de promoção, deploy manual/gated onde a casa exige
    (front/Vercel, prd), imagem de container (não-root/read-only/distroless/multi-stage/pinada por
    digest), estratégia + healthcheck gating + rollback, feature flags, pipeline como TCB.
  - `segredos.md` — gestão de segredos: nunca no repo/layer/env commitado, cofre + rotação
    documentada + secret scan que trava, referência pelo seed, procedimento de vazamento (rotação
    imediata).
  - `observabilidade.md` — LGTM+ integrado: logs (sem PII) + métricas RED/USE + traços por
    `trace_id`, SLO com error budget, alertas versionados e acionáveis, healthchecks, trilha de
    auditoria imutável, metas de performance + FinOps.
  - `resiliencia.md` — backup & DR (RPO/RTO, restore testado), rede/TLS/mTLS/hardening
    (deny-by-default, least-privilege), cadeia de suprimentos (SBOM/pinning/assinatura/SLSA),
    degradação graciosa.
- **assets/commands/**: `/infra-help`, `/infra-deploy` (deploy gated), `/infra-iac` (IaC + ops),
  `/infra-secrets` (gestão de segredos), `/infra-load`, `/infra-claude`, `/infra-cc`,
  `/infra-handoff`.
- **assets/CLAUDE.md** — regra sempre-on: blast radius mínimo, tudo declarado, tudo auditado,
  deny-by-default.
