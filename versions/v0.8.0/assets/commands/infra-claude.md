---
description: schematize-infra — cria ou mescla o CLAUDE.md sempre-on de infra na raiz do repo (não sobrescreve blocos de outras skills)
---

Instale/atualize a regra **sempre-on** de infra/DevOps/SRE na raiz do repositório.

1. Pegue `assets/CLAUDE.md` da skill `schematize-infra` (projeto ou `~/.claude/skills/...`).
2. Se **não existe** `CLAUDE.md` na raiz: crie com esse conteúdo.
3. Se **já existe** (de outra skill — engineering/go/rust/web/pentest/...): **mescle** — adicione
   a seção de Infra/DevOps/SRE **sem sobrescrever** os blocos das outras skills. Em repo
   multi-skill, cada CLAUDE convive; o piso da infra é aditivo.
4. Se houver customização local, salve `./CLAUDE.md.bak` e reaplique por cima.
5. Confirme a versão aplicada e destaque o **piso**: isolamento por app, deny-by-default,
   nada de mão no servidor (infra é código), deploy gated onde a casa exige, segredo nunca no repo,
   backup com restore testado, supply-chain (SBOM/pinning/assinatura), tudo auditado.
