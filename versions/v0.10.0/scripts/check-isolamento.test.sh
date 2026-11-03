#!/usr/bin/env bash
# check-isolamento.test.sh — o VERMELHO VISTO do gate de isolamento.
# Planta cada violação num diretório temporário e exige exit 1 (e 0 no limpo, 2 no vazio).
# EXCEÇÃO DECLARADA de strict mode (`schematize-shell` -> `references/piso.md` secao 1):
# harness de teste roda sem `-e` de propósito — precisa continuar depois de um caso vermelho
# para reportar TODOS, em vez de parar no primeiro.
set -uo pipefail
G="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-isolamento.sh"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
rc=0; n=0
caso() { # nome esperado dir [padrão-na-saída]
  local nome="$1" esp="$2" dir="$3" pad="${4:-}" out z
  out=$(bash "$G" "$dir" 2>&1); z=$?; n=$((n+1))
  if [ "$z" -eq "$esp" ] && { [ -z "$pad" ] || grep -q -- "$pad" <<<"$out"; }; then echo "  ✔ $nome (exit $z)"
  else echo "  ✖ $nome: esperava $esp, veio $z: $out"; rc=1; fi
}
unit_ok() { printf '[Service]\nUser=svc-app\nNoNewPrivileges=yes\nProtectSystem=strict\nPrivateTmp=yes\nProtectHome=yes\nCapabilityBoundingSet=\nRestrictAddressFamilies=AF_INET\n' > "$1"; }

echo "── limpo passa"
d="$W/limpo"; mkdir -p "$d"; unit_ok "$d/app.service"
printf 'FROM scratch\nUSER 10001\nHEALTHCHECK CMD true\n' > "$d/Dockerfile"; printf '.git\n.env\n' > "$d/.dockerignore"
caso "unit + Dockerfile conformes" 0 "$d" "piso cumprido"

echo "── vermelhos plantados"
d="$W/semuser"; mkdir -p "$d"; unit_ok "$d/app.service"; sed -i '/^User=/d' "$d/app.service"
caso "unit sem User=" 1 "$d" "sem User="
d="$W/root"; mkdir -p "$d"; unit_ok "$d/app.service"; sed -i 's/^User=.*/User=root/' "$d/app.service"
caso "unit com User=root" 1 "$d" "User=root"
d="$W/semhard"; mkdir -p "$d"; unit_ok "$d/app.service"; sed -i '/^ProtectSystem=/d' "$d/app.service"
caso "unit sem ProtectSystem" 1 "$d" "falta ProtectSystem"
d="$W/semuserdock"; mkdir -p "$d"; printf 'FROM scratch\n' > "$d/Dockerfile"
caso "Dockerfile sem USER" 1 "$d" "sem USER"
d="$W/dockroot"; mkdir -p "$d"; printf 'FROM scratch\nUSER root\n' > "$d/Dockerfile"
caso "Dockerfile USER root" 1 "$d" "USER root"
d="$W/banco"; mkdir -p "$d"; printf 'services:\n  db:\n    image: postgres:17\n    ports:\n      - "5432:5432"\n' > "$d/compose.yaml"
caso "banco com ports: publicado (via gate do docker)" 1 "$d" "porta publicada"

echo "── sem a skill docker: fallback mínimo local, com aviso (sem acoplar)"
mkdir -p "$W/iso/a/b/scripts"; cp "$G" "$W/iso/a/b/scripts/check-isolamento.sh"
out=$(HOME="$W/iso" bash "$W/iso/a/b/scripts/check-isolamento.sh" "$d" 2>&1); z=$?; n=$((n+1))
if [ "$z" -eq 1 ] && grep -q "ports: publicado" <<<"$out" && grep -q "MÍNIMA local" <<<"$out"; then echo "  ✔ fallback local reprova banco com ports: e avisa"; else echo "  ✖ fallback: exit $z: $out"; rc=1; fi
d="$W/semuserdock2"; mkdir -p "$d"; printf 'FROM scratch\n' > "$d/Dockerfile"
out=$(HOME="$W/iso" bash "$W/iso/a/b/scripts/check-isolamento.sh" "$d" 2>&1); z=$?; n=$((n+1))
if [ "$z" -eq 1 ] && grep -q "sem USER" <<<"$out"; then echo "  ✔ fallback local reprova Dockerfile sem USER"; else echo "  ✖ fallback USER: exit $z: $out"; rc=1; fi

echo "── fail-closed"
d="$W/vazio"; mkdir -p "$d"
caso "repo sem artefato nenhum" 2 "$d" "nenhum systemd unit"

echo
[ $rc -eq 0 ] && echo "✔ check-isolamento.test.sh: $n casos" || echo "✖ check-isolamento.test.sh: falhou"
exit $rc
