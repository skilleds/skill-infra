#!/usr/bin/env bash
# schematize-infra — gate de OBSERVABILIDADE (references/observabilidade.md).
#
# Tres coisas que o texto exige e que da para verificar no repo:
#  1. liveness e readiness EXISTEM e sao DIFERENTES (readiness que e apelido do liveness e o
#     healthcheck vacuamente verdadeiro: o orquestrador manda trafego para um processo que ainda
#     nao tem banco);
#  2. log nao carrega PII/segredo (secao 2);
#  3. existe SLO escrito — sem objetivo nao ha error budget, e sem error budget o alerta e ruido.
#
# uso: check-observabilidade.sh [dir]   ·   0 = passa · 1 = REPROVA · 2 = nada para checar
# EXCEÇÃO DECLARADA de strict mode (`schematize-shell` -> `references/piso.md` secao 1):
# este script é um COLETOR — ele varre tudo e SOMA os achados. Com `set -e` abortaria no
# primeiro problema e reportaria um, escondendo os outros. Por isso `set -uo pipefail` sem `-e`.
set -uo pipefail
raiz="${1:-.}"
erros=(); avisos=()
fontes=$(find "$raiz" -type f \( -name '*.go' -o -name '*.rs' -o -name '*.ts' -o -name '*.js' -o -name '*.py' -o -name '*.rb' -o -name '*.ex' -o -name '*.cs' \) \
  -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/target/*' -not -path '*/versions/*' 2>/dev/null)

if [ -z "$fontes" ]; then
  echo "✖ nenhum fonte encontrado em $raiz — nada para verificar." >&2
  exit 2
fi

live=$(grep -rlE '"/(healthz|livez|health/live|health)"|/healthz|/livez' $fontes 2>/dev/null | head -3)
ready=$(grep -rlE '"/(readyz|ready|health/ready)"|/readyz' $fontes 2>/dev/null | head -3)
[ -n "$live" ]  || erros+=("sem endpoint de LIVENESS (/healthz|/livez) — o orquestrador nao sabe reiniciar")
[ -n "$ready" ] || erros+=("sem endpoint de READINESS (/readyz) — sem ele o deploy manda trafego para processo que ainda nao subiu")

# Readiness que aponta para o MESMO handler do liveness: existe no papel, nao existe no efeito.
if [ -n "$live" ] && [ -n "$ready" ]; then
  for f in $ready; do
    dupla=$(grep -oE '(readyz|ready)"?\s*,\s*([A-Za-z_.]+)' "$f" | grep -oE '[A-Za-z_.]+$' | head -1)
    solo=$(grep -oE '(healthz|livez)"?\s*,\s*([A-Za-z_.]+)' "$f" | grep -oE '[A-Za-z_.]+$' | head -1)
    if [ -n "$dupla" ] && [ "$dupla" = "$solo" ]; then
      erros+=("${f#$raiz/}: readiness e liveness apontam para o MESMO handler ($dupla) — readiness que nao checa dependencia e healthcheck vacuamente verdadeiro")
    fi
  done
fi

# PII/segredo no log. Deliberadamente restrito a chamada de log, para nao acusar o campo do DTO.
pii=$(grep -rnEi '(log|logger|slog|tracing|Log)[A-Za-z.]*\.(info|warn|error|debug|Info|Warn|Error|Debug)\(.*\b(senha|password|cpf|cnpj|authorization|api[_-]?key|secret|token|cartao|card_number)\b' $fontes 2>/dev/null | head -10)
if [ -n "$pii" ]; then
  while IFS= read -r l; do erros+=("PII/segredo em log: ${l#$raiz/}"); done <<< "$pii"
fi

slo=$(find "$raiz" -type f \( -iname 'slo*.y*ml' -o -iname 'SLO.md' -o -iname 'slos.*' \) -not -path '*/.git/*' 2>/dev/null | head -1)
[ -n "$slo" ] || avisos+=("sem arquivo de SLO — sem objetivo escrito nao ha error budget, e alerta sem budget vira ruido")
grep -rqE 'OTEL_SERVICE_NAME|otel|OpenTelemetry|opentelemetry' "$raiz" --include='*.yml' --include='*.yaml' --include='*.env*' --include='*.toml' --include='*.go' --include='*.ts' 2>/dev/null \
  || avisos+=("nenhum sinal de OpenTelemetry configurado (stack LGTM+, secao 1)")

for a in "${avisos[@]:-}"; do [ -n "$a" ] && echo "  ! $a" >&2; done
if [ ${#erros[@]} -gt 0 ]; then
  echo "✖ observabilidade REPROVADA — ${#erros[@]} problema(s):" >&2
  for e in "${erros[@]}"; do echo "  · $e" >&2; done
  exit 1
fi
echo "✔ observabilidade: liveness e readiness distintos, log sem PII."
