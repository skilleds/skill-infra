<!-- cross-skill: cadeia-suprimentos.md -> schematize-engineering -->
<!-- cross-skill: dockerfile.md, supply-chain.md, runtime.md -> schematize-docker -->
# Resiliência — backup & DR, rede/TLS/hardening, cadeia de suprimentos

> Três frentes que decidem se o sistema **sobrevive** ao dia ruim: o dado volta depois do desastre
> (**backup & DR com restore testado**), a porta está fechada por padrão (**rede/TLS/hardening
> deny-by-default**) e o que você embarca é o que você acha que embarcou (**cadeia de
> suprimentos**). Este reference consolida o *como* de infra do §21/§13 da
> `schematize-engineering` e da `cadeia-suprimentos.md`.

## 1. Backup & DR — RPO/RTO e o restore que se PROVA

- **RPO e RTO definidos por dado.** **RPO** (quanto de dado você aceita perder — a janela entre
  backups) e **RTO** (quanto tempo até voltar) são **decisão de negócio, escrita**, não implícita.
  Dado de billing tem RPO/RTO diferente de cache.
> **O drill tem forma:** `scripts/dr-drill.sh` (comando `/infra-drill`). Ele restaura, cronometra
> contra o RTO, confere a idade do backup contra o RPO e exige o **canário** — e `--frescor` reprova
> o drill que envelheceu. Sem `comandos.verificar` ele nem roda: *"o restore não deu erro"* é a
> esperança que este parágrafo proíbe.

- **Backup cujo restore NUNCA foi testado NÃO é backup — é esperança.** O piso: **restore
  ensaiado periodicamente** (DR drill / game day) num ambiente limpo, cronometrado contra o RTO,
  verificado contra o RPO. Backup que ninguém restaurou é dado corrompido esperando o incidente pra
  se revelar.
- **Postgres tem dona.** Backup base + WAL, PITR, `pg_dump` vs físico, retenção e o restore de banco
  passo a passo: `schematize-postgres → references/backup-e-pitr.md`. Aqui fica o piso (RPO/RTO
  escritos, drill cronometrado, canário); lá, o mecanismo.
- **3-2-1:** 3 cópias, 2 mídias, 1 offsite. Backup **cifrado** (em trânsito e repouso) e com
  **acesso separado** do sistema principal (ransomware não pode cifrar o backup junto). Considere
  cópia **imutável**/WORM pra billing/auditoria.
- **Backup ANTES de migração destrutiva** (`iac.md`, `entrega.md`): migração de schema é
  **reversível** (`down` testado) e precedida de backup. `reset`/apagar dado é comando **gated, só
  dev/hml**, nunca prd (`isolamento.md` §5).
- **Resposta ao incidente** (papéis, SEV, comunicação, postmortem blameless) é da
  `schematize-incident`; o drill reprovado abre incidente por lá.
- **Runbook de DR** ensaiado: passo a passo de "a região caiu, e agora?" — quem faz o quê, em que
  ordem, com que comando do ops. Registre o resultado do drill no archive.

## 2. Redes — deny-by-default e segmentação

- **Tudo começa fechado.** Firewall / security group / NetworkPolicy **nega por padrão**; abre só
  o fluxo necessário e **nomeado** (`isolamento.md` §4). Sem `0.0.0.0/0` fora do ponto de entrada
  público (e esse atrás de WAF/proxy). **Egress** também restrito — corta exfiltração e SSRF de
  saída.
- **Segmentação:** public / private / data subnets; o banco **nunca** exposto à internet; bastion/
  túnel para acesso administrativo, não IP público no Postgres.
- **Zero-trust interno:** identidade de serviço (mTLS/SPIFFE), não confiança por estar na mesma
  rede. "Está na VPC, então é confiável" é premissa furada.

## 3. TLS e criptografia — em trânsito e repouso

- **TLS 1.2+ (prefira 1.3)** em toda borda pública; cifras fortes, HSTS. **Sem TLS terminado e
  esquecido**: certificado **automatizado** (cert-manager / ACME) com **renovação automática** —
  certificado vencido é incidente evitável.
- **mTLS interno** entre serviços onde a malha permite (autenticação mútua de serviço).
- **Criptografia em repouso** para dado pessoal/sensível (disco, banco, backup — §32 LGPD da
  engenharia). Chave no cofre, rotacionável (`segredos.md`).

## 4. Hardening — least-privilege em todas as camadas

- **IAM de nuvem least-privilege:** política com **ação e recurso específicos**, nunca `"*"`.
  Sem chave estática de longa vida — **OIDC/workload identity** com credencial de curta duração
  (`segredos.md`). Sem credencial de root/owner em automação.
- **Container/host hardened** (`isolamento.md`; flags em `schematize-docker -> references/runtime.md`): não-root, read-only, `drop ALL` capabilities,
  `seccomp`, `NoNewPrivileges`, imagem mínima. Host com patch em dia, SSH por chave (sem senha),
  sem porta desnecessária aberta.
- **Superfície mínima:** menos serviço exposto, menos pacote instalado, menos permissão concedida
  = menos CVE e menos caminho de ataque. Deny-by-default é o tema que atravessa tudo.
- **A pentest prova o hardening.** Fechar a porta é infra; **provar que fechou** (SSRF, exposição
  de segredo, escalonamento de privilégio, cross-tenant) é a `schematize-pentest`. Hardening
  "revisei e tá seguro" sem teste que prove a rejeição é **suspeita, não fato**.

## 5. Cadeia de suprimentos — você entrega tudo que embarca

O ataque hoje raramente é no seu código: é numa dependência, numa imagem base ou no pipeline. Trate
build e dependência como **superfície de ataque de primeira classe** (`cadeia-suprimentos.md`).

- **Dependências:** **lockfile commitado**, build reproduzível a partir dele; verificar **nome e
  licença** de toda dependência nova (typosquatting é real; allowlist MIT/Apache-2.0/BSD/MPL-2.0/
  ISC — GPL/AGPL/SSPL/proprietária só com ADR); minimizar superfície transitiva. **VETADO** fixar
  por branch (`main`) em prd e `curl | sh` de origem não verificada no build.
- **SBOM:** gerar (CycloneDX/SPDX) no build e **versionar junto ao artefato** — é o inventário do
  que foi de fato embarcado (`syft`, `cargo cyclonedx`).
- **Scan que trava:** SAST (Semgrep/CodeQL), SCA (deps + licenças), container scan (Trivy/Grype),
  secret scan (Gitleaks) — **travam o merge** em `high`/`critical` sem ADR de aceite datado.
  Vulnerabilidade aceita conscientemente vira **ADR com prazo**, não silêncio.
- **Imagem:** pinada por digest, multi-stage, não-root; rebuild periódico para absorver patch da base —
  o como é da `schematize-docker -> references/dockerfile.md` e `-> references/supply-chain.md`.
- **Proveniência (SLSA):** **build só no CI** (não na máquina do dev pra prd), a partir do código
  versionado — o pipeline é parte da TCB. **Assinar** o artefato/imagem (cosign/sigstore) e
  **verificar a assinatura na admissão** (deploy só aceita imagem assinada por pipeline confiável —
  assinar sem verificar não protege). **Atestação de build**: quem buildou, de qual commit, com
  qual SBOM; a tag inclui o commit.
- **Segredo no build:** nenhum segredo em layer (`segredos.md` §1); BuildKit secret mount efêmero;
  permissões mínimas no CI (token escopado).

## 6. Resiliência de runtime — degradação graciosa

- **Cada serviço sobe sozinho**, sem exigir outro no boot — **degradação graciosa** (outbox/retry/
  fila/circuit breaker) em vez de cascata. É o mesmo invariante do "falha no paralelo = bug de
  independência" (`isolamento.md` §6). Um serviço lento/fora não derruba os que dependem dele: eles
  degradam, não caem.
- **Timeout, retry com backoff e circuit breaker** em toda chamada externa/fila/banco. Sem
  timeout, uma dependência lenta vira thread exhaustion e o serviço inteiro trava.
- **Limite de recurso** (`MemoryMax`/limits do k8s) — um serviço em loop não estrangula o host
  (`isolamento.md` §2).

> Regra de bolso: **backup só conta depois do restore provado; a porta só conta fechada por
> padrão; o artefato só conta se você sabe exatamente o que tem dentro e quem o produziu.** RPO/RTO
> escritos e ensaiados, deny-by-default na rede/IAM, TLS que renova sozinho, SBOM + pinning +
> assinatura verificada. Sobreviver ao dia ruim é design, não sorte.

## 7. Chaos engineering — o modo `chaos` tem dono, definição, oráculo e gate

> **A `schematize-infra` é a dona do `chaos`.** Até 2026-08-21 ele era citado **12 vezes** na
> `schematize-qa` (no CLI do test kit, no plano do `/qa-plan`, na matriz nightly, como passo
> destrutivo com gate) e **não existia em lugar nenhum**: `grep -i chaos` na pentest, na
> engineering e aqui dava **zero**. Um modo que **apaga serviço e derruba banco** sem dono,
> definição, oráculo nem exemplo é pior que um modo inexistente — porque parece que alguém
> pensou nele.

**Definição.** Chaos não é "quebrar coisas para ver o que acontece": é **experimento controlado**
que injeta uma falha **prevista** para verificar uma **hipótese explícita** sobre degradação
graciosa (§6). Sem hipótese escrita antes, é sabotagem com relatório.

**O experimento tem 5 partes — todas obrigatórias:**

| Parte | O que é | Exemplo |
|---|---|---|
| **Estado estável** | a métrica que define "saudável", medida ANTES | p95 de `/checkout` < 400 ms, taxa de erro < 0,5% |
| **Hipótese** | o que você afirma que continua valendo sob a falha | *"com o `payments` fora, `/checkout` responde 503 com `Retry-After` em < 1 s e nenhum pedido é perdido"* |
| **Injeção** | a falha, escopada e reversível | matar o processo de UM serviço; cortar a rota para o banco réplica; injetar 300 ms de latência num upstream |
| **Raio de explosão** | o limite declarado ANTES | 1 serviço, 1 zona, 5 minutos, ambiente ≤ hml |
| **Abort** | a condição que **encerra o experimento sozinha** | estado estável violado por > 60 s → rollback automático |

**Oráculo (o que faz o experimento PASSAR ou REPROVAR)** — e é aqui que ele deixa de ser teatro:

- **PASSA** quando a hipótese se sustenta: a degradação foi **a prevista**, o alerta **disparou**,
  o dado **não se perdeu** (outbox/fila reteve), e o sistema **voltou sozinho** ao estado estável
  depois que a injeção parou.
- **REPROVA** quando: cai em cascata (fere a independência de runtime — `schematize-engineering`
  §2/§18), perde escrita aceita, **não** alerta, ou não se recupera sem intervenção manual.
- **REPROVA TAMBÉM quando "não aconteceu nada"** — se derrubar a dependência não mudou métrica
  nenhuma, ou o serviço não a usava, ou a injeção não pegou. *"Nada aconteceu" é resultado
  inválido, não sucesso* — a mesma disciplina do verde-mentiroso.

**Exemplo executável (o mínimo viável, sem plataforma de chaos):**

```bash
# hipótese: com o `payments` fora, /checkout degrada para 503 e nenhum pedido se perde.
ops health --json > /tmp/antes.json                      # 1) estado estável
systemctl stop payle-payments                            # 2) injeção escopada
sleep 60                                                 # 3) raio: 60s, 1 serviço, hml
curl -s -o /dev/null -w '%{http_code}\n' "$API/checkout"  # espera 503
ops queue depth --queue orders                           # espera: reteve, não descartou
systemctl start payle-payments                           # 4) reverte SEMPRE
sleep 30 && ops health --json > /tmp/depois.json          # 5) voltou sozinho?
diff <(jq -S . /tmp/antes.json) <(jq -S . /tmp/depois.json)
```

**Gate de segurança (inegociável):**

- **Nunca em `prd` sem as cinco condições:** ADR aprovado, janela combinada, dono de plantão
  presente, raio declarado e mecanismo de abort **testado antes**. Sem as cinco, chaos é `dev`/`hml`.
- O test kit exige `<PROJECT>_CHAOS_ALLOW=1` **e** aprovação do plano (`/qa-plan`) — dois gates,
  porque a variável sozinha é fácil demais de exportar sem pensar.
- **Efeito externo continua valendo:** derrubar serviço não autoriza envio real
  (`schematize-engineering` → `references/efeitos-externos.md`).
- **Todo experimento vira registro** em `<projeto>_archive/` — hipótese, resultado, e o que mudou
  por causa dele. Chaos que não gerou correção nem confirmação registrada foi só downtime.

> **Fronteira:** a **`schematize-qa`** *invoca* o modo (é um passo da malha plan-first, destrutivo
> e gated) e reporta o resultado; a **definição, o oráculo e o gate são desta skill**. A
> **`schematize-pentest`** não é dona de chaos: ela prova **rejeição**, não **resiliência**.

