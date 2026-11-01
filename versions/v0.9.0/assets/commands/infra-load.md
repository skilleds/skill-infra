---
description: schematize-infra — carrega à força TODO o corpo normativo (isolamento, IaC, entrega, segredos, observabilidade, resiliência) e passa a aplicá-lo
---

Carregue **à força** e passe a aplicar **integralmente** os Padrões de Infra/DevOps/SRE da Casa
(skill `schematize-infra`) neste projeto. A partir de agora, nesta sessão, isto **não é opcional**.

1. **Leia agora, na íntegra, TODOS os references** — não trabalhe de memória. Caminho:
   `.claude/skills/schematize-infra/references/*.md` (projeto) ou
   `~/.claude/skills/schematize-infra/references/*.md` (global):
   - `isolamento.md` — **isolamento por aplicação**: user Linux dedicado + systemd unit hardened +
     container não-root/read-only por serviço, blast radius mínimo, isolamento de rede
     deny-by-default, layout `/<app>/` + seed, provisionamento pelo ops (nunca à mão).
   - `iac.md` — **infra é código**: declarativa/idempotente/revisável, `plan` antes do `apply`,
     state seguro, **drift detection**, artefato imutável com proveniência git, o `<projeto>_ops`
     como interface única (100% das operações).
   - `entrega.md` — **CI/CD gated**: fluxo fixo de promoção, deploy **manual/gated** onde a casa
     exige (front/Vercel, prd), imagem de container (não-root/read-only/distroless/multi-stage/
     pinada por digest), estratégia + healthcheck gating + rollback, feature flags.
   - `segredos.md` — **gestão de segredos**: nunca no repo/layer/env commitado, cofre + rotação
     documentada + secret scan que trava, referência pelo seed, procedimento de vazamento (rotação
     imediata).
   - `observabilidade.md` — **LGTM+ integrado**: logs (sem PII) + métricas RED/USE + traços por
     `trace_id`, **SLO com error budget**, alertas versionados e acionáveis, healthchecks, trilha
     de auditoria imutável.
   - `resiliencia.md` — **backup & DR** (RPO/RTO, **restore testado**), rede/TLS/mTLS/hardening
     (deny-by-default, least-privilege), **cadeia de suprimentos** (SBOM/pinning/assinatura/SLSA),
     degradação graciosa.

2. **Confirme ao usuário** que leu (1 linha por arquivo).

3. Deste ponto, aplique como regra inegociável: **isolamento por app**, **deny-by-default e
   least-privilege**, **infra é código (nada de mão no servidor)**, **deploy gated onde a casa
   exige**, **segredo nunca no repo**, **observabilidade integrada**, **backup com restore
   testado**, **supply-chain (SBOM/pinning/assinatura)** e **tudo auditado**.

4. **Atualize o `CLAUDE.md` da raiz** com `assets/CLAUDE.md` da skill (mescla se já houver de outra
   skill) — é o `/infra-claude`.
