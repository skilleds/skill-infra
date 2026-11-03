#!/usr/bin/env bash
# schematize-infra — o DR drill. Restaura um backup num ambiente limpo, CRONOMETRA contra o RTO,
# confere a idade do dado contra o RPO e so entao diz que o backup existe.
#
# Por que existe: o piso 7 desta skill e "backup cujo restore nunca foi provado nao e backup — e
# esperanca", e a skill nao tinha drill nenhum. O piso era literalmente o que ela acusava (achado
# da vistoria de 2026-08-21).
#
# QUEM RODA: o drill e uma OPERACAO DO OPS (`ops drill <dado>`), nunca a IA na mao (pisos 24 e 15).
# Nenhum comando vem do JSON para um shell: o JSON declara OPERACOES NOMEADAS do ops, como argv
# (arrays), e este script as executa SEM eval e SEM bash -c.
#
# uso:
#   dr-drill.sh <drill.json>                  roda o drill, grava o relatorio e o publica (commit+push)
#   dr-drill.sh --frescor <dir> [--max-dias N]  so confere se o ULTIMO drill nao envelheceu
#
# env: DR_OPS = binario do ops (default: campo "ops" do JSON, depois `ops`)
#      DR_NO_COMMIT=1 = nao faz commit/push do relatorio (so p/ teste; o piso 22 manda publicar)
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
ops_bin="${DR_OPS:-$(json_campo "$cfg" ops)}"; ops_bin="${ops_bin:-ops}"
saida_dir="$(json_campo "$cfg" relatorios)"; saida_dir="${saida_dir:-.}"

# Operacao = array argv no JSON (ex.: ["drill","latest","pedidos"]). NUL-separado: sem re-parse de shell.
argv_campo() { # <caminho> -> imprime argv NUL-separado (vazio se ausente ou nao for array de strings)
  node -e '
    const [arq, cam] = process.argv.slice(1)
    const d = JSON.parse(require("fs").readFileSync(arq, "utf8"))
    const v = cam.split(".").reduce((o, k) => (o == null ? o : o[k]), d)
    if (Array.isArray(v) && v.length && v.every((x) => typeof x === "string" && x !== "")) process.stdout.write(v.join("\0") + "\0")
  ' "$1" "$2" 2>/dev/null
}
mapfile -d '' op_backup < <(argv_campo "$cfg" operacoes.backup_mais_recente)
mapfile -d '' op_restaurar < <(argv_campo "$cfg" operacoes.restaurar)
mapfile -d '' op_verificar < <(argv_campo "$cfg" operacoes.verificar)

# --- PRE-FLIGHT fail-closed: falta de configuracao NAO vira drill "que passou". --------------
faltando=()
[ -n "$dado" ]          || faltando+=("dado")
[ -n "$rpo" ]           || faltando+=("rpo_minutos")
[ -n "$rto" ]           || faltando+=("rto_minutos")
[ ${#op_backup[@]} -gt 0 ]    || faltando+=("operacoes.backup_mais_recente (array argv do ops)")
[ ${#op_restaurar[@]} -gt 0 ] || faltando+=("operacoes.restaurar (array argv do ops)")
# Sem verificacao nao ha drill: "o comando de restore nao deu erro" e exatamente a esperanca que o
# piso proibe. Tem de haver oraculo — o canario que so existe se o dado voltou de verdade.
[ ${#op_verificar[@]} -gt 0 ] || faltando+=("operacoes.verificar (sem oraculo nao ha drill)")
if [ ${#faltando[@]} -gt 0 ]; then
  erro "$cfg incompleto: ${faltando[*]}"
  exit 2
fi

agora_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
falhas=()
info "drill de '$dado' — RPO ${rpo}min, RTO ${rto}min"

# --- 1. achar o backup e medir a IDADE dele (o RPO) -------------------------------------------
# A operacao imprime OU o caminho de um arquivo (idade = mtime) OU um MANIFESTO JSON (PITR, pgBackRest,
# objeto em bucket): {"timestamp": "<ISO>"} · {"timestamp": <epoch>} · {"timestamp": {"stop": <epoch>}}
# · {"idade_minutos": N} · ou lista (ex.: `pgbackrest info --output=json`; vale o backup mais novo).
saida_backup="$("$ops_bin" "${op_backup[@]}" 2>/dev/null)"
backup="$(printf '%s\n' "$saida_backup" | tail -1)"
idade_min=""
if [ -z "$saida_backup" ]; then
  erro "nenhum backup encontrado — nao ha o que restaurar"
  falhas+=("sem backup")
  backup=""
else
  idade_manifesto="$(printf '%s' "$saida_backup" | node -e '
    let t = ""; process.stdin.on("data", (c) => (t += c)).on("end", () => {
      let d; try { d = JSON.parse(t) } catch { return }
      const ep = (v) => {
        if (v && typeof v === "object") v = v.stop ?? v.end ?? v.start
        if (typeof v === "number") return v > 1e12 ? v / 1000 : v
        if (typeof v === "string") { const m = Date.parse(v); return Number.isNaN(m) ? null : m / 1000 }
        return null
      }
      const cand = (o) => {
        if (!o || typeof o !== "object") return []
        if (typeof o.idade_minutos === "number") return [{ idade: o.idade_minutos }]
        const e = ep(o.timestamp ?? o.ts ?? o.finished_at ?? o.mtime)
        const out = e == null ? [] : [{ epoch: e }]
        for (const k of ["backup", "backups"]) if (Array.isArray(o[k])) o[k].forEach((x) => out.push(...cand(x)))
        return out
      }
      const todos = (Array.isArray(d) ? d : [d]).flatMap(cand)
      if (!todos.length) return
      const agora = Date.now() / 1000
      const idades = todos.map((c) => (c.idade !== undefined ? c.idade : (agora - c.epoch) / 60))
      process.stdout.write(String(Math.floor(Math.min(...idades))))
    })' 2>/dev/null)"
  if [ -n "$idade_manifesto" ]; then
    backup="manifesto"
    idade_min="$idade_manifesto"
    info "backup: manifesto JSON"
  elif [ -e "$backup" ]; then
    info "backup: $backup"
    idade_min=$(( ( $(date -u +%s) - $(stat -c %Y "$backup") ) / 60 ))
  else
    falhas+=("a operacao devolveu '$backup': nao e arquivo existente nem manifesto JSON com timestamp — idade do backup nao medida")
  fi
  if [ -n "$idade_min" ]; then
    info "idade do backup: ${idade_min}min"
    [ "$idade_min" -le "$rpo" ] || falhas+=("RPO estourado: backup com ${idade_min}min, limite ${rpo}min")
  fi
fi

# --- 2. restaurar, cronometrando (o RTO) ------------------------------------------------------
inicio=$(date -u +%s)
# Operacoes do ops, direto por argv: sem eval, sem bash -c, sem string de shell vinda do JSON.
if [ -n "$backup" ]; then
  if BACKUP="$backup" CANARIO="$canario" "$ops_bin" "${op_restaurar[@]}" >/dev/null 2>&1; then
    info "restore executou"
  else
    falhas+=("a operacao de restore falhou")
  fi
fi

# --- 3. o ORACULO: o canario voltou? ----------------------------------------------------------
if BACKUP="$backup" CANARIO="$canario" "$ops_bin" "${op_verificar[@]}" >/dev/null 2>&1; then
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
  const [rel, quando, dado, rpo, rto, idade, decorridoSeg, veredito, backup, cfgPath, ...falhas] = process.argv.slice(1)
  const fs = require("fs")
  const custos = JSON.parse(fs.readFileSync(cfgPath, "utf8")).custos ?? null
  fs.writeFileSync(rel, JSON.stringify({
    schema: "schematize-infra/drill-relatorio@2",
    quando, dado, veredito, custos,
    rpo_minutos: Number(rpo), rto_minutos: Number(rto),
    idade_backup_minutos: idade === "" ? null : Number(idade),
    duracao_restore_segundos: Number(decorridoSeg),
    backup, falhas,
  }, null, 2) + "\n")
' "$rel" "$agora_iso" "$dado" "$rpo" "$rto" "$idade_min" "$decorrido_seg" "$veredito" "$backup" "$cfg" "${falhas[@]}"
echo "relatorio: $rel" >&2

# --- 5. publicar o relatorio (piso 22/26): commit + push NA HORA, no repo do archive ----------
# Relatorio que so existe nesta maquina nao prova nada. Falha ao publicar tambem reprova o drill.
if [ -z "${DR_NO_COMMIT:-}" ]; then
  rdir="$(dirname "$rel")"
  if git -C "$rdir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if git -C "$rdir" add -- "$rel" \
       && git -C "$rdir" commit -q -m "infra(drill): $dado $veredito $agora_iso" -- "$rel" \
       && git -C "$rdir" push -q; then
      info "relatorio publicado (commit+push)"
    else
      falhas+=("relatorio gravado mas NAO publicado (commit/push falhou) — piso 22")
      veredito=reprovado
    fi
  else
    falhas+=("relatorio fora de repo git: $rdir — aponte 'relatorios' para <projeto>_archive/ (piso 22)")
    veredito=reprovado
  fi
fi

if [ ${#falhas[@]} -gt 0 ]; then
  erro "DRILL REPROVADO — ${#falhas[@]} problema(s):"
  for f in "${falhas[@]}"; do echo "  · $f" >&2; done
  echo "  Backup cujo restore nao foi provado nao e backup." >&2
  exit 1
fi
echo "✔ restore PROVADO para '$dado': ${decorrido_seg}s <= RTO ${rto}min, backup com ${idade_min}min <= RPO ${rpo}min"
