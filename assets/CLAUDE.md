# CLAUDE.md — Infra/DevOps/SRE da Casa (sempre on)

> Copie para a **raiz do repositório** e ajuste `<project>`. Fica pinado no contexto de toda
> tarefa e garante o piso mesmo quando a skill `schematize-infra` não dispara sozinha. Em repo
> multi-skill, use **junto** com os `CLAUDE.md` das skills de engenharia/linguagem (rode
> `/infra-claude` que mescla, sem sobrescrever os outros blocos).

## Regra mestre

Este sistema roda em produção com **blast radius mínimo, tudo declarado e tudo auditado**. A skill
`schematize-infra` rege como se provisiona, deploya e opera a infra da casa. Em conflito entre
"faço na mão rapidinho que resolve" e este piso, **o piso vence**. Consulte o reference antes de
agir — não trabalhe de memória. Segurança **ofensiva** (provar que fechou) é a `schematize-pentest`.

## Pisos inegociáveis (VETADO — sem exceção)

1. **Isolamento por aplicação.** Cada serviço roda confinado: **user Linux dedicado** + **systemd
   unit hardened** (`NoNewPrivileges`, `ProtectSystem=strict`, capabilities mínimas) + **container
   não-root/read-only**. **Nunca** `root`; **nunca** dois serviços no mesmo user. Blast radius
   contido é design.
2. **Deny-by-default e least-privilege em tudo.** Rede, IAM de nuvem, capabilities, filesystem,
   token de CI — começam **fechados**, abrem só o mínimo nomeado e revisável. `0.0.0.0/0` fora do
   ponto público, `"*"` no IAM, admin token no CI = **achado**, não conveniência.
3. **Infra é código — nada de mão no servidor.** Declarativa, idempotente, revisável (IaC +
   `<project>_ops`), com `plan` antes do `apply` e **drift detection**. O servidor é **imutável por
   edição manual**: recebe só artefato promovido do git (commit SHA). "Editei direto no prd" é
   VETADO — mão no servidor é break-glass **auditado**, nunca o fluxo.
4. **Deploy GATED onde a casa exige.** Fluxo fixo `dev local → teste local verde → GitHub → hml →
   prd`; **nada pula etapa**, nada vai direto pra hml/prd. Onde a casa pede **deploy manual/gated**
   (ex.: o **front na Vercel**), respeite o gate. Hotfix segue o mesmo trilho, acelerado.
5. **Segredo nunca no repo.** Nunca em código, layer de imagem, `.env` commitado, `NEXT_PUBLIC_`,
   `ARG`/`ENV`, log. Cofre (Vault/Secret Manager/sealed-secrets) + **rotação documentada** +
   **secret scan que trava a promoção** (gate local por commit). Segredo achado no rastro → **rotação imediata**.
6. **Observabilidade integrada, não posterior.** Todo serviço nasce com logs estruturados (sem
   PII), métricas RED/USE, traços por `trace_id`, **SLO com error budget** e alertas versionados.
   Sem `/health` `/ready` `/metrics` + dashboard + alerta + chart, o serviço **não é "pronto"**.
7. **Backup com restore TESTADO.** RPO/RTO definidos por dado; backup cujo restore nunca foi provado
   **não é backup**. Restore ensaiado periodicamente (DR drill); migração de dado **reversível**
   (`down` + backup). Apagar dado é gated, só dev/hml.
8. **Cadeia de suprimentos de primeira classe.** Lockfile commitado, **SBOM** versionado com o
   artefato, scan que **trava** em `high`/`critical` sem ADR, imagem **pinada por digest**
   (`@sha256`, nunca `latest`), **assinatura verificada na admissão**. Build limpo a partir do git (dev/hml de build quando existe, piso 29); CI remoto só na promoção (piso 27).
9. **Tudo auditado.** Toda operação de infra passa pelo `<project>_ops` e **grava rastro** (§28);
   operação sensível vai pra **trilha de auditoria imutável**. O que não está no ops/IaC **não
   aconteceu**.

10. **Efeito externo NUNCA sai de não-produção (e-mail, SMS/voz, push, webhook, cobrança) — as
    camadas de INFRA.** **(a) DNS:** o domínio de teste `test.<domain>` é declarado na IaC com
    **null MX (RFC 7505: `MX 0 .`) + SPF `v=spf1 -all` + DMARC `p=reject`** (ou TLD reservado
    `.test`/`.invalid`/`.example`) e **provado por `dig`** no CI/`ops doctor`. **(b) Rede:**
    **egress SMTP 25/465/587/2525 BLOQUEADO em dev/hml** (NetworkPolicy/SG/NACL/nftables — `reject`,
    não `drop`), incluindo o egress pro endpoint real de PSP/webhook de parceiro. **(c) Segredo:**
    chave **sandbox** no seed de não-prd; a **chave de prd não existe fora de prd** (policy do cofre
    nega o path). **(d) Provedor:** **subdomínio de envio separado por ambiente**
    (`mail.<domain>` prd vs `mail-hml.<domain>` hml, DKIM/SPF próprios na IaC) e **alerta** de
    bounce > 2% / complaint > 0,1% + **envio real fora de prd = página imediata**. **VETADO** reusar
    o remetente de prd fora de prd, enviar pelo domínio raiz e apontar o domínio de teste pra caixa
    real. **Por quê:** bounce/complaint em massa **queima IP e domínio**, derruba o transacional de
    **produção** (inclusive o **OTP de login**) e custa **semanas de warm-up**. Normativa:
    `schematize-engineering` → `references/efeitos-externos.md`; o *como* de infra em `iac-efeitos-externos.md` §7,
    `segredos.md` §7, `observabilidade.md` §9.

11. **Tudo vai pro git; deploy SOMENTE do git (pisos 22-23).** Sem remote acessível e `HEAD ==
    origin`, a demanda não conclui. **VETADO** `scp`/`rsync`/`tar|ssh`/`docker save|load`/editar
    remoto; o **ops, na VPS**, clona/atualiza do git e verifica o **SHA/tag exato**
    (`entrega.md` §8). **Única exceção, ESCOPADA (piso 29):** a máquina de **build/teste dev/hml**
    (`entrega.md` §8.1) aceita ponte direta, só p/ build/teste, no workspace remoto de build; o que
    sai dela **não é artefato promovível**. Continua vetado: prd, deploy/promoção por ponte, dado,
    volume, `.env` e segredo de prd, efeito externo real.
12. **O ops é o GATE da IA (piso 24).** A IA só altera a VPS por `unattended-upgrades`/`apt` e pelo
    mínimo (`git`) para clonar o ops; depois conversa **só com o ops** (operações nomeadas e
    tipadas; sem SQL/script/comando mutável próprio; **sem ssh mutável**). Falta comando →
    implementa no repo do ops via git, nunca contorna por ssh. Break-glass: humano e auditado,
    nunca da IA (`isolamento.md` §7). O piso 29 **não alarga** este: a ponte vale na máquina de
    build/teste dev/hml (`isolamento.md` §7.1), nunca no ambiente de implantação nem em prd.

## Como se opera aqui

- **Deploy (`/infra-deploy`):** fluxo fixo + artefato imutável com proveniência git + estratégia
  (rolling/blue-green/canary) + healthcheck gating + rollback automatizado; respeita o gate
  manual (front/Vercel, prd).
- **IaC (`/infra-iac`):** declarativa/idempotente/revisável, `plan` antes do `apply`, drift
  detection, state seguro, layout `/<app>/` + seed, ops como interface única.
- **Segredos (`/infra-secrets`):** nada no repo/layer, cofre + rotação, secret scan que trava,
  referência pelo seed; vazou = rotaciona já.
- **Observabilidade/Resiliência:** LGTM+ integrado, SLO/alertas versionados; backup/DR com restore
  testado, rede deny-by-default, TLS que renova sozinho, supply-chain (SBOM/pinning/assinatura).

## Relação com as outras skills

- **schematize-engineering** — a base: o **ops como interface única** (§2), o **fluxo de deploy**
  (§21), a **observabilidade LGTM+** (§16), a **cadeia de suprimentos** e o **archive** (§28). Esta
  skill é o *como* de infra disso.
- **schematize-pentest** — o oráculo do hardening: a infra fecha a porta; a pentest **prova** que
  fechou. Hardening sem teste de rejeição é suspeita, não fato.

## Orquestração

<!-- herdado:engineering/orquestracao:curto -->**Orquestrador não desenvolve; subagent barato executa.** O agent principal só planeja, despacha e revisa; ação onerosa vira micro-tasks para o executor mais barato que resolve: `haiku` (mecânico) / `sonnet` (código; falhou → mesmo subagent corrige, até 2 rodadas) → Codex `gpt-5.6-terra` → Cursor → subagent `opus` (motivo) → `park`; **visual vai direto ao Codex**; **imagem nunca pelo Claude: detectar Codex/Gemini e perguntar ao usuário qual usar (Codex é a sugestão), nunca API de imagem paga**; papéis em `agentes.toml`. No overdev, cada item do checklist vai a um subagent e o principal revisa antes do `- [x]`. **Sem frota ociosa:** idle com pendência volta ao trabalho; dependente de outro agent → mata e enfileira com gatilho; terminou → mata (§9.6). Detalhe: `schematize-engineering` → `references/orquestracao.md` §9.<!-- /herdado -->

Herda os pisos 22–29 da `schematize-engineering` (git como trava de conclusão, deploy só do git, ops é o gate da IA, sem agents inúteis, relatório 30 min/handoff 6 h, CI remoto só antes do hml, microserviço autônomo, build em dev/hml + higiene).

## Gestão de contexto (sessões longas)

Ao se aproximar do teto de contexto: **PARE e** gere o handoff em `<project>_archive/context/`
(estado da infra + FEITO vs EM ABERTO) **antes** de compactar (`/infra-cc`).
