---
description: schematize-infra — audita/scaffolda a IaC (declarativa, idempotente, revisável): plan-before-apply, drift detection, state seguro, layout /<app>/ + seed, e o <projeto>_ops como interface única (nada de mão no servidor)
argument-hint: "[dir de infra/ops, ex: <projeto>_ops | infra/]"
---

Audite/scaffolda a **Infra como Código** deste projeto (`references/iac.md`). Se a IaC é
Terraform/OpenTofu, o detalhe da ferramenta (state, módulos, pins, fluxo plan/apply, drift) é da
`schematize-terraform` (`/tf-review`, `/tf-plan`, `/tf-drift`); aqui fica a visão de plataforma. Princípio: **o que
não está em código não existe** — nada de mão no servidor. Alvo: `${ARGUMENTS:-<projeto>_ops}`.

## 1. Os três atributos (§1)
Verifique que a infra é:
- **Declarativa** (estado desejado — Terraform/OpenTofu, Helm, cloud-init), não script imperativo;
- **Idempotente** (aplicar N vezes = 1 vez; `plan` vazio num estado convergido; nada acumula);
- **Revisável** (mudança de infra por **PR + review + CI**, `plan` no PR mostra o diff; branch
  protegida em prd).
Achado: script que quebra na 2ª execução, recurso criado no console/`kubectl edit` na mão,
mudança de prd sem PR.

## 2. Plan-before-apply e state (§2-§3)
- `plan` **sempre** antes do `apply`; ler o diff é obrigatório; `apply` em prd **gated**.
- Alarme em `destroy`/`replace` de recurso com estado (banco/volume/IP) — pode ser **perda de
  dado**; investigue antes de aprovar.
- **State remoto, versionado, com lock**, cifrado (contém segredo); sem state local commitado, sem
  edição manual do state.

## 3. Drift detection (§4)
O mundo divergiu do git? Rode/agende a detecção (`terraform plan`, `driftctl`, reconciliação
GitOps). **A correção do drift é re-aplicar o código**, não editar de novo na mão; mudança manual
legítima **vira código**. Filesystem read-only em hml/prd; escrita = **break-glass auditado**.

## 4. Artefato imutável / GitOps (§5)
O git é a fonte da verdade do estado desejado; o cluster == o git. Deploy consome a **mesma imagem/
commit SHA** do CI (`/infra-deploy`). **Redeploy nasce do seed e é destrutivo na app, nunca nos
dados**; dado só muda por **migration reversível** (`down`+backup).

## 5. O `<projeto>_ops` é a interface única (§6)
**Toda** operação (provisionar/subir/atualizar/config/migrar/reverter/diagnosticar) passa por um
**comando do ops** — proibido `ssh`+ad-hoc, `kubectl edit`, `docker` na mão, script solto. Falta
comando? **cria no ops**. Verifique: superfície mínima idempotente com `--help` + saída
machine-readable, layout `/<app>/` + seed `/<app>/.env`, **instalação paralela** (`nproc`) e
**independência** (falha no paralelo = bug de independência, prioridade máxima), archive de cada
operação (§28).

## 6. Saída
Relatório de conformidade: declarativa/idempotente/revisável? plan-before-apply? state seguro?
drift sob controle? ops é a interface única? — cada achado com **o quê + onde + o conserto**. Grave
no `<projeto>_archive/`.
