#!/usr/bin/env bash
# schematize-infra — gate dos pisos 22/23 no pipeline, Makefile, runbook e *.sh da INFRA.
# Reprova scp/rsync remoto, tar|ssh, docker save|load, ssh mutável, SQL remoto e (no repo git) árvore
# suja / commits por empurrar. NÃO duplica regra: delega ao gate único da casa
# (`schematize-engineering` -> `scripts/check-deploy-git.sh`), para os padrões não divergirem.
# Fail-closed: se o gate da engineering não for achado, sai 2 (sem gate não há "passou").
# uso: check-deploy-git.sh [dir]   (SKIP_GIT=1 pula a parte de git; SCHEMATIZE_ENGINEERING_DIR aponta a skill)
# exit: 0 ok · 1 violação · 2 gate da engineering ausente
set -euo pipefail
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cands=()
[ -n "${SCHEMATIZE_ENGINEERING_DIR:-}" ] && cands+=("$SCHEMATIZE_ENGINEERING_DIR/scripts/check-deploy-git.sh")
cands+=("$AQUI/../../schematize-engineering/scripts/check-deploy-git.sh"   # instalada: .claude/skills/
        "$AQUI/../../skill-engineering/scripts/check-deploy-git.sh"        # catálogo
        "$HOME/.claude/skills/schematize-engineering/scripts/check-deploy-git.sh")
gate=""
for g in "${cands[@]}"; do [ -f "$g" ] && { gate="$g"; break; }; done
if [ -z "$gate" ]; then
  echo "✖ gate da schematize-engineering (scripts/check-deploy-git.sh) não encontrado — instale a skill ou" >&2
  echo "  defina SCHEMATIZE_ENGINEERING_DIR. Sem o gate, 'deploy só do git' não está provado." >&2
  exit 2
fi
D="${1:-.}"; rc=0
bash "$gate" "$D" || rc=1

# Runbook em Markdown: o gate da engineering lê *.sh/yml/Makefile, não .md. Extraio os blocos de código
# (```) dos runbooks (arquivos *.md com runbook/deploy/ops/dr/rollback no caminho; nunca references/,
# versions/ nem SKILL.md) para .sh temporários e rodo o MESMO gate.
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
n=0
while IFS= read -r md; do
  n=$((n+1))
  awk '/^[[:space:]]*```/{f=!f; next} f{print}' "$md" > "$T/$n.sh"
  printf '%s\n' "$md" > "$T/$n.origem"
done < <(find "$D" -type f -name '*.md' -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/versions/*' \
  -not -path '*/references/*' -not -name 'SKILL.md' -not -name 'CHANGELOG.md' 2>/dev/null | grep -Ei 'runbook|deploy|ops|dr[-_/]|rollback|release')
if [ "$n" -gt 0 ]; then
  out="$(SKIP_GIT=1 bash "$gate" "$T" 2>&1)" || { rc=1; echo "FAIL: runbook(s) .md com envio fora do git/ops (blocos de código):"; echo "$out" | sed 's|'"$T"'/\([0-9]*\)\.sh|runbook #\1|'; for o in "$T"/*.origem; do echo "  origem $(basename "$o" .origem): $(cat "$o")"; done; }
fi
exit "$rc"
