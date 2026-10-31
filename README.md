# schematize-infra

> **Infra/DevOps/SRE** da casa — a disciplina de operar sistema em produção com **blast radius
> mínimo, tudo declarado e tudo auditado**, deny-by-default. Isolamento por app (user Linux +
> systemd hardened + container por serviço), IaC declarativa/idempotente/revisável, deploy
> **GATED** (nada pula etapa; front manual/gated), segredo **nunca no repo** (cofre + rotação),
> observabilidade integrada (SLO/alertas), backup & DR com **restore testado**, redes/TLS/
> hardening e cadeia de suprimentos (SBOM/pinning/assinatura).

Pacote de **skill normativa para [Claude Code](https://claude.com/claude-code)**.
Parte do catálogo **schematize skills**. Disciplina **agnóstica de linguagem** que pareia com a
`schematize-engineering` (a base: ops §2, deploy §21, observabilidade §16, cadeia de suprimentos,
archive §28) e delega a segurança **ofensiva** (provar que fechou) à `schematize-pentest`.

## Instalar

### Pelo app schematize (recomendado)

```bash
schematize install infra      # requer o CLI schematize instalado
```

### Última versão (a partir de um clone)

```bash
git clone https://github.com/schematizeme/skill-infra.git
cd skill-infra && ./install.sh            # instala no projeto atual
# ./install.sh /caminho/do/projeto          # ou aponte para outro projeto
```

Ou baixe o `.zip` da última release e descompacte em `.claude/skills/`:

```bash
curl -L -o skill-infra.zip \
  https://github.com/schematizeme/skill-infra/releases/latest/download/skill-infra.zip
unzip skill-infra.zip -d .claude/skills/
```

## O que tem dentro

- **SKILL.md** — o contrato: 12 pisos inegociáveis (isolamento por app, deny-by-default,
  infra é código, deploy gated, segredo fora do repo, observabilidade integrada, backup com
  restore testado, cadeia de suprimentos, tudo auditado) + mapa de references.
- **references/** — `isolamento` (user Linux + systemd hardened + container por serviço, blast
  radius), `iac` (declarativa/idempotente/revisável, plan-before-apply, drift, ops como interface
  única), `entrega` (CI/CD gated, imagem, estratégia + healthcheck gating + rollback), `segredos`
  (cofre + rotação + scan que trava), `observabilidade` (LGTM+, SLO/alertas, healthchecks),
  `resiliencia` (backup & DR com restore testado, rede/TLS/hardening, supply-chain).
- **assets/commands/** — `/infra-help`, `/infra-deploy`, `/infra-iac`, `/infra-secrets`,
  `/infra-load`, `/infra-claude`, `/infra-cc`, `/infra-handoff`.
- **assets/CLAUDE.md** — regra sempre-on: blast radius mínimo, tudo declarado, tudo auditado.

## Regra de ouro

**Blast radius mínimo, tudo declarado, tudo auditado — deny-by-default.** Cada serviço roda
isolado (um comprometimento não vaza pros vizinhos); toda infra é código (jogue o servidor fora e
reconstrua do git com um comando); o deploy é gated onde a casa exige; o segredo mora no cofre, não
no repo; o backup só conta depois do **restore provado**. A infra fecha a porta; a
`schematize-pentest` **prova** que fechou.

## Relação com as outras skills

- **schematize-engineering** — a base. Esta skill é o *como* de infra do **ops como interface
  única** (§2), do **fluxo de deploy** (§21), da **observabilidade LGTM+** (§16), da **cadeia de
  suprimentos** e do **archive** (§28).
- **schematize-pentest** — o oráculo do hardening: a infra fecha a porta, a pentest prova que
  fechou; hardening sem teste de rejeição é suspeita, não fato.

## Co-autoria / patrocínio

Co-autoria / patrocínio: Lucassa — https://lucassa.me

MIT.
