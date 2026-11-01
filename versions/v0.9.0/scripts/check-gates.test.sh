#!/usr/bin/env bash
# Vermelho primeiro dos dois gates que tiravam `isolamento.md` e `observabilidade.md` da condicao de
# normativa orfa. Cada fixture e um repo de mentira com UM defeito.
# EXCEÇÃO DECLARADA de strict mode (`schematize-shell` -> `references/piso.md` secao 1):
# harness de teste roda sem `-e` de propósito — ele precisa continuar depois de um caso
# vermelho para reportar TODOS, em vez de parar no primeiro.
set -u
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO="$AQUI/check-isolamento.sh"; OBS="$AQUI/check-observabilidade.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
ok=0; fail=0
checa() { local nome="$1" esp="$2" agulha="$3"; shift 3
  local saida; saida="$("$@" 2>&1)"; local rc=$?
  if [ "$rc" != "$esp" ]; then echo "  ✖ $nome: exit $rc, esperado $esp"; sed 's/^/      /' <<<"$saida"; fail=$((fail+1)); return; fi
  if [ -n "$agulha" ] && ! grep -qF -- "$agulha" <<<"$saida"; then echo "  ✖ $nome: exit certo, saida sem \"$agulha\""; sed 's/^/      /' <<<"$saida"; fail=$((fail+1)); return; fi
  echo "  ✔ $nome"; ok=$((ok+1)); }

unit_bom() { cat > "$1" <<'U'
[Service]
User=pedidos
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
CapabilityBoundingSet=
RestrictAddressFamilies=AF_INET AF_INET6
U
}

echo "== isolamento =="
d="$TMP/iso-ok"; mkdir -p "$d"; unit_bom "$d/pedidos.service"
printf 'FROM alpine\nRUN adduser -D app\nUSER app\nHEALTHCHECK CMD wget -q -O- localhost:8080/healthz\n' > "$d/Dockerfile"
checa "repo com unit hardened + container nao-root passa" 0 "piso cumprido" bash "$ISO" "$d"

d="$TMP/iso-vazio"; mkdir -p "$d"; echo "# so prosa" > "$d/README.md"
checa "repo SEM artefato nao passa por vacuidade" 2 "Ausencia de artefato nao e conformidade" bash "$ISO" "$d"

d="$TMP/iso-root"; mkdir -p "$d"; unit_bom "$d/x.service"; sed -i 's/User=pedidos/User=root/' "$d/x.service"
checa "User=root reprova" 1 "User=root" bash "$ISO" "$d"

d="$TMP/iso-semuser"; mkdir -p "$d"; unit_bom "$d/x.service"; sed -i '/User=/d' "$d/x.service"
checa "unit sem User= reprova (roda como root)" 1 "roda como ROOT" bash "$ISO" "$d"

d="$TMP/iso-semhard"; mkdir -p "$d"; unit_bom "$d/x.service"; sed -i '/ProtectSystem/d' "$d/x.service"
checa "unit sem ProtectSystem reprova" 1 "falta ProtectSystem=" bash "$ISO" "$d"

d="$TMP/iso-dockerroot"; mkdir -p "$d"; unit_bom "$d/x.service"
printf 'FROM alpine\nCMD ["/app"]\n' > "$d/Dockerfile"
checa "Dockerfile sem USER reprova" 1 "container roda como root" bash "$ISO" "$d"

d="$TMP/iso-dbexposto"; mkdir -p "$d"; unit_bom "$d/x.service"
cat > "$d/compose.yml" <<'C'
services:
  db:
    image: postgres:17
    ports:
      - "5432:5432"
C
checa "banco publicado no host reprova" 1 "rede deny-by-default" bash "$ISO" "$d"

echo "== observabilidade =="
d="$TMP/obs-ok"; mkdir -p "$d"
cat > "$d/api.go" <<'G'
func rotas(r chi.Router) {
	r.Get("/healthz", vivo)
	r.Get("/readyz", pronto)   // checa banco e fila
}
G
echo "objetivo: 99.9" > "$d/slo.yml"; echo "OTEL_SERVICE_NAME=api" > "$d/.env.example"
checa "liveness + readiness distintos passam" 0 "distintos" bash "$OBS" "$d"

d="$TMP/obs-semready"; mkdir -p "$d"
printf 'r.Get("/healthz", vivo)\n' > "$d/api.go"
checa "sem readiness reprova" 1 "sem endpoint de READINESS" bash "$OBS" "$d"

d="$TMP/obs-alias"; mkdir -p "$d"
cat > "$d/api.go" <<'G'
r.Get("/healthz", vivo)
r.Get("/readyz", vivo)
G
checa "readiness apelido do liveness reprova" 1 "vacuamente verdadeiro" bash "$OBS" "$d"

d="$TMP/obs-pii"; mkdir -p "$d"
cat > "$d/api.go" <<'G'
r.Get("/healthz", vivo)
r.Get("/readyz", pronto)
func entrar(u User) { log.Info("login", "email", u.Email, "senha", u.Senha) }
G
checa "senha no log reprova" 1 "PII/segredo em log" bash "$OBS" "$d"

d="$TMP/obs-token"; mkdir -p "$d"
cat > "$d/api.ts" <<'T'
router.get('/healthz', vivo); router.get('/readyz', pronto)
logger.debug(`chamando provider`, { authorization: req.headers.authorization })
T
checa "authorization no log reprova" 1 "PII/segredo em log" bash "$OBS" "$d"

d="$TMP/obs-vazio"; mkdir -p "$d"; echo x > "$d/LEIA.md"
checa "sem fonte nenhum nao passa por vacuidade" 2 "nada para verificar" bash "$OBS" "$d"

echo; echo "check-gates: $ok ok, $fail falha(s)"; [ "$fail" = 0 ]
