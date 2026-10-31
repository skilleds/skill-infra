---
description: schematize-infra — audita/planeja o deploy GATED: fluxo fixo (local→teste→git→hml→prd), artefato imutável com proveniência git, estratégia + healthcheck gating + rollback; respeita o manual/gated onde a casa exige (front/Vercel)
argument-hint: "[ambiente alvo, ex: hml | prd | front]"
---

Audite/planeje o **deploy** deste projeto (`references/entrega.md`). O deploy é **promoção de
artefato imutável por um trilho fixo**, gated onde a casa exige — **nunca** "subir o que está na
minha máquina". Alvo: `${ARGUMENTS:-(detecte pelo repo)}`.

## 1. Fluxo de promoção — fixo, sem atalho (§1)
Confirme o trilho `dev local → teste local verde → GitHub → hml → prd`. **Nada pula etapa**; nada
vai direto pra hml/prd. **VETADO editar código no servidor** — só artefato promovido do git (commit
SHA). Hotfix segue o mesmo trilho, acelerado. Ache e sinalize qualquer atalho ("deploy da branch
local", "editei no prd", "hml recebeu o que não passou no CI").

## 2. Gate manual onde a casa exige (§2)
- **Front → deploy manual/gated** (Vercel): disparado deliberadamente (CLI prebuilt / promoção
  manual), não em todo push. **Respeite o gate** — não "conserte" ligando auto-deploy.
- **prd → gated:** promoção com **aprovação humana** (environment protection); o CI constrói/testa,
  promover pede o portão. `apply` de IaC em prd também é gated. Verifique que o gate é **auditável**
  (quem aprovou, qual artefato/commit — no archive).

## 3. Artefato imutável com proveniência git (§3)
**Um** artefato (mesma imagem/commit SHA) atravessa hml→prd — **não rebuilda por ambiente**. A tag
inclui o commit; o deploy só aceita origem git. Build **só no CI**. Config por ambiente vem do
seed/cofre no deploy, **não** embutida na imagem.

## 3b. Deploy só do git, ops como gate (`entrega.md` §8, `isolamento.md` §7)
Cobre e reprova se faltar: **(a) SHA do git** — o deploy informa o SHA/tag exato e o ops, na VPS,
verifica; HEAD==origin e push feito (piso 22); **(b) vetado** `scp`/`rsync`/`tar|ssh`/`docker
save|load`/edição remota (piso 23) — grep no pipeline/scripts/histórico de comandos; **(c) IA sem
ssh mutável** — só bootstrap mínimo (`git`+clone do ops) e depois o ops; **(d) ops com auditoria** —
log append-only, agente≠humano, dry-run/plan, confirmação humana p/ destrutivo, kill-switch,
rollback (piso 24).

## 4. Imagem e orquestração (§4-§5)
- Imagem: **multi-stage**, base **pinada por digest** (`@sha256`, nunca `latest`), **não-root/
  read-only/`drop ALL`**, healthcheck; **SBOM** versionado, scan que trava, **assinada + verificada
  na admissão** (`references/resiliencia.md`).
- Estratégia por risco: rolling (default) / blue-green (crítico) / canary (alto impacto).
  **Healthcheck gating** (`/ready`) + **rollback automatizado** pós-falha (rollback = artefato
  anterior, nunca mão no servidor). Janela de validação (SLO não regrediu). Migração de schema
  **reversível** (`down`+backup), antes do serviço que a consome.

## 5. Saída
Relatório: o fluxo está íntegro? o gate manual é respeitado? artefato imutável/rastreável? imagem
hardened/pinada/assinada? healthcheck+rollback existem? — cada achado com **o quê + onde + o
conserto**. Grave no `<projeto>_archive/`. Toda operação passa pelo `<projeto>_ops` (`/infra-iac`);
o hardening de fato é provado pela `schematize-pentest`.
