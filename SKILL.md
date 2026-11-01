---
name: schematize-infra
metadata:
  version: 0.8.0
description: >-
  Infra/SRE: isolamento por serviço, IaC, CI/CD gated, segredos, backup/DR, rede/TLS. Use ao operar infra, deploy, systemd unit, pipeline. Docker, Terraform, observabilidade: skills próprias.
---

<!-- cross-skill: dockerfile.md, supply-chain.md, runtime.md -> schematize-docker -->

# Infraestrutura/DevOps/SRE da casa (schematize-infra)

Disciplina normativa, **agnóstica de linguagem**, que responde a uma pergunta só: **este sistema
roda em produção com blast radius mínimo, tudo declarado e tudo auditado?** A casa não opera
servidor na mão. Cada serviço roda **isolado** (user Linux + systemd hardened + container), toda
mudança nasce de **código versionado** (IaC + artefato imutável), o deploy é **gated** onde a
casa exige, o segredo **nunca** mora no repo, e nada acontece fora do **`<projeto>_ops`** — o que
não está no ops/IaC **não aconteceu** e não é reproduzível.

É a contraparte de **operação** da engenharia: a `schematize-engineering` define *que* o ops é a
interface única (§2), *que* o deploy segue o fluxo fixo (§21) e *que* observabilidade é integrada
(§16); esta skill é o **como** dessas frentes de infra, com pisos que vetam o atalho ("editei
direto no prd", "botei o segredo no `.env` do repo", "o backup roda, nunca testei o restore").

**Versão:** skill `schematize-infra` v0.8.0. Changelog em `CHANGELOG.md`.

## Comandos (Claude Code)

Digite `/infra-help` pra ver todos. Em resumo:

| Comando | O que faz |
|---|---|
| `/infra-help` | lista todos os comandos do schematize-infra |
| `/infra-deploy` | audita/planeja o deploy **gated**: fluxo fixo (local→teste→git→hml→prd), artefato imutável com proveniência git, estratégia (rolling/blue-green/canary) + healthcheck gating + rollback; respeita o **manual/gated** onde a casa exige (ex.: front na Vercel) |
| `/infra-iac` | audita/scaffolda a **IaC** (declarativa, idempotente, revisável), verifica drift, plan-before-apply, state seguro e o layout `/<app>/` + seed do `<projeto>_ops` |
| `/infra-secrets` | audita a **gestão de segredos**: nada no repo/layer/env commitado, cofre + rotação documentada, secret scan que trava, referência pelo seed — sinaliza **rotação** se achar segredo vazado |
| `/infra-drill` | **o restore que se prova**: restaura o backup num ambiente limpo, cronometra contra o RTO, confere o RPO e o **canário**, grava o relatório no archive — e `--frescor` reprova o drill que envelheceu |
| `/infra-check` | roda os **gates** de isolamento e observabilidade sobre o repo (unit hardened, container não-root, banco não publicado, liveness ≠ readiness, log sem PII) |
| `/infra-load` | carrega à força TODO o corpo normativo (isolamento, IaC, entrega, segredos, observabilidade, resiliência) e passa a aplicá-lo |
| `/infra-claude` | cria ou mescla o `CLAUDE.md` sempre-on de infra na raiz do repo |
| `/infra-cc` | context compact: gera handoff no archive e roda `/compact` |
| `/infra-handoff` | gera o handoff (context.md + checklist.md) sem compactar |

Os comandos ficam em `assets/commands/` e são instalados em `.claude/commands/`.

## Artefatos executáveis

A vistoria de 2026-08-21 achou dois buracos que esta skill acusava nos outros: o piso 7 diz
*"backup cujo restore nunca foi provado não é backup — é esperança"* e **não havia drill**; e
`isolamento.md`/`observabilidade.md`/`resiliencia.md` — os pisos 1, 6 e 7 — eram **normativa órfã**,
sem comando nem gate. Agora:

| Artefato | Cobre | Reprova quando |
|---|---|---|
| `scripts/dr-drill.sh` | `resiliencia.md` §1 | sem backup · backup mais velho que o RPO · restore falhou · **canário ausente com restore "bem-sucedido"** · RTO estourado (medido em segundos, para que RTO=0 não passe) |
| `scripts/dr-drill.sh --frescor` | idem | nenhum relatório (restore **nunca** provado) · último drill velho demais · último drill reprovado |
| `scripts/check-isolamento.sh` | `isolamento.md` | unit sem `User=` ou com root · sem hardening · `Dockerfile` sem `USER` · banco com `ports:` publicado · **repo sem artefato nenhum** (exit 2) |
| `scripts/check-observabilidade.sh` | `observabilidade.md` | sem liveness/readiness · **readiness apelido do liveness** · PII/segredo em chamada de log |
| `scripts/dr-drill.test.sh` · `scripts/check-gates.test.sh` · `scripts/check-isolamento.test.sh` · `scripts/check-observabilidade.test.sh` | os gates | casos vermelhos plantados de propósito (um arquivo de teste por gate) |

## Como usar esta skill

1. **Isole antes de tudo** (`references/isolamento.md`): um user Linux + systemd hardened +
   container por serviço, nunca `root`, nunca dois serviços no mesmo user. Blast radius contido é
   pré-condição, não enfeite — casa com o isolamento do `<projeto>_ops` (ops.md §3 da engenharia).
2. **Declare, não digite** (`references/iac.md`): toda infra é código — declarativo, idempotente,
   revisável, com `plan` antes do `apply` e drift detection. Nada de mão no servidor; o servidor é
   **imutável por edição manual** e recebe só artefato promovido do git.
3. **Deploye pelo trilho** (`references/entrega.md`): o fluxo fixo `dev local → teste local verde
   → GitHub → hml → prd`, nada pula etapa; **deploy gated/manual** onde a casa exige (o front
   deploya manual na Vercel). Container não-root/read-only/distroless; healthcheck gating +
   rollback automatizado.
4. **Guarde o segredo fora** (`references/segredos.md`): nunca no repo, nunca em layer, nunca em
   `.env` commitado — cofre + rotação + secret scan que trava o merge.
5. **Enxergue o sistema** (`references/observabilidade.md`): logs/métricas/traços correlacionados,
   SLO com error budget, alertas versionados (o critério de "pronto" está no piso 6).
6. **Sobreviva ao desastre** (`references/resiliencia.md`): RPO/RTO definidos, **restore testado**;
   rede deny-by-default, TLS 1.2+/mTLS, hardening; supply-chain (SBOM + pinning + assinatura).
7. **Não trabalhe de memória** — os detalhes estão nos references. Aplique os pisos abaixo
   independentemente do reference carregado.

Mapa de references — leia o que casa com a tarefa:

| Tarefa | Reference |
|---|---|
| Isolamento por aplicação: user Linux dedicado + systemd hardened + container por serviço, blast radius, layout `/<app>/`, provisionamento pelo ops | `references/isolamento.md` |
| IaC declarativa/idempotente/revisável, plan-before-apply, state seguro, drift detection, artefato imutável, o ops como interface única (agnóstico de ferramenta; **OpenTofu e Terraform em si**, em paridade — estrutura, state, módulos, segredos, fluxo, testes — é da `schematize-terraform`) | `references/iac.md` · `schematize-terraform → references/fluxo.md` |
| CI/CD com deploy **gated/manual**, fluxo fixo de promoção, estratégia de deploy + healthcheck gating + rollback (a **imagem** — Dockerfile, BuildKit, compose, SBOM/assinatura, tag imutável — é da `schematize-docker`) | `references/entrega.md` |
| Gestão de segredos: nunca no repo/layer, cofre, rotação, secret scan, referência pelo seed, rotação em caso de vazamento | `references/segredos.md` |
| Observabilidade: logs/métricas/traços (RED/USE), SLO/error budget, alertas versionados, healthchecks, trilha de auditoria imutável | `references/observabilidade.md` |
| Backup & DR (RPO/RTO, restore testado), redes/TLS/mTLS/hardening (deny-by-default, least-privilege), cadeia de suprimentos (SBOM/pinning/assinatura/SLSA) | `references/resiliencia.md` |
| **Efeito externo fora de prd**: domínio de teste em rota nula (null MX/SPF/DMARC) em Terraform, subdomínio de envio por ambiente, egress SMTP bloqueado (SG/NACL/NetworkPolicy/nftables); **gate de máquina em `scripts/check-external-effects.sh`** (distribuído nesta skill, vermelho provado em `scripts/check-external-effects.test.sh`) | `references/iac-efeitos-externos.md` §7 |
| **Chave de provedor de envio por ambiente**: sandbox em não-prd, chave de prd inexistente fora de prd (policy do cofre) | `references/segredos.md` §7 |
| **Alerta de reputação**: métrica de envio, bounce > 2% / complaint > 0,1%, envio real fora de prd = página imediata | `references/observabilidade.md` §9 |

## Pisos inegociáveis (vetam o atalho)

Independente do reference, estes limites nunca são cruzados:

1. **Isolamento por aplicação.** Cada serviço roda **confinado**: um **user Linux dedicado** + um
   **systemd unit hardened** (`NoNewPrivileges`, `ProtectSystem=strict`, capabilities mínimas) +
   **container não-root/read-only**. **Nunca** `root`; **nunca** dois serviços no mesmo user.
   Blast radius contido é design, não sorte — um serviço comprometido não vaza para os vizinhos.
2. **Deny-by-default e least-privilege em tudo.** Rede (firewall/security group/network policy),
   IAM de nuvem, capabilities de container, permissão de filesystem, escopo de token de CI —
   tudo começa **fechado** e abre só o mínimo necessário, explícito e revisável. Regra ampla
   ("`0.0.0.0/0`", "`*` no IAM", token de admin no CI) é achado, não conveniência.
3. **Infra é código — nada de mão no servidor.** Toda infra é **declarativa, idempotente e
   revisável** (IaC + `<projeto>_ops`), com `plan` antes do `apply` e **drift detection**. O
   servidor é **imutável por edição manual**: recebe só **artefato promovido do git** (mesmo
   commit SHA). "Editei direto no prd pra resolver rápido" é o anti-padrão que esta skill mata.
4. **Deploy gated onde a casa exige.** O fluxo é fixo e sem atalho: `dev local → teste local
   verde → GitHub → hml → prd`. **Nada pula etapa**; nada vai direto pra hml/prd. Onde a casa pede
   **deploy manual/gated** (ex.: o front na Vercel), respeite o gate — urgência não autoriza
   mão no servidor; hotfix segue o mesmo trilho, acelerado.
5. **Segredo nunca no repo.** Nunca em código, nunca em layer de imagem, nunca em `.env`
   commitado, nunca `NEXT_PUBLIC_`/`ARG`/`ENV` persistido. Cofre (Vault / Secret Manager /
   sealed-secrets) + **rotação documentada** + **secret scan que trava o merge**. Segredo achado
   no rastro → **rotação imediata**, não "depois eu troco".
6. **Observabilidade integrada, não posterior.** Todo serviço nasce com logs estruturados,
   métricas (RED/USE), traços correlacionados por `trace_id`, **SLO com error budget** e alertas
   **versionados como código**. Sem `/metrics` + dashboard + alerta + chart, o serviço **não é
   "pronto"** (§35 da engenharia). PII/segredo **nunca** em log.
7. **Backup com restore TESTADO.** RPO/RTO **definidos** por dado; backup cujo **restore nunca
   foi provado não é backup** — é esperança. O restore é ensaiado periodicamente (game day / DR
   drill) e o resultado mora no archive. Migração de dado é **reversível** (`down` + backup).
8. **Cadeia de suprimentos é superfície de primeira classe.** Lockfile commitado, **SBOM
   versionado junto ao artefato**, scan que **trava** em `high`/`critical` sem ADR, imagem
   **pinada por digest** (`@sha256`, nunca `latest`), **assinatura verificada na admissão** (deploy
   só aceita imagem assinada por pipeline confiável). Você entrega tudo que embarca.
9. **Tudo auditado, saída durável no archive.** Toda operação de infra passa pelo `<projeto>_ops`
   e **grava rastro** (§28): quem, quando, de qual commit, com qual resultado. Operação sensível
   vai pra **trilha de auditoria imutável**. O que não está no ops/IaC **não aconteceu**.

10. **Efeito externo NUNCA sai de não-produção — e as camadas de infra são as que não dependem de
    ninguém lembrar.** O piso é da `schematize-engineering` (`references/efeitos-externos.md`, 4
    camadas); esta skill **é dona das camadas 1, 3 e 4**, e elas moram em **IaC**, não em combinado:
    **(1) DNS** — `test.<domain>` declarado com **null MX (RFC 7505: `MX 0 .`) + SPF `v=spf1 -all` +
    DMARC `p=reject`** (ou TLD reservado `.test`/`.invalid`/`.example`), **provado por `dig`** no CI/
    `ops doctor`; **(3) rede e segredo** — **egress SMTP 25/465/587/2525 bloqueado em dev/hml**
    (SG/NACL/NetworkPolicy/nftables, `reject` e não `drop`) e **chave sandbox** no seed de não-prd,
    com a **chave de prd inexistente fora de prd** (policy do cofre nega o path); **(4) provedor** —
    **subdomínio de envio separado por ambiente** (`mail.<domain>` em prd vs `mail-hml.<domain>` em
    hml, DKIM/SPF próprios na IaC) pra **isolar reputação**, mais **alerta** de bounce > 2% /
    complaint > 0,1% e de **envio real fora de prd** (página imediata). **VETADO** reusar o
    remetente de prd fora de prd, enviar pelo domínio raiz, e deixar o domínio de teste apontando pra
    caixa real. **Por quê:** bounce/complaint em massa **queima IP e domínio**, derruba o
    transacional de **produção** — inclusive o **OTP de login** — e custa **semanas de warm-up**,
    com utilidade zero. Não tem undo. Camada faltando é **bug de infra**, não descuido de quem rodou.
    Detalhe: `iac-efeitos-externos.md` §7, `segredos.md` §7, `observabilidade.md` §9.

11. **Tudo vai pro git; deploy SOMENTE do git (pisos 22-23 da `schematize-engineering`).** Sem remote
    acessível, push feito e `HEAD == origin`, a demanda não se conclui. **VETADO** `scp`, `rsync`,
    `tar|ssh`, `docker save|load` e editar remoto: o **ops, rodando na VPS**, clona/atualiza do git e
    verifica o **SHA/tag exato**. **Exceção ESCOPADA (piso 29):** na máquina de build/teste dev/hml
    (se o projeto tem) a ponte direta é permitida, só p/ build/teste e dentro do workspace remoto de
    build; o resultado **não é promovível**. Segue vetado: prd, promoção por ponte, dado/volume/
    `.env`/segredo de prd, efeito externo real. Detalhe: `entrega.md` §8 e §8.1.
12. **O ops é o GATE da IA (piso 24).** A IA não altera a VPS direto — exceto `unattended-upgrades`/
    `apt` e o mínimo (`git`) para clonar o ops; depois só conversa com o ops, por **operações
    nomeadas e tipadas**, sem SQL/script/comando mutável próprio e **sem ssh mutável**. O ops tem
    guardrails auditáveis, interface completa (logs, status, métricas, config mascarada, drift vs
    git, banco só-leitura por query nomeada) e, se falta comando, ele é **implementado no repo do ops
    via git**. Break-glass é humano e auditado, nunca da IA. O piso 29 **não alarga** este piso: a ponte é só na
    máquina de build/teste dev/hml. Detalhe: `isolamento.md` §7 e §7.1.

## Precedência e herança (leia antes de divergir)

<!-- herdado:engineering/precedencia:dominio intro="Esta skill é o recorte **infra/SRE** (isolamento, deploy gated, segredos, backup/DR) da `schematize-engineering`, agnóstico de linguagem: ela opera o serviço de qualquer stack do rol." cmd="infra" -->Esta skill é o recorte **infra/SRE** (isolamento, deploy gated, segredos, backup/DR) da `schematize-engineering`, agnóstico de linguagem: ela opera o serviço de qualquer stack do rol.

1. **Onde esta skill divergir da base, a BASE MANDA.** Aqui mora a especialização do domínio ou da
   ferramenta — o como, o padrão, o gate. Divergência de *piso* é defeito desta skill, não variante local.
2. **O que não está repetido aqui é HERDADO, não dispensado.** Esta skill herda os pisos da base e
   os comandos dela cobrem o **domínio**, não o piso geral. Valem integralmente, sem cópia local:
   - **§28 Archive** — `<projeto>/<projeto>_archive/` é **repositório git próprio, PRIVADO e
     obrigatório**, criticidade 0 (`schematize-archive`).
   - **§35 Definition of Done** e a lista de anti-padrões (citada por **título**, nunca por número).
   - **§39 Índice/MAPA** — enumeração exaustiva (uma entrada por unidade chamável, `M == N`) e grafo
     com arestas em ASCII (`A -> B`), nunca a seta unicode.
   - **IAM** (`schematize-engineering` → `references/iam.md`): identidade ≠ email, ≥2 fatores, ReBAC
     multi-tenant, argon2id-only para senha nova, sessão longa e logout irreversível.
   - **Efeito externo** nunca sai de não-produção (`schematize-engineering` →
     `references/efeitos-externos.md`).
   - **Orquestração** (`schematize-engineering` → `references/orquestracao.md` §9): o principal não
     desenvolve (é Claude Opus); executor mais barato que resolve — `haiku`/`sonnet` → Codex Terra → Cursor → `opus` só após falha; visual direto ao Codex; imagem nunca pelo Claude: detecta Codex/Gemini e pergunta ao usuário qual usar (Codex é a sugestão, não automática), nunca API paga.
3. **QA, ops, IAM e índice não têm comando próprio aqui:** vêm da base `/eng-*`. Para trabalho
   contínuo use `/eng-overdev`; para planejar `/eng-plan`; para varrer a base `/eng-scan`; para
   revisão geral `/eng-review` (e `/eng-ops`, `/eng-iam`, `/eng-index`). Os comandos
   `/infra-*` cobrem o domínio desta skill; o piso geral é o da base.<!-- /herdado -->

## Orquestração

<!-- herdado:engineering/orquestracao:curto -->**Orquestrador não desenvolve; subagent barato executa.** O agent principal só planeja, despacha e revisa; ação onerosa vira micro-tasks para o executor mais barato que resolve: `haiku` (mecânico) / `sonnet` (código; falhou → mesmo subagent corrige, até 2 rodadas) → Codex `gpt-5.6-terra` → Cursor → subagent `opus` (motivo) → `park`; **visual vai direto ao Codex**; **imagem nunca pelo Claude: detectar Codex/Gemini e perguntar ao usuário qual usar (Codex é a sugestão), nunca API de imagem paga**; papéis em `agentes.toml`. No overdev, cada item do checklist vai a um subagent e o principal revisa antes do `- [x]`. **Sem frota ociosa:** idle com pendência volta ao trabalho; dependente de outro agent → mata e enfileira com gatilho; terminou → mata (§9.6). Detalhe: `schematize-engineering` → `references/orquestracao.md` §9.<!-- /herdado -->

## Relação com as outras skills

- **schematize-engineering** — a **BASE**. Esta skill é o *como* de infra do que a engenharia
  normatiza: o **`<projeto>_ops` como interface única** e o **isolamento por usuário** (ops.md
  §2/§3), o **deploy e o fluxo de promoção** (operacao.md §21), a **observabilidade LGTM+** (§16),
  a **cadeia de suprimentos** (SBOM/pinning/assinatura) e o **archive** (§28). Onde a engenharia
  diz "o servidor é imutável por edição manual", esta skill diz **como** garantir isso.
- **schematize-docker** — a especialista do **artefato/imagem** e do **runtime de container**
  (Dockerfile, `.dockerignore`, BuildKit, compose de dev/hml, registry/tags, SBOM/provenance,
  cosign, scan, flags de runtime, rootless/Podman). Esta skill fica com o **onde e com quem a imagem
  roda** (user Linux + systemd, deploy gated, orquestração, cofre, observabilidade) e exige que o
  deploy consuma a imagem assinada por digest; `schematize-docker -> references/dockerfile.md`,
  `-> references/supply-chain.md`, `-> references/runtime.md`.
- **schematize-pentest** — o **oráculo** do hardening. A infra fecha a porta (deny-by-default,
  least-privilege, mTLS, container hardened); a pentest **prova** que fechou (SSRF, exposição de
  segredo, escalonamento, cross-tenant). Um hardening "revisei e tá seguro" sem teste que prove a
  rejeição é suspeita, não fato.
- **schematize-web / go / rust / elixir / c# / zig / ruby / node** — a infra é agnóstica: ela
  provisiona e opera o serviço **de qualquer stack**; a build e o gate de cada item rodam na
  linguagem daquele repo (`/<slug>-review`, testes, lint). O **front** tem regra própria de
  deploy **manual/gated** (Vercel), respeitada aqui.
