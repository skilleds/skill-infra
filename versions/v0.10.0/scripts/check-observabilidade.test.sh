#!/usr/bin/env bash
# check-observabilidade.test.sh — o VERMELHO VISTO do gate de observabilidade.
# Planta cada violação num diretório temporário e exige o exit esperado.
# EXCEÇÃO DECLARADA de strict mode (`schematize-shell` -> `references/piso.md` secao 1):
# harness de teste roda sem `-e` de propósito — precisa continuar depois de um caso vermelho
# para reportar TODOS, em vez de parar no primeiro.
set -uo pipefail
G="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-observabilidade.sh"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
rc=0; n=0
caso() { # nome esperado dir [padrão]
  local nome="$1" esp="$2" dir="$3" pad="${4:-}" out z
  out=$(bash "$G" "$dir" 2>&1); z=$?; n=$((n+1))
  if [ "$z" -eq "$esp" ] && { [ -z "$pad" ] || grep -q -- "$pad" <<<"$out"; }; then echo "  ✔ $nome (exit $z)"
  else echo "  ✖ $nome: esperava $esp, veio $z: $out"; rc=1; fi
}

echo "── limpo passa"
d="$W/limpo"; mkdir -p "$d"
printf 'mux.HandleFunc("/healthz", liveH)\nmux.HandleFunc("/readyz", readyH)\nlog.Info("pedido criado", "id", id)\n' > "$d/main.go"
caso "liveness e readiness distintos" 0 "$d" "distintos"

echo "── vermelhos plantados"
d="$W/semready"; mkdir -p "$d"; printf 'mux.HandleFunc("/healthz", liveH)\n' > "$d/main.go"
caso "sem readiness" 1 "$d" "READINESS"
d="$W/semlive"; mkdir -p "$d"; printf 'mux.HandleFunc("/readyz", readyH)\n' > "$d/main.go"
caso "sem liveness" 1 "$d" "LIVENESS"
d="$W/apelido"; mkdir -p "$d"; printf 'mux.HandleFunc("/healthz", okH)\nmux.HandleFunc("/readyz", okH)\n' > "$d/main.go"
caso "readiness apelido do liveness" 1 "$d" "MESMO handler"
d="$W/pii"; mkdir -p "$d"
printf 'mux.HandleFunc("/healthz", liveH)\nmux.HandleFunc("/readyz", readyH)\nlog.Info("login", "cpf", cpf, "senha", senha)\n' > "$d/main.go"
caso "PII/segredo em chamada de log" 1 "$d" "PII/segredo em log"

echo "── fail-closed"
d="$W/vazio"; mkdir -p "$d"
caso "repo sem fonte" 2 "$d" "nenhum fonte"

echo
[ $rc -eq 0 ] && echo "✔ check-observabilidade.test.sh: $n casos" || echo "✖ check-observabilidade.test.sh: falhou"
exit $rc
