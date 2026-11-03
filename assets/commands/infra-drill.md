---
description: schematize-infra — roda o DR drill (restaura o backup num ambiente limpo, cronometra contra o RTO, confere o RPO e o canário) e grava o relatório no archive
argument-hint: "[dado/serviço]"
---

# /infra-drill — o restore que se prova

Piso 7 desta skill: **backup cujo restore nunca foi provado não é backup — é esperança.** Este
comando é o que transforma essa frase em exit code.

## 1. O `drill.json` (no repo do serviço)

**Quem roda:** o drill é uma **operação do ops** (`ops drill <dado>`), não a IA na mão (pisos 15 e
24). Nenhum comando do JSON vira string de shell: cada operação é um **array argv de operação
nomeada do ops** (o script não usa `eval` nem `bash -c`). Copie `assets/templates/drill.exemplo.json`:

| Campo | O que é |
|---|---|
| `dado` | o que está sendo restaurado (`pedidos`, `faturas`) — RPO/RTO são **por dado** |
| `ops` | binário do ops (ou `DR_OPS`); default `ops` |
| `rpo_minutos` | quanto de dado o negócio aceita perder. Vira a idade máxima aceitável do backup |
| `rto_minutos` | quanto tempo até voltar. Vira o cronômetro |
| `canario` | a linha que **só existe se o dado voltou de verdade** |
| `operacoes.backup_mais_recente` | imprime o **arquivo** do backup mais novo OU um **manifesto JSON** (`pgbackrest info --output=json`, PITR, objeto em bucket: `timestamp`/`timestamp.stop`/`idade_minutos`); a idade vem do manifesto, não só de `stat` |
| `operacoes.restaurar` | recebe `$BACKUP` (caminho, ou `manifesto` = o mais recente). **Ambiente limpo**, nunca o de produção |
| `operacoes.verificar` | recebe `$CANARIO`. Sai `0` só se o canário está lá |
| `custos` | opcional, vai ao relatório: ambiente do drill, storage/retenção do backup, egress |

**Sem `operacoes.verificar` o drill não roda** (exit 2). "O comando de restore não deu erro" é
exatamente a esperança que o piso proíbe: restore que termina bem com o banco vazio é o caso que
mais aparece de verdade. Para Postgres, o mecanismo do restore (base + WAL, PITR) é da
`schematize-postgres` → `references/backup-e-pitr.md`; esta é a receita única do drill.

## 2. Rodar

```bash
ops drill pedidos        # o ops chama: dr-drill.sh drill.json
bash .claude/skills/schematize-infra/scripts/dr-drill.sh drill.json   # equivalente, pelo humano/ops
```

| Exit | Significado |
|---|---|
| `0` | **restore provado**: canário voltou, dentro do RTO, backup dentro do RPO, relatório publicado |
| `1` | reprovou — o relatório diz qual (sem backup · RPO estourado · restore falhou · **canário ausente** · RTO estourado · relatório não publicado) |
| `2` | configuração incompleta — não rodou, e **não** conta como "passou" |

O relatório vai para `relatorios/` (aponte para `<projeto>_archive/infra/drills/`, §28) como
`drill-<timestamp>.json` (veredito, idade do backup, duração medida, `custos`) e **o script faz
commit + push dele na hora** (piso 22; `DR_NO_COMMIT=1` só em teste). Relatório fora de repo git ou
sem push reprova o drill.

## 3. Frescor — o drill que envelheceu

Drill feito uma vez em 2024 não prova nada hoje. Confira o frescor no gate local (`tools/ci.sh`) e
no CI remoto único de promoção (tag `hml-*`/`v*` ou `workflow_dispatch` — nunca cron por PR/commit):

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
- **Custos:** registre no relatório o custo do drill e do backup (storage, retenção, egress) —
  backup que ninguém consegue pagar é cortado no primeiro aperto.

Prova do próprio gate: `bash .claude/skills/schematize-infra/scripts/dr-drill.test.sh` (24 casos,
sendo o principal o `restore-ok-canario-ausente`).
