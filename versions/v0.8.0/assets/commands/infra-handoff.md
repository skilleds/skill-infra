---
description: Gera o handoff de contexto (context.md + checklist.md) no archive, SEM compactar
---

Gere o handoff da infra **sem** compactar — pra fim de sessão ou troca de tarefa:

1. `<projeto>_archive/context/<YYYY-MM-DD-HH-MM-SS>-context.md` — ambiente alvo (dev/hml/prd),
   artefato/commit em jogo, estado do provisionamento/deploy, drift detectado, achados de
   segredo/hardening, decisões de infra, onde parou.
2. `<projeto>_archive/context/<YYYY-MM-DD-HH-MM-SS>-checklist.md` — **FEITO vs EM ABERTO**
   (isolamento por app, IaC/drift, deploy gated, segredo fora do repo, backup+restore testado,
   observabilidade, supply-chain).

Não rode `/compact` — só arquiva.
