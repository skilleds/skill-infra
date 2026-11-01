#!/usr/bin/env bash
# schematize-infra — gate de ISOLAMENTO (references/isolamento.md).
#
# Le os artefatos que EXISTEM no repo (systemd units, Dockerfile, compose) e cobra o piso:
# um user dedicado por servico, unit hardened, container nao-root e read-only, e nada de banco
# publicado na rede. Nao inspeciona servidor: cobra o que esta versionado, que e onde a decisao mora.
#
# uso: check-isolamento.sh [dir]   ·   exit 0 = passa · 1 = REPROVA · 2 = nada para checar
# EXCEÇÃO DECLARADA de strict mode (`schematize-shell` -> `references/piso.md` secao 1):
# este script é um COLETOR — ele varre tudo e SOMA os achados. Com `set -e` abortaria no
# primeiro problema e reportaria um, escondendo os outros. Por isso `set -uo pipefail` sem `-e`.
set -uo pipefail
raiz="${1:-.}"
erros=(); avisos=()

acha() { find "$raiz" -type f \( "$@" \) \
  -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/target/*' -not -path '*/versions/*' 2>/dev/null; }

units=$(acha -name '*.service'); dockerfiles=$(acha -name 'Dockerfile' -o -name 'Dockerfile.*')
composes=$(acha -name 'docker-compose*.y*ml' -o -name 'compose.y*ml')

# Fail-closed: repo sem NENHUM artefato de isolamento nao "passa". Nao ha o que aprovar.
if [ -z "$units$dockerfiles$composes" ]; then
  echo "✖ nenhum systemd unit, Dockerfile ou compose em $raiz — nao ha isolamento para verificar." >&2
  echo "  Ausencia de artefato nao e conformidade: e provisionamento a mao, que a skill veta (isolamento.md secao 6)." >&2
  exit 2
fi

for u in $units; do
  nome="$(basename "$u")"
  user=$(grep -oP '^\s*User\s*=\s*\K\S+' "$u" | tail -1)
  if [ -z "$user" ]; then erros+=("$nome: sem User= — unit sem User roda como ROOT")
  elif [ "$user" = "root" ]; then erros+=("$nome: User=root — um user Linux dedicado POR servico e o piso 1")
  fi
  for d in NoNewPrivileges ProtectSystem PrivateTmp ProtectHome; do
    grep -qE "^\s*$d\s*=" "$u" || erros+=("$nome: falta $d=")
  done
  v=$(grep -oP '^\s*ProtectSystem\s*=\s*\K\S+' "$u" | tail -1)
  [ -n "$v" ] && [ "$v" != "strict" ] && [ "$v" != "full" ] && avisos+=("$nome: ProtectSystem=$v (prefira strict)")
  grep -qE '^\s*NoNewPrivileges\s*=\s*(yes|true|1)' "$u" || [ -z "$(grep -E '^\s*NoNewPrivileges' "$u")" ] || erros+=("$nome: NoNewPrivileges declarado mas nao habilitado")
  for d in CapabilityBoundingSet RestrictAddressFamilies; do
    grep -qE "^\s*$d\s*=" "$u" || avisos+=("$nome: sem $d= (least-privilege incompleto)")
  done
done

for f in $dockerfiles; do
  nome="${f#$raiz/}"
  user=$(grep -oP '^\s*USER\s+\K\S+' "$f" | tail -1)
  if [ -z "$user" ]; then erros+=("$nome: sem USER — container roda como root por default")
  elif [ "$user" = "root" ] || [ "$user" = "0" ]; then erros+=("$nome: USER $user — container nao-root e o piso")
  fi
  grep -qE '^\s*HEALTHCHECK' "$f" || avisos+=("$nome: sem HEALTHCHECK")
done

for c in $composes; do
  nome="${c#$raiz/}"
  grep -qE '^\s*read_only:\s*true' "$c" || avisos+=("$nome: nenhum servico com read_only: true")
  grep -qE '^\s*cap_drop:' "$c" || avisos+=("$nome: nenhum cap_drop:")
  # Banco publicado no host e o furo classico do compose de dev que virou producao.
  if grep -qiE 'image:\s*(postgres|mysql|mariadb|redis|mongo)' "$c" && \
     awk '/image:[[:space:]]*(postgres|mysql|mariadb|redis|mongo)/{f=1} f&&/^[[:space:]]*ports:/{print;exit}' "$c" | grep -q ports; then
    erros+=("$nome: banco/cache com ports: publicado — rede deny-by-default (isolamento.md secao 4) nao publica dado")
  fi
done

for a in "${avisos[@]:-}"; do [ -n "$a" ] && echo "  ! $a" >&2; done
if [ ${#erros[@]} -gt 0 ]; then
  echo "✖ isolamento REPROVADO — ${#erros[@]} problema(s):" >&2
  for e in "${erros[@]}"; do echo "  · $e" >&2; done
  exit 1
fi
echo "✔ isolamento: $(echo "$units $dockerfiles $composes" | wc -w) artefato(s) verificado(s), piso cumprido."
