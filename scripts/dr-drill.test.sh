#!/usr/bin/env bash
# Vermelho primeiro do drill. Cada caso monta um "banco" de mentira (arquivos) e exige que o drill
# reprove pelo motivo certo. O caso que mais importa e o 'restore-ok-canario-ausente': o comando de
# restore termina com exit 0 e o dado NAO voltou — e exatamente a esperanca que o piso 7 proibe.
# EXCEÇÃO DECLARADA de strict mode (`schematize-shell` -> `references/piso.md` secao 1):
# harness de teste roda sem `-e` de propósito — ele precisa continuar depois de um caso
# vermelho para reportar TODOS, em vez de parar no primeiro.
set -u
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRILL="$AQUI/dr-drill.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
ok=0; fail=0
checa() { local nome="$1" esp="$2" agulha="$3"; shift 3
  local saida; saida="$("$@" 2>&1)"; local rc=$?
  if [ "$rc" != "$esp" ]; then echo "  ✖ $nome: exit $rc, esperado $esp"; sed 's/^/      /' <<<"$saida"; fail=$((fail+1)); return; fi
  if [ -n "$agulha" ] && ! grep -qF -- "$agulha" <<<"$saida"; then echo "  ✖ $nome: exit certo, saida sem \"$agulha\""; sed 's/^/      /' <<<"$saida"; fail=$((fail+1)); return; fi
  echo "  ✔ $nome"; ok=$((ok+1)); }

# "ops" de mentira: o drill so fala com ele por argv (sem eval/bash -c). Le STUB_DIR do ambiente.
cat > "$TMP/ops" <<'STUB'
#!/usr/bin/env bash
case "$2" in
  backup-latest) ls -1t "$STUB_DIR"/backups/* 2>/dev/null | head -1 ;;
  backup-manifest) cat "$STUB_DIR/manifesto.json" ;;
  restore) [ -z "${STUB_RESTORE_SLEEP:-}" ] || sleep "$STUB_RESTORE_SLEEP"; [ -f "$BACKUP" ] || BACKUP="$(ls -1t "$STUB_DIR"/backups/* | head -1)"; cp "$BACKUP" "$STUB_DIR/restaurado.db" ;;
  verify) grep -q "$CANARIO" "$STUB_DIR/restaurado.db" ;;
  *) exit 64 ;;
esac
STUB
chmod +x "$TMP/ops"
export STUB_DIR="$TMP" DR_NO_COMMIT=1

cfg() { # <arquivo> <programa-python de mutacao>
  python3 -c "
import json
d={'schema':'schematize-infra/drill@2','dado':'pedidos','rpo_minutos':60,'rto_minutos':30,
   'ops':'$TMP/ops','relatorios':'$TMP/rel','canario':'canario-1',
   'operacoes':{'backup_mais_recente':['drill','backup-latest','pedidos'],
                'restaurar':['drill','restore','pedidos'],
                'verificar':['drill','verify','pedidos']}}
$2
json.dump(d,open('$1','w',encoding='utf8'),ensure_ascii=False)"
}
reset() { rm -rf "$TMP/backups" "$TMP/restaurado.db" "$TMP/rel" "$TMP/manifesto.json"; mkdir -p "$TMP/backups"; }

echo "== verde: backup fresco, restore que restaura, canario presente =="
reset; printf 'linha\ncanario-1\n' > "$TMP/backups/2026.dump"
cfg "$TMP/ok.json" "pass"
checa "drill aprovado" 0 "restore PROVADO" bash "$DRILL" "$TMP/ok.json"
checa "gravou relatorio" 0 "" test -n "$(ls -1 "$TMP/rel"/drill-*.json 2>/dev/null)"

echo "== o caso que separa drill de teatro =="
reset; printf 'linha sem o canario\n' > "$TMP/backups/2026.dump"   # restore "funciona", dado nao volta
cfg "$TMP/oco.json" "pass"
checa "restore-ok-canario-ausente reprova" 1 "VERIFICACAO FALHOU" bash "$DRILL" "$TMP/oco.json"

echo "== RPO e RTO =="
reset; printf 'canario-1\n' > "$TMP/backups/velho.dump"; touch -d '3 hours ago' "$TMP/backups/velho.dump"
cfg "$TMP/rpo.json" "pass"
checa "backup mais velho que o RPO reprova" 1 "RPO estourado" bash "$DRILL" "$TMP/rpo.json"

reset; printf 'canario-1\n' > "$TMP/backups/2026.dump"
cfg "$TMP/rto.json" "d['rto_minutos']=0"
STUB_RESTORE_SLEEP=2 checa "restore mais lento que o RTO reprova" 1 "RTO estourado" bash "$DRILL" "$TMP/rto.json"

echo "== ausencias =="
reset   # sem nenhum arquivo de backup
cfg "$TMP/sembkp.json" "pass"
checa "nenhum backup reprova (nao 'passa por vacuidade')" 1 "sem backup" bash "$DRILL" "$TMP/sembkp.json"

reset; printf 'canario-1\n' > "$TMP/backups/2026.dump"
cfg "$TMP/semver.json" "del d['operacoes']['verificar']"
checa "config sem oraculo nem roda" 2 "sem oraculo nao ha drill" bash "$DRILL" "$TMP/semver.json"
cfg "$TMP/semrpo.json" "del d['rpo_minutos']"
checa "config sem RPO nem roda" 2 "rpo_minutos" bash "$DRILL" "$TMP/semrpo.json"
checa "arquivo inexistente" 2 "uso:" bash "$DRILL" "$TMP/nao-existe.json"
echo '{nao json' > "$TMP/torto.json"
checa "JSON torto" 2 "JSON invalido" bash "$DRILL" "$TMP/torto.json"

echo "== frescor: o drill que envelheceu =="
FR="$TMP/frescor"; mkdir -p "$FR"
checa "nenhum relatorio = restore NUNCA provado" 1 "NUNCA foi provado" bash "$DRILL" --frescor "$FR"
python3 -c "
import json,datetime
q=(datetime.datetime.now(datetime.UTC)-datetime.timedelta(days=200)).strftime('%Y-%m-%dT%H:%M:%SZ')
json.dump({'schema':'schematize-infra/drill-relatorio@1','quando':q,'veredito':'aprovado'},open('$FR/drill-antigo.json','w'))"
checa "drill de 200 dias reprova" 1 "volta a ser esperanca" bash "$DRILL" --frescor "$FR" --max-dias 30
python3 -c "
import json,datetime
q=(datetime.datetime.now(datetime.UTC)-datetime.timedelta(days=2)).strftime('%Y-%m-%dT%H:%M:%SZ')
json.dump({'schema':'schematize-infra/drill-relatorio@1','quando':q,'veredito':'reprovado'},open('$FR/drill-recente.json','w'))"
checa "drill recente que REPROVOU nao vale frescor" 1 "ultimo drill REPROVOU" bash "$DRILL" --frescor "$FR" --max-dias 30
python3 -c "
import json,datetime
q=(datetime.datetime.now(datetime.UTC)-datetime.timedelta(days=2)).strftime('%Y-%m-%dT%H:%M:%SZ')
json.dump({'schema':'schematize-infra/drill-relatorio@1','quando':q,'veredito':'aprovado'},open('$FR/drill-verde.json','w'))"
checa "drill recente e aprovado passa" 0 "dentro da janela" bash "$DRILL" --frescor "$FR" --max-dias 30

echo "== sem eval/bash -c: comando vindo do JSON nao vira shell =="
reset; printf 'canario-1\n' > "$TMP/backups/2026.dump"
cfg "$TMP/inj.json" "d['operacoes']['restaurar']=['drill','restore','pedidos; touch $TMP/PWNED']"
bash "$DRILL" "$TMP/inj.json" >/dev/null 2>&1
checa "string de shell no argv nao executa" 0 "" test ! -e "$TMP/PWNED"
cfg "$TMP/strcmd.json" "d['operacoes']['verificar']='true'"
checa "operacao como string (nao array) e config invalida" 2 "operacoes.verificar" bash "$DRILL" "$TMP/strcmd.json"
checa "dr-drill.sh nao contem eval nem bash -c" 0 "" bash -c "! grep -nE '^[^#]*(\\beval\\b|bash -c)' '$DRILL'"

echo "== idade por MANIFESTO (PITR/pgBackRest/bucket), nao so por arquivo =="
reset; printf 'canario-1\n' > "$TMP/backups/base"
agora=$(date -u +%s)
printf '[{"backup":[{"timestamp":{"stop":%s}}]}]\n' "$((agora-600))" > "$TMP/manifesto.json"
cfg "$TMP/man.json" "d['operacoes']['backup_mais_recente']=['drill','backup-manifest','pedidos']"
checa "manifesto pgbackrest fresco passa" 0 "restore PROVADO" bash "$DRILL" "$TMP/man.json"
printf '{"timestamp":"2020-01-01T00:00:00Z"}\n' > "$TMP/manifesto.json"
checa "manifesto velho estoura o RPO" 1 "RPO estourado" bash "$DRILL" "$TMP/man.json"
printf 'lixo-que-nao-e-arquivo-nem-json\n' > "$TMP/manifesto.json"
checa "saida sem idade mensuravel reprova" 1 "idade do backup nao medida" bash "$DRILL" "$TMP/man.json"

echo "== relatorio: commit+push no archive (piso 22) e custos =="
reset; printf 'canario-1\n' > "$TMP/backups/2026.dump"
git init -q --bare "$TMP/remoto.git"
git init -q "$TMP/archive"; git -C "$TMP/archive" remote add origin "$TMP/remoto.git"
git -C "$TMP/archive" config user.email t@t; git -C "$TMP/archive" config user.name t
git -C "$TMP/archive" commit -q --allow-empty -m init; git -C "$TMP/archive" push -q -u origin HEAD 2>/dev/null
cfg "$TMP/pub.json" "d['relatorios']='$TMP/archive/drills'; d['custos']={'storage_mensal_brl':12}"
DR_NO_COMMIT='' checa "drill publica o relatorio" 0 "relatorio publicado" bash "$DRILL" "$TMP/pub.json"
checa "HEAD do archive == origin" 0 "" test "$(git -C "$TMP/archive" rev-parse HEAD)" = "$(git -C "$TMP/remoto.git" rev-parse HEAD)"
checa "relatorio carrega custos" 0 "" grep -q storage_mensal_brl "$TMP"/archive/drills/drill-*.json
cfg "$TMP/fora.json" "d['relatorios']='$TMP/solto/drills'"
DR_NO_COMMIT='' checa "relatorio fora de repo git reprova" 1 "fora de repo git" bash "$DRILL" "$TMP/fora.json"

echo; echo "dr-drill: $ok ok, $fail falha(s)"; [ "$fail" = 0 ]
