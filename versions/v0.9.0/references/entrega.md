<!-- cross-skill: dockerfile.md, supply-chain.md -> schematize-docker -->
# Entrega — CI/CD gated, container e orquestração

> A casa promove software por um **trilho fixo** e, onde exige, **gated/manual**. Nada pula etapa,
> nada vai direto pro servidor, todo artefato é **imutável** e rastreável ao commit. Este
> reference é o *como* do fluxo de promoção da `schematize-engineering` (operacao.md §21) e da
> cadeia de suprimentos; a imagem/assinatura detalha em `resiliencia.md`.

O deploy não é "subir o que está na minha máquina". É **promover um artefato provado** por
estágios, com portão onde a casa quer olhar antes. A urgência não abre atalho — hotfix segue o
mesmo trilho, acelerado.

## 1. O fluxo de promoção — fixo, sem atalho

```
desenvolvimento local  →  teste local (verde)  →  GitHub (merge)  →  hml  →  prd
```

- **Nada pula etapa.** hml só recebe o que está no GitHub e passou no teste local; prd só recebe o
  que foi homologado em hml. Nunca direto pra hml/prd.
- **VETADO editar código direto no servidor (hml/prd).** O servidor é **imutável por edição
  manual** (`iac.md`) — recebe só **artefato promovido do git** (mesmo commit SHA). "Editei direto
  no prd" é o anti-padrão que o trilho existe pra matar.
- **Hotfix segue o mesmo fluxo, acelerado:** branch → teste local → git → hml → prd. Urgência
  **não** autoriza mão no servidor.

## 2. Deploy GATED/manual onde a casa exige

Nem todo deploy é automático — a casa **gateia** onde quer controle:

- **O front deploya manual/gated** (Vercel): o deploy é disparado **deliberadamente** (CLI
  prebuilt / promoção manual), não em todo push. Respeite o gate — é decisão da casa, não fricção
  a "consertar" ligando auto-deploy.
- **prd é sempre gated:** promoção com **aprovação humana** (environment protection do GitHub
  Actions, approval no pipeline). O CI **constrói e testa** sozinho; **promover pra prd** pede o
  portão.
- **`apply` de IaC em prd é gated** (`iac.md`): plan revisado → aprovação → apply.
- O gate é **auditável**: quem aprovou, qual artefato, qual commit — no archive.

## 3. Artefato imutável com proveniência git

- **Um artefato, todos os ambientes.** A **mesma imagem/commit SHA** que passou no CI vai pra hml
  e depois pra prd — não se rebuilda por ambiente (rebuild = artefato diferente = teste inválido).
- **Proveniência:** a tag da imagem **inclui o commit**; o deploy só aceita artefato com **origem
  git** (SHA). Build **só no CI**, nunca na máquina do dev pra produção (`resiliencia.md` §
  supply-chain).
- **Config por ambiente vem do seed/secret manager** no deploy, não embutida na imagem — a imagem
  é a mesma; o que muda é a config injetada (`segredos.md`, `iam` do ambiente).
- **Provider de efeito externo é config de AMBIENTE, resolvida uma vez na composição:** fora de
  `prd` o default é o **sink** (`MAIL_PROVIDER=sink`), com chave **sandbox** e **subdomínio de
  envio separado** — nunca a chave/remetente de prd promovidos junto com o artefato. Detalhe e IaC
  em `iac-efeitos-externos.md` §7 e `segredos.md` §7; a normativa é a `schematize-engineering`
  (`references/efeitos-externos.md`).

## 4. Imagem de container — ponteiro

A imagem (Dockerfile, multi-stage, base mínima pinada por digest, não-root, `.dockerignore`, cache e
segredo de build pelo BuildKit), o SBOM/provenance, o scan que trava, a assinatura cosign e a tag
imutável = sha do git são da **`schematize-docker`**: `schematize-docker -> references/dockerfile.md`
e `schematize-docker -> references/supply-chain.md`. Esta skill cobra o que fica do lado da
entrega: o deploy consome **só** a imagem assinada, por **digest**, promovida do CI, e **verifica a
assinatura na admissão** (`resiliencia.md`).

## 5. Orquestração e estratégia de deploy

**O default da casa é `<projeto>_ops` sobre systemd/container, em servidor próprio** — é o que
`isolamento.md` §2 e §5 descrevem (user Linux por serviço, unit hardened, layout `/<app>/`,
provisionamento 100% pelo ops). **Kubernetes + Helm** é uma **decisão com ADR**, não o ponto de
partida: ele paga quando há **escala horizontal real, muitos serviços e time que opera o cluster** —
e cobra caro quando é adotado por um punhado de serviços, porque você troca "um systemd que você
entende" por um plano de controle inteiro para manter, atualizar e depurar às 3h da manhã.

*(As duas frases desta skill divergiam: aqui se fixava "Kubernetes + Helm" e lá se descrevia
bare-metal/systemd como padrão. A ordem agora é uma só — e ela vale para as duas leituras: **a
estratégia de deploy abaixo independe do alvo**.)*

A estratégia casa com o risco:

| Estratégia | Quando usar |
|---|---|
| Rolling update | Default para serviços comuns |
| Blue/green | Serviços críticos, rollback instantâneo necessário |
| Canary | Mudanças de alto impacto, rollout gradual com observação |

- **Healthcheck gating:** tráfego só vai pra pod **ready** (`/ready`); pod que não fica pronto não
  recebe request (`observabilidade.md` §healthchecks).
- **Rollback automatizado quando o healthcheck falha pós-deploy** — e rollback manual sempre à
  mão de um comando (`ops rollback`). Rollback é **artefato anterior** (imutável), não "reverte na
  mão".
- **Janela de validação** antes de declarar o deploy bem-sucedido (SLO/erro não regrediu).
- **Migração de schema é reversível** (`down` + backup) e roda **antes** do serviço que a consome,
  como dependência declarada no grafo de deploy (`resiliencia.md`, `iac.md`).

## 6. Feature flags — desacoplar deploy de release

- **Deploy ≠ release.** Código pode subir desligado atrás de flag e ser **ligado** depois
  (rollout por %, segmentação por tenant, **kill switch**, expiração da flag).
- Obrigatório pra **features críticas, migrações e rollouts graduais** — reduz o risco de cada
  deploy e dá reversão instantânea sem novo deploy.

## 7. Pipeline como base de confiança (TCB)

- **Build e teste no CI** (GitHub Actions), a partir do código versionado. O pipeline **é parte da
  base de confiança** — trate-o como produção.
- **Permissões mínimas no CI:** token escopado, sem segredo amplo; segredo via mecanismo efêmero,
  **nunca** em log de build (`segredos.md`). Secret scan + SAST + SCA + container scan travando o
  merge em `high`/`critical` (`resiliencia.md` § supply-chain).
- **Cada deploy grava rastro** no archive (§28): commit, artefato, quem aprovou, resultado.

## 8. Deploy SOMENTE do git — pisos 22 e 23 (`schematize-engineering`)

Base normativa: `schematize-engineering` → `assets/CLAUDE.md` pisos 22-24 e `references/ops.md`.

- **Piso 22 — tudo vai pro git.** Sem remote acessível (GitHub/GitLab/similar), sem push feito e
  sem `HEAD == origin/<branch>`, **a demanda não se conclui** (trava de conclusão). Código que só
  existe na máquina não tem como ser deployado.
- **Piso 23 — o deploy nasce do git, nunca da máquina.** **VETADO** enviar código da máquina para a
  VPS: `scp`, `rsync`, `tar | ssh`, `docker save | load`, editar remoto. Quem **clona/atualiza a
  partir do git** é o **`<projeto>_ops` rodando na própria VPS**, e ele **verifica o SHA/tag
  exato** (o que o gate aprovou) antes de subir; SHA diferente do pedido = aborta. Deploy,
  `redeploy`, `update` e `rollback` (artefato/SHA anterior) são operações nomeadas do ops.
- Hotfix idem: branch → git → ops puxa. "Copiei o arquivo pra lá" é o anti-padrão.

### 8.1 Máquina de build/teste dev/hml × ambiente de implantação — piso 29

Dois papéis que não se misturam (base: `schematize-engineering` piso 29 e `references/ops.md`):

| | **Máquina de build/teste (dev/hml)** | **Ambiente de implantação** |
|---|---|---|
| Existe se | o projeto TEM máquina dev e/ou hml (**hml**, não staging) | sempre (hml/prd) |
| Ponte direta (`rsync`/`scp`/`ssh`) | **PERMITIDA**, só p/ build/teste, só no workspace remoto de build (ex.: `/var/tmp/schematize-build/<projeto>/`) | **VETADA** (pisos 23-24) |
| Deploy/promoção | **nunca sai daí** | **só do git**: `commit+push` + build limpo do git via ops |
| Agente | EVITA buildar local; usa essa máquina p/ build e teste de tudo que for possível | só conversa com o ops |

- Sem máquina dev/hml, o build é local. **NUNCA prd** como máquina de build.
- O que foi construído por ponte **NÃO é artefato promovível**: promoção a hml/prd = commit+push +
  build limpo do git, feito pelo ops (pisos 23/24). Imagem, binário ou tarball vindos da ponte
  não entram em `deploy`/`promote`.
- Continuam vetados lá: dado/volume/`.env`/segredo de prd e efeito externo real.
- **Higiene após cada ciclo (local e remoto):** apagar builds inúteis e caches — **dry-run por
  padrão**, escopo = workspace + allowlist, **nunca** dado persistente — medindo disco antes/depois.
  O isolamento e a limpeza agendada da máquina estão em `isolamento.md` §7.1.

> Regra de bolso: **promova, não copie.** Um artefato imutável, provado no CI, sobe por estágios
> com portão onde a casa quer olhar (prd, front). Nada pula etapa; nada é editado no servidor;
> rollback é voltar pro artefato anterior — nunca mexer na mão.
> E o artefato **só chega ao servidor por pull do git feito pelo ops** — nunca por push da máquina.
