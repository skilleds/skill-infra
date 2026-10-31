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

cfg() { # <arquivo> <programa-python de mutacao>
  python3 -c "
import json
d={'schema':'schematize-infra/drill@1','dado':'pedidos','rpo_minutos':60,'rto_minutos':30,
   'relatorios':'$TMP/rel','canario':'canario-1',
   'comandos':{'backup_mais_recente':'ls -1t $TMP/backups/*.dump | head -1',
               'restaurar':'cp \"\$BACKUP\" $TMP/restaurado.db',
               'verificar':'grep -q \"\$CANARIO\" $TMP/restaurado.db'}}
$2
json.dump(d,open('$1','w',encoding='utf8'),ensure_ascii=False)"
}
reset() { rm -rf "$TMP/backups" "$TMP/restaurado.db" "$TMP/rel"; mkdir -p "$TMP/backups"; }

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
cfg "$TMP/rto.json" "d['rto_minutos']=0; d['comandos']['restaurar']='sleep 2; cp \"\$BACKUP\" $TMP/restaurado.db'"
checa "restore mais lento que o RTO reprova" 1 "RTO estourado" bash "$DRILL" "$TMP/rto.json"

echo "== ausencias =="
reset   # sem nenhum arquivo de backup
cfg "$TMP/sembkp.json" "pass"
checa "nenhum backup reprova (nao 'passa por vacuidade')" 1 "sem backup" bash "$DRILL" "$TMP/sembkp.json"

reset; printf 'canario-1\n' > "$TMP/backups/2026.dump"
cfg "$TMP/semver.json" "del d['comandos']['verificar']"
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

echo; echo "dr-drill: $ok ok, $fail falha(s)"; [ "$fail" = 0 ]
