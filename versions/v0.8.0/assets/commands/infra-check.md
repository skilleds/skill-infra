---
description: schematize-infra — roda os gates de isolamento e observabilidade sobre o repo (unit hardened, container não-root, banco não publicado, liveness ≠ readiness, log sem PII, SLO escrito)
argument-hint: "[diretório]"
---

# /infra-check — os gates de isolamento e observabilidade

`references/isolamento.md` e `references/observabilidade.md` eram **normativa órfã**: os pisos 1 e 6
da skill, sem um comando ou gate que os exercitasse (achado da vistoria de 2026-08-21). Isto é o
gate.

```bash
bash .claude/skills/schematize-infra/scripts/check-isolamento.sh .
bash .claude/skills/schematize-infra/scripts/check-observabilidade.sh .
```

## Isolamento (`references/isolamento.md`)

Lê os artefatos **versionados** — systemd units, `Dockerfile`, `compose` — porque é onde a decisão
mora. **Reprova:** unit sem `User=` (roda como root) ou com `User=root`; unit sem
`NoNewPrivileges`/`ProtectSystem`/`PrivateTmp`/`ProtectHome`; `Dockerfile` sem `USER` ou com `USER
root`; banco/cache com `ports:` publicado no host — o furo clássico do compose de dev que virou
produção. **Avisa** sobre `CapabilityBoundingSet`/`RestrictAddressFamilies` ausentes, `read_only` e
`cap_drop` faltando, `HEALTHCHECK` ausente.

**Repo sem nenhum desses artefatos sai `2`, não `0`:** ausência de artefato não é conformidade — é
provisionamento à mão, que a §6 veta.

## Observabilidade (`references/observabilidade.md`)

**Reprova:** falta de liveness (`/healthz`) ou de readiness (`/readyz`); **readiness apontando para o
mesmo handler do liveness** — que é o healthcheck vacuamente verdadeiro: o orquestrador manda
tráfego para um processo que ainda não tem banco; PII/segredo dentro de chamada de log (`senha`,
`cpf`, `authorization`, `api_key`, `token`, número de cartão). **Avisa** sobre SLO não escrito (sem
objetivo não há error budget, e alerta sem budget vira ruído) e OpenTelemetry não configurado.

A detecção de PII é deliberadamente restrita à **chamada de log** — acusar o campo do DTO faria o
gate gritar em todo repo e treinar todo mundo a ignorá-lo.

## Revisão de entrega e acesso (pisos 22-24)

Além dos scripts, cobre à mão (`references/entrega.md` §8, `references/isolamento.md` §7):
**"SHA do git"** (deploy por SHA/tag verificado pelo ops, push feito, HEAD==origin) · **"IA sem ssh
mutável"** (nenhum `scp`/`rsync`/`tar|ssh`/`docker save|load` no repo, CI ou runbook; IA só com
bootstrap mínimo + ops) · **"ops com auditoria"** (allowlist tipada, dry-run, confirmação humana p/
destrutivo, log append-only, agente≠humano, kill-switch, rollback, leitura de banco só por query
nomeada). Violação é achado, não nota.

## Resiliência

O gate de `references/resiliencia.md` é o **`/infra-drill`** — restore provado, com canário e
cronômetro.

## Provas

`bash .claude/skills/schematize-infra/scripts/check-gates.test.sh` — 13 casos, 11 vermelhos de
propósito (User=root, unit sem hardening, Dockerfile sem USER, banco publicado, readiness apelido do
liveness, senha e `authorization` em log, e os dois casos de "não passa por vacuidade").
