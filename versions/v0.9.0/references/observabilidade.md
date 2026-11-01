# Observabilidade — logs, métricas, traços, SLO e alertas (integrada, não posterior)

> Sistema que você não enxerga, você não opera — você reza. Todo serviço nasce com observabilidade
> **integrada de ponta a ponta**: logs estruturados, métricas RED/USE, traços correlacionados,
> **SLO com error budget** e alertas **versionados como código**. Nunca "a gente instrumenta
> depois". Este reference é o recorte de **infra** do §16 da `schematize-engineering`; o tema em si é da `schematize-observability`.

Um serviço só é **"pronto"** (§35) se expõe `/metrics`, emite logs estruturados e traces, e sobe
com **dashboard + alertas + chart** versionados junto do código. Observabilidade que não subiu com
o serviço não existe quando você precisa dela — às 3h da manhã, no incidente.

> **Gate:** `scripts/check-observabilidade.sh` (comando `/infra-check`) cobra liveness e readiness
> **distintos** (readiness que é apelido do liveness é healthcheck vacuamente verdadeiro), log sem
> PII/segredo e SLO escrito.

## 1. Stack, logs, métricas e tracing — são da `schematize-observability`

> **A dona do tema é a `schematize-observability`.** O padrão OpenTelemetry, os três sinais, a
> cardinalidade, a amostragem, o SLO/burn-rate, os dashboards e a stack de referência estão lá e
> **não são repetidos aqui**. Os pisos da base (§16): `schematize-engineering -> references/observabilidade.md`.

O que é **de infra**: a stack sobe **junto do serviço** (chart + dashboard + alertas na IaC, `iac.md`) e
é ela mesma um conjunto de serviços com isolamento, TLS entre componentes e backup do que importa
(`schematize-observability -> references/stack-referencia.md` §3); segredo em log é incidente de vazamento
(`segredos.md`); retenção de log é definida por tipo — log não é banco de dados
(`schematize-observability -> references/stack-referencia.md` §4).

## 5. SLO, error budget e alertas — o que a infra entrega

SLI/SLO por serviço em `/docs/slo.md`, error budget com freeze de feature e **alertas por burn-rate
multi-window, de sintoma de usuário, com `severity`, `for` e `runbook_url`** são normativos em
`schematize-observability -> references/slo-alertas.md` (gate `scripts/check-alertas.mjs`).
A infra entrega o **encanamento**: as regras versionadas na IaC junto do serviço, o roteamento do
Alertmanager por `severity` e por ambiente (hml não acorda ninguém), e o runbook de cada alerta
(`schematize-docs`) — **alerta que ninguém age vira ruído, e ruído esconde o alerta real**.

## 6. Healthchecks — o contrato com o orquestrador

Endpoints obrigatórios (o deploy/orquestração dependem deles — `entrega.md` §5): **`/health`**
(liveness; se falha, reinicia), **`/ready`** (readiness; se falha, **sai do balanceador** sem ser morto) e
**`/metrics`** (Prometheus). O desenho completo (liveness != readiness != startup, drenagem, o que cada um
checa) é de `schematize-observability -> references/healthchecks.md`. Aqui, o que é de infra: **probe,
período, timeout e limiar configurados na IaC/orquestrador**, readiness do fleet inteiro falhando vira
alerta, e matar o pod porque uma dependência piscou (liveness confundida com readiness) causa cascata.

## 7. Trilha de auditoria — imutável

Campos, append-only e retenção: `schematize-engineering → references/observabilidade.md` §16.6. Aqui: break-glass e
toda operação de infra pelo ops gravam rastro no archive (§28) — é evidência, não debug.

## 8. Metas de performance e FinOps

- **As metas padrão são da base**, não daqui: `schematize-engineering` -> `references/observabilidade.md`
  §30 ("Performance — Metas Padrão") tem a tabela (p95/p99, startup, tamanho de imagem), e metas
  específicas do serviço a sobrescrevem no `/docs/slo.md`. *Repetir os números aqui era ter a mesma
  tabela em dois lugares — e no dia em que um alvo mudar, um dos dois passa a mentir.*
- **FinOps** (SHOULD): custo por serviço/tenant, budget com alerta de threshold, revisão de
  overprovisioning, tags de billing consistentes na IaC, custo por request em serviço de alto
  volume. Observabilidade também mede **dinheiro**, não só latência.

## 9. Efeito externo — métrica de envio e alerta de reputação

Os **>5.000 e-mails** do incidente que originou o piso (`schematize-engineering` →
`references/efeitos-externos.md`) só existiram porque **nada estava contando**. Todo projeto que
envia qualquer coisa (e-mail, SMS/voz, push, webhook de terceiro, cobrança) instrumenta o envio e
**alerta na reputação**, que é o ativo que não tem undo:

- **Métrica obrigatória por envio** (real ou sinkado): `mail_sent_total{env,provider,template,
  status}`, `mail_bounce_total`, `mail_complaint_total` — com `run_id` e **hash** do destinatário.
  **Nunca o endereço em claro** no log/label (é PII — §2; e vira cardinalidade infinita).
- **Limiares da indústria** (SES/Resend/Postmark suspendem a conta acima deles): **bounce > 2%**
  e **complaint > 0,1%**. São **alerta crítico com runbook**, não painel pra olhar depois.
- **Envio real fora de `prd` é página imediata** — não existe volume "aceitável" de e-mail real em
  hml/dev. Também alerte o **contador da regra de firewall** que barra SMTP fora de prd
  (`iac-efeitos-externos.md` §7.3): tentativa bloqueada é sinal de bypass tentado.

```yaml
# ops/iac/alerts/efeitos-externos.yaml — versionado com o servico, como todo alerta
groups:
  - name: efeitos-externos
    rules:
      - alert: EnvioRealForaDeProducao
        expr: sum by (env) (increase(mail_sent_total{provider!="sink", env!="prd"}[5m])) > 0
        for: 0m
        labels: { severity: critical }
        annotations:
          summary: "e-mail REAL saindo de {{ $labels.env }} - parar o job e revogar a chave"
          runbook_url: "<projeto>_archive/runbooks/efeito-externo.md"
      - alert: BounceRateAcimaDoLimiar
        expr: sum(rate(mail_bounce_total[1h])) / sum(rate(mail_sent_total[1h])) > 0.02
        for: 15m
        labels: { severity: critical }
      - alert: ComplaintRateAcimaDoLimiar
        expr: sum(rate(mail_complaint_total[1h])) / sum(rate(mail_sent_total[1h])) > 0.001
        for: 15m
        labels: { severity: critical }
```

- **Runbook do alerta** (obrigatório, §5): **1)** matar o job/laço e **revogar a chave** — nessa
  ordem; **2)** medir enviados/bounce/complaint/spam trap no painel do provedor; **3)** acima do
  limiar, **pausar todo envio** daquele subdomínio e abrir ticket com o provedor **antes** que ele
  suspenda a conta; **4)** voltar por **warm-up** gradual, nunca no volume normal; **5)** o
  post-mortem (`schematize-incident`) fecha **com a camada implantada**, não com "combinamos de tomar cuidado".
- **Webhook de bounce/complaint do provedor** assinado e consumido (SNS/webhook) — é o que
  alimenta os contadores acima; sem ele, você descobre a reputação queimada pelo suporte.

> Regra de bolso: **se caiu e você foi olhar o dashboard, ele já tinha que estar lá.** Logs
> estruturados sem PII, RED/USE, traço correlacionado, SLO que define "funcionando", alerta que
> dói no usuário e aponta runbook, `/health` `/ready` `/metrics` sempre. Subiu com o serviço ou não
> subiu.
