#!/usr/bin/env bash
# Vermelho->verde do gate de deploy-só-do-git aplicado à infra: pipeline, Makefile, runbook e *.sh.
# EXCEÇÃO DECLARADA de strict mode (`schematize-shell` -> `references/piso.md` secao 1):
# harness de teste roda sem `-e` para reportar TODOS os casos.
set -uo pipefail
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G="$AQUI/check-deploy-git.sh"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
export SKIP_GIT=1
rc=0
caso() { # nome esperado dir
  local out z; out=$(bash "$G" "$3" 2>&1); z=$?
  if [ "$z" -eq "$2" ]; then echo "  ✔ $1 (exit $z)"; else echo "  ✖ $1: esperava $2, veio $z: $out"; rc=1; fi
}
mk() { mkdir -p "$W/$1"; printf '%s\n' "$2" > "$W/$1/$3"; }

echo "── vermelhos plantados"
mk scp 'scp -r dist/ deploy@prd.exemplo.com:/srv/app' deploy.sh;                    caso "scp em *.sh" 1 "$W/scp"
mk rsync 'deploy:
	rsync -az ./build/ deploy@prd.exemplo.com:/srv/app/' Makefile;                  caso "rsync em Makefile" 1 "$W/rsync"   # shell-ok: fixture — rsync é a ENTRADA que o gate deve reprovar, nunca executado
mk tarssh 'tar czf - . | ssh deploy@prd.exemplo.com "tar xzf - -C /srv/app"' release.sh; caso "tar|ssh em *.sh" 1 "$W/tarssh"   # shell-ok: fixture — tar|ssh é a ENTRADA que o gate deve reprovar, nunca executado
mk dsl 'docker save app:1 | ssh deploy@prd.exemplo.com docker load' push.sh;        caso "docker save|load" 1 "$W/dsl"   # shell-ok: fixture — docker save|ssh é a ENTRADA que o gate deve reprovar, nunca executado
mk pipe 'jobs:
  deploy:
    steps:
      - run: scp app.tar deploy@prd.exemplo.com:/srv' pipeline.yml;                caso "scp em pipeline yml" 1 "$W/pipe"
mk rb 'ssh deploy@prd.exemplo.com "systemctl restart app"' runbook-deploy.sh;       caso "ssh mutável em runbook .sh" 1 "$W/rb"   # shell-ok: fixture — ssh mutável é a ENTRADA que o gate deve reprovar, nunca executado

echo "── verde"
mkdir -p "$W/rbmd/docs"; printf '# Runbook de deploy\n\n```bash\nrsync -az build/ deploy@prd.exemplo.com:/srv/app\n```\n' > "$W/rbmd/docs/runbook-deploy.md"   # shell-ok: fixture — rsync em runbook .md é a ENTRADA que o gate deve reprovar
caso "rsync em bloco de código de runbook .md" 1 "$W/rbmd"
mkdir -p "$W/rbok/docs"; printf '# Runbook de deploy\n\n```bash\nssh deploy@prd.exemplo.com ops deploy --sha abc123\n```\n' > "$W/rbok/docs/runbook-deploy.md"   # shell-ok: fixture — ssh ops deploy por SHA é o caso LIMPO que o gate deve aceitar
mk limpo 'git push origin main
ssh deploy@prd.exemplo.com ops deploy --sha "$(git rev-parse HEAD)"' deploy.sh;     caso "push + ops deploy por SHA" 0 "$W/limpo"   # shell-ok: fixture — ssh ops deploy por SHA é o caso LIMPO que o gate deve aceitar
caso "runbook .md limpo (ops deploy por SHA)" 0 "$W/rbok"

echo "── gate ausente é fail-closed"
mkdir -p "$W/iso/a/b/scripts"; cp "$G" "$W/iso/a/b/scripts/c.sh"
out=$(HOME="$W/iso" SCHEMATIZE_ENGINEERING_DIR='' bash "$W/iso/a/b/scripts/c.sh" "$W/limpo" 2>&1); z=$?
if [ "$z" -eq 2 ]; then echo "  ✔ sem gate da engineering: exit 2"; else echo "  ✖ esperava 2, veio $z: $out"; rc=1; fi
[ "$rc" -eq 0 ] && echo "check-deploy-git (infra): OK"
exit "$rc"
