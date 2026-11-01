---
description: schematize-infra — audita a gestão de segredos: nada no repo/layer/env commitado, cofre + rotação documentada, secret scan que trava, referência pelo seed; sinaliza rotação imediata se achar segredo vazado
argument-hint: "[dir a varrer, ex: . | infra/ | .github/]"
---

Audite a **gestão de segredos** deste projeto (`references/segredos.md`). Princípio: **segredo é
radioativo** — nunca no repo, nunca em layer, nunca em `.env` commitado; mora no cofre, é
rotacionado, e um scan trava o vazamento. Alvo: `${ARGUMENTS:-.}`.

## 1. Caça a segredo vazado (§1, §5) — PRIORIDADE
Varra código, config, `.env` versionado, layer de imagem, `.github/workflows`, histórico git:
- `git ls-files | grep -iE '\.env($|\.)' ` e confira se algum `.env` **real** está versionado;
- rode/simule `gitleaks detect` / `trufflehog` no worktree **e** no histórico;
- `docker history`/inspeção de layer por `ARG`/`ENV` de segredo, `COPY .env`;
- front: `NEXT_PUBLIC_`/`VITE_`/`PUBLIC_` com valor sensível, service-role/admin SDK no client;
- token de sessão em `localStorage`, segredo em query string/URL, segredo em log.

**Achou segredo real → é INCIDENTE:** sinalize **rotação imediata** (revoga a antiga no provedor/
cofre — apagar o commit NÃO basta), purga do histórico (`git filter-repo`/BFG), investiga uso
indevido na janela de exposição, registra no archive. Mecânica de purga e rotação: `schematize-git → references/segredos.md`; condução do incidente:
`schematize-incident`. Nunca cole o segredo no relatório (sanitize).

## 2. Onde o segredo DEVE estar (§2)
Cofre dedicado (Vault / Secret Manager / SOPS+age / sealed-secrets / External Secrets), **cifrado
em repouso**, acesso **least-privilege** (cada serviço lê só os seus). O seed `/<app>/.env`
**referencia** o cofre (`secret://…`), não carrega o valor; injeção **em runtime**, nunca na imagem.
State de IaC (pode conter segredo) tratado como confidencial.

## 3. Rotação (§3)
Toda credencial com **política de rotação documentada** (quem/quando/como); **rotação sem downtime**
(duas chaves válidas na janela); credencial de **curta duração** onde der (OIDC/workload identity,
não chave estática de longa vida).

## 4. Scan que trava (§4)
**Secret scan no CI travando o merge** (gitleaks/trufflehog); `.env` real fora do git
(`.gitignore` + `.env.example` só placeholder); pre-commit hook como 1ª barreira, mas o **gate é o
CI**. Token de CI escopado e efêmero, sem admin token.

## 5. Saída
Relatório: há segredo no repo/layer/log? cofre em uso? rotação documentada/exercida? scan trava o
merge? — cada achado com **o quê + onde + severidade + o conserto** (e **rotação** onde houver
exposição). Grave no `<projeto>_archive/`. A prova de que a porta ficou fechada (exposição
explorável) é da `schematize-pentest`.

Token de bot de chat: cofre, rotação e escopo mínimo em `schematize-bots → references/credenciais-e-token.md`.
