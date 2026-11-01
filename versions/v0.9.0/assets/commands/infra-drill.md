---
description: schematize-infra — roda o DR drill (restaura o backup num ambiente limpo, cronometra contra o RTO, confere o RPO e o canário) e grava o relatório no archive
argument-hint: "[dado/serviço]"
---

# /infra-drill — o restore que se prova

Piso 7 desta skill: **backup cujo restore nunca foi provado não é backup — é esperança.** Este
comando é o que transforma essa frase em exit code.

## 1. O `drill.json` (no repo do serviço)

Copie `assets/templates/drill.exemplo.json`. Os comandos são **seus** — a skill não conhece seu
banco, e não deve conhecer:

| Campo | O que é |
|---|---|
| `dado` | o que está sendo restaurado (`pedidos`, `faturas`) — RPO/RTO são **por dado** |
| `rpo_minutos` | quanto de dado o negócio aceita perder. Vira a idade máxima aceitável do backup |
| `rto_minutos` | quanto tempo até voltar. Vira o cronômetro |
| `canario` | a linha que **só existe se o dado voltou de verdade** |
| `comandos.backup_mais_recente` | imprime o caminho do backup mais novo |
| `comandos.restaurar` | recebe `$BACKUP`. **Ambiente limpo**, nunca o de produção |
| `comandos.verificar` | recebe `$CANARIO`. Sai `0` só se o canário está lá |

**Sem `comandos.verificar` o drill não roda** (exit 2). "O comando de restore não deu erro" é
exatamente a esperança que o piso proíbe: restore que termina bem com o banco vazio é o caso que
mais aparece de verdade.

## 2. Rodar

```bash
bash .claude/skills/schematize-infra/scripts/dr-drill.sh drill.json
```

| Exit | Significado |
|---|---|
| `0` | **restore provado**: canário voltou, dentro do RTO, backup dentro do RPO |
| `1` | reprovou — o relatório diz qual dos quatro (sem backup · RPO estourado · restore falhou · **canário ausente** · RTO estourado) |
| `2` | configuração incompleta — não rodou, e **não** conta como "passou" |

O relatório vai para `relatorios/` (aponte para `<projeto>_archive/infra/drills/`, §28) como
`drill-<timestamp>.json`, com veredito, idade do backup e duração medida.

## 3. Frescor — o drill que envelheceu

Drill feito uma vez em 2024 não prova nada hoje. No CI (semanal ou no deploy):

```bash
bash .claude/skills/schematize-infra/scripts/dr-drill.sh --frescor ../projeto_archive/infra/drills --max-dias 30
```

Reprova em três situações: **nenhum relatório** (restore nunca foi provado — o pior estado, e o mais
fácil de confundir com "tudo certo"), último drill mais velho que a janela, e último drill que
**reprovou**.

## 4. Depois

- Drill reprovado é **incidente**, não tarefa de backlog: o dado está sem rede de proteção agora.
- Registre no archive o que falhou e o tempo real medido — RTO estimado no papel e RTO medido no
  drill raramente são o mesmo número, e o que vale é o medido.
- Todo incidente de restore vira caso novo no drill (`references/resiliencia.md` §1).

Prova do próprio gate: `bash .claude/skills/schematize-infra/scripts/dr-drill.test.sh` (14 casos,
sendo o principal o `restore-ok-canario-ausente`).
