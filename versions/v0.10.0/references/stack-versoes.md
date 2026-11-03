# Anexo volátil — versões de infraestrutura

> Parte da skill **schematize-infra**. **Fonte volátil:** número de versão, nome de recurso de
> provider e argumento deprecado mudam. O corpo normativo diz **princípio**; o número mora aqui,
> com data. O lint do catálogo (regra `anexo-volatil`) reprova versão cravada fora daqui.
>
> **Verificado em: 2026-08-21.** Cadência: **revisão trimestral**, e sempre antes de um release.
> Fontes: registry do Terraform, docs do provider, `endoflife.date`, release notes do Kubernetes.
>
> **Esta skill é a dona dos números de INFRA de todo o catálogo.** As skills de linguagem não
> devem repetir Kubernetes/Postgres/Redis/OTel nos anexos delas — apontam para cá.

## Plataforma

| Componente | Corrente (2026-08-21) | Nota de suporte |
|---|---|---|
| **Kubernetes** | **1.36** | ~3 minors recebem patch; a 1.30 está **EOL desde 2025**. Upgrade de control plane é tarefa agendada, não reação a incidente. |
| **PostgreSQL** | **18** (18.6) | 5 anos por major; a 19 está em beta. Major novo = ADR + plano de upgrade testado com restore. |
| **Redis** | **8.x** | atenção à **licença** desde a mudança de 2024 — se a allowlist da casa não aceita, o substituto (Valkey) é ADR. |
| **OpenTelemetry** | especificação **1.x estável** | SDK por linguagem tem cadência própria; o contrato (trace/metric/log correlacionados por `trace_id`) não muda. |

## Terraform / OpenTofu

> **Atenção:** os números de Terraform/OpenTofu e providers são mantidos pela `schematize-terraform`
> (`schematize-terraform → references/stack-versoes.md`, verificado em 2026-10-14: OpenTofu 1.13.x,
> Terraform 1.16.x). A tabela abaixo é do saneamento de 2026-08-21 e fica só como histórico do que
> motivou o piso do domínio de teste em rota nula.

| Item | Estado (2026-08-21) |
|---|---|
| **Terraform** | **1.15.x** |
| **Lock de state no backend `s3`** | **`use_lockfile = true`** (nativo). **`dynamodb_table` está DEPRECADO** — a doc o marca *"Optional, Deprecated"*. Bucket **com versionamento** é parte do piso: é o que permite recuperar state apagado. |
| **Provider Cloudflare** | **v5.x** (5.23.0). O recurso é **`cloudflare_dns_record`** (era `cloudflare_record` até a v4) e **`ttl` é obrigatório** (60–86400, ou 1 = automatic). |

> **Por que este bloco importa mais que os outros:** é aqui que mora o DNS do **domínio de teste em
> rota nula** (`references/iac-efeitos-externos.md`), que é o piso de efeito externo virando infraestrutura
> (ADR-0004). Um exemplo que não aplica — recurso da v4 com argumento da v5, sem o `ttl`
> obrigatório — falha no `plan`, e quem tenta seguir o piso desiste dele.

## A regra que NÃO é volátil

Rodar em versão **fora de suporte** é violação de cadeia de suprimentos, não dívida para depois;
mudança de **major** exige ADR; **restore testado** é o que define backup; pinning por **digest**,
nunca por tag móvel.
