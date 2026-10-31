#!/usr/bin/env bash
# schematize-infra — o DR drill. Restaura um backup num ambiente limpo, CRONOMETRA contra o RTO,
# confere a idade do dado contra o RPO e so entao diz que o backup existe.
#
# Por que existe: o piso 7 desta skill e "backup cujo restore nunca foi provado nao e backup — e
# esperanca", e a skill nao tinha drill nenhum. O piso era literalmente o que ela acusava (achado
# da vistoria de 2026-08-21).
#
# uso:
#   dr-drill.sh <drill.json>                  roda o drill e grava o relatorio
#   dr-drill.sh --frescor <dir> [--max-dias N]  so confere se o ULTIMO drill nao envelheceu
#
# exit: 0 = restore provado · 1 = REPROVOU · 2 = configuracao invalida/uso errado
# EXCEÇÃO DECLARADA de strict mode (`schematize-shell` -> `references/piso.md` secao 1):
# COLETOR de falhas: o drill precisa rodar as 4 verificações e reportar TODAS; com `set -e` a primeira falha esconderia as outras três.
set -uo pipefail

erro() { echo "✖ $*" >&2; }
info() { echo "  $*" >&2; }

json_campo() { # <arquivo> <caminho.jq-ish simples>
  node -e '
    const [arq, cam] = process.argv.slice(1)
    const d = JSON.parse(require("fs").readFileSync(arq, "utf8"))
    const v = cam.split(".").reduce((o, k) => (o == null ? o : o[k]), d)
    process.stdout.write(v === undefined || v === null ? "" : String(v))
  ' "$1" "$2" 2>/dev/null
}

# ------------------------------------------------------------------ modo --frescor
if [ "${1:-}" = "--frescor" ]; then
  dir="${2:-}"; max_dias=30
  for ((i=3; i<=$#; i++)); do [ "${!i}" = "--max-dias" ] && { j=$((i+1)); max_dias="${!j}"; }; done
  [ -d "$dir" ] || { erro "diretorio de relatorios nao existe: $dir"; exit 2; }
  ultimo="$(ls -1 "$dir"/drill-*.json 2>/dev/null | sort | tail -1)"
  # Ausencia de relatorio NAO e "esta fresco". E o pior estado possivel: nunca se restaurou nada.
  [ -n "$ultimo" ] || { erro "nenhum relatorio de drill em $dir — restore NUNCA foi provado"; exit 1; }
  quando="$(json_campo "$ultimo" quando)"
  veredito="$(json_campo "$ultimo" veredito)"
  [ -n "$quando" ] || { erro "$ultimo sem campo 'quando'"; exit 2; }
  epoch_drill=$(date -u -d "$quando" +%s 2>/dev/null) || { erro "data invalida em $ultimo: $quando"; exit 2; }
  dias=$(( ( $(date -u +%s) - epoch_drill ) / 86400 ))
  echo "ultimo drill: $ultimo ($quando, ha $dias dia(s), veredito=$veredito)"
  [ "$veredito" = "aprovado" ] || { erro "o ultimo drill REPROVOU — nao ha restore provado"; exit 1; }
  [ "$dias" -le "$max_dias" ] || { erro "ultimo drill ha $dias dias, limite $max_dias — backup volta a ser esperanca"; exit 1; }
  echo "✔ drill dentro da janela ($dias <= $max_dias dias)"
  exit 0
fi

cfg="${1:-}"
[ -n "$cfg" ] && [ -f "$cfg" ] || { erro "uso: dr-drill.sh <drill.json> | --frescor <dir> [--max-dias N]"; exit 2; }
node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$cfg" 2>/dev/null || { erro "$cfg: JSON invalido"; exit 2; }

dado="$(json_campo "$cfg" dado)"
rpo="$(json_campo "$cfg" rpo_minutos)"
rto="$(json_campo "$cfg" rto_minutos)"
canario="$(json_campo "$cfg" canario)"
cmd_backup="$(json_campo "$cfg" comandos.backup_mais_recente)"
cmd_restaurar="$(json_campo "$cfg" comandos.restaurar)"
cmd_verificar="$(json_campo "$cfg" comandos.verificar)"
saida_dir="$(json_campo "$cfg" relatorios)"; saida_dir="${saida_dir:-.}"

# --- PRE-FLIGHT fail-closed: falta de configuracao NAO vira drill "que passou". --------------
faltando=()
[ -n "$dado" ]          || faltando+=("dado")
[ -n "$rpo" ]           || faltando+=("rpo_minutos")
[ -n "$rto" ]           || faltando+=("rto_minutos")
[ -n "$cmd_backup" ]    || faltando+=("comandos.backup_mais_recente")
[ -n "$cmd_restaurar" ] || faltando+=("comandos.restaurar")
# Sem verificacao nao ha drill: "o comando de restore nao deu erro" e exatamente a esperanca que o
# piso proibe. Tem de haver oraculo — o canario que so existe se o dado voltou de verdade.
[ -n "$cmd_verificar" ] || faltando+=("comandos.verificar (sem oraculo nao ha drill)")
if [ ${#faltando[@]} -gt 0 ]; then
  erro "$cfg incompleto: ${faltando[*]}"
  exit 2
fi

agora_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
falhas=()
info "drill de '$dado' — RPO ${rpo}min, RTO ${rto}min"

# --- 1. achar o backup e medir a IDADE dele (o RPO) -------------------------------------------
backup="$(eval "$cmd_backup" 2>/dev/null | tail -1)"
if [ -z "$backup" ]; then
  erro "nenhum backup encontrado — nao ha o que restaurar"
  falhas+=("sem backup")
  idade_min=""
else
  info "backup: $backup"
  if [ -e "$backup" ]; then
    idade_min=$(( ( $(date -u +%s) - $(stat -c %Y "$backup") ) / 60 ))
  else
    idade_min=""
    falhas+=("o comando devolveu '$backup', que nao existe no disco")
  fi
  if [ -n "$idade_min" ]; then
    info "idade do backup: ${idade_min}min"
    [ "$idade_min" -le "$rpo" ] || falhas+=("RPO estourado: backup com ${idade_min}min, limite ${rpo}min")
  fi
fi

# --- 2. restaurar, cronometrando (o RTO) ------------------------------------------------------
inicio=$(date -u +%s)
if [ -n "$backup" ]; then
  # O comando de restore E a configuração: `drill.json` declara, por contrato, um comando do projeto.
  # Não é entrada de usuário — é o operador descrevendo como restaurar o próprio banco.
  # shell-ok: comando vindo do drill.json do projeto, por contrato
  if BACKUP="$backup" bash -c "$cmd_restaurar" >/dev/null 2>&1; then
    info "restore executou"
  else
    falhas+=("o comando de restore falhou")
  fi
fi

# --- 3. o ORACULO: o canario voltou? ----------------------------------------------------------
# shell-ok: idem — o oráculo vem do `drill.json` do projeto, por contrato.
if BACKUP="$backup" CANARIO="$canario" bash -c "$cmd_verificar" >/dev/null 2>&1; then
  info "verificacao: canario presente"
else
  # Este e o caso que separa drill de teatro: restore "bem-sucedido" com dado que nao voltou.
  falhas+=("VERIFICACAO FALHOU: o restore terminou mas o canario nao esta la")
fi
fim=$(date -u +%s)
# Em SEGUNDOS de proposito: arredondar para minuto faria um RTO de 0min "passar" com o relogio
# andando — e um limite que nunca pode ser estourado nao e limite.
decorrido_seg=$(( fim - inicio ))
rto_seg=$(( rto * 60 ))
info "decorrido: ${decorrido_seg}s (RTO ${rto}min = ${rto_seg}s)"
[ "$decorrido_seg" -le "$rto_seg" ] || falhas+=("RTO estourado: ${decorrido_seg}s, limite ${rto}min (${rto_seg}s)")

# --- 4. relatorio (vai para o archive) --------------------------------------------------------
mkdir -p "$saida_dir"
rel="$saida_dir/drill-$(date -u +%Y%m%dT%H%M%SZ).json"
veredito=$([ ${#falhas[@]} -eq 0 ] && echo aprovado || echo reprovado)
node -e '
  const [rel, quando, dado, rpo, rto, idade, decorridoSeg, veredito, backup, ...falhas] = process.argv.slice(1)
  require("fs").writeFileSync(rel, JSON.stringify({
    schema: "schematize-infra/drill-relatorio@1",
    quando, dado, veredito,
    rpo_minutos: Number(rpo), rto_minutos: Number(rto),
    idade_backup_minutos: idade === "" ? null : Number(idade),
    duracao_restore_segundos: Number(decorridoSeg),
    backup, falhas,
  }, null, 2) + "\n")
' "$rel" "$agora_iso" "$dado" "$rpo" "$rto" "$idade_min" "$decorrido_seg" "$veredito" "$backup" "${falhas[@]}"
echo "relatorio: $rel" >&2

if [ ${#falhas[@]} -gt 0 ]; then
  erro "DRILL REPROVADO — ${#falhas[@]} problema(s):"
  for f in "${falhas[@]}"; do echo "  · $f" >&2; done
  echo "  Backup cujo restore nao foi provado nao e backup." >&2
  exit 1
fi
echo "✔ restore PROVADO para '$dado': ${decorrido_seg}s <= RTO ${rto}min, backup com ${idade_min}min <= RPO ${rpo}min"
