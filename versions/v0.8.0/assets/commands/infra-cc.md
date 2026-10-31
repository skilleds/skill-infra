---
description: Context Compact — gera handoff (context.md + checklist.md) no <projeto>_archive e compacta
---

Antes de compactar, **arquive o handoff** (não perca o estado da infra):

1. `<projeto>_archive/context/<YYYY-MM-DD-HH-MM-SS>-context.md` — estado: o que está sendo
   provisionado/deployado, ambiente alvo (dev/hml/prd), artefato/commit em jogo, o que já subiu vs
   o que falta, drift/achados de segredo/hardening pendentes, decisões de infra, onde parou.
2. `<projeto>_archive/context/<YYYY-MM-DD-HH-MM-SS>-checklist.md` — **FEITO vs EM ABERTO**
   (isolamento aplicado? segredo fora do repo? deploy gated respeitado? restore testado? SBOM/
   assinatura? observabilidade subiu com o serviço?).
3. Só então rode `/compact` (foco na tarefa corrente).
