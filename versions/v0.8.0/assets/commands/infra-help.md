---
description: schematize-infra — lista todos os comandos disponíveis e o que cada um faz
---

Liste os comandos do **schematize-infra** instalados (`/infra-*`), com 1 linha cada:

- `/infra-help` — esta lista.
- `/infra-deploy` — audita/planeja o deploy **GATED**: fluxo fixo (`dev local → teste local verde → GitHub → hml → prd`, nada pula etapa), artefato imutável com proveniência git, estratégia (rolling/blue-green/canary) + healthcheck gating + rollback automatizado; respeita o **manual/gated** onde a casa exige (ex.: front na Vercel, prd).
- `/infra-iac` — audita/scaffolda a **IaC** (declarativa, idempotente, revisável): `plan` antes do `apply`, drift detection, state seguro, layout `/<app>/` + seed, e o `<projeto>_ops` como interface única (nada de mão no servidor).
- `/infra-secrets` — audita a **gestão de segredos**: nada no repo/layer/env commitado, cofre + rotação documentada, secret scan que trava o merge, referência pelo seed; segredo achado no rastro → sinaliza **rotação imediata**.
- `/infra-drill` — **o restore que se prova**: restaura o backup num ambiente limpo, cronometra contra o RTO, confere RPO e **canário**, grava o relatório no archive. `--frescor` reprova o drill que envelheceu.
- `/infra-check` — os **gates** de isolamento e observabilidade sobre o repo (unit hardened, container não-root, banco não publicado, liveness ≠ readiness, log sem PII, SLO escrito).
- `/infra-load` — carrega à força TODO o corpo normativo (isolamento, IaC, entrega, segredos, observabilidade, resiliência) e passa a aplicá-lo.
- `/infra-claude` — cria ou mescla o `CLAUDE.md` sempre-on de infra na raiz do repo.
- `/infra-cc` — context compact: gera handoff no archive e roda `/compact`.
- `/infra-handoff` — gera o handoff (context.md + checklist.md) sem compactar.

Depois da lista, lembre a **regra de ouro**: *blast radius mínimo, tudo declarado, tudo auditado, deny-by-default.* Cada serviço roda **isolado** (user + systemd hardened + container não-root); toda infra é **código** (nada de mão no servidor); o deploy é **gated** onde a casa exige; **segredo nunca no repo**; **backup só conta com restore testado**. A infra fecha a porta; a `schematize-pentest` **prova** que fechou. Detalhe normativo em `references/` da skill `schematize-infra`; a base (ops §2, deploy §21, observabilidade §16, cadeia de suprimentos, archive §28) é a `schematize-engineering`.
