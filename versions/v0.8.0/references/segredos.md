<!-- cross-skill: dockerfile.md, check-dockerfile.sh -> schematize-docker -->
# Segredos — nunca no repo, cofre + rotação, scan que trava

> Segredo é a chave do reino. A casa trata segredo como **radioativo**: nunca no repo, nunca em
> layer de imagem, nunca em `.env` commitado; mora em **cofre**, é **rotacionado**, e um **secret
> scan trava o merge** antes do vazamento. Este reference é o *como* do piso "segredo nunca no
> cliente/no repo" da `schematize-engineering` (seguranca.md §13.4, cadeia-suprimentos.md §S5).

Se o cliente pode ver, o atacante já viu. Se está no git, está no histórico **pra sempre** (mesmo
depois de apagado) — e num repo público, já foi coletado. "Bota a senha pra funcionar" não é
solução, é **vazamento agendado**.

## 1. Onde segredo NUNCA pode estar (VETADO — sem ADR)

- **No código** (constante, string literal, config hardcoded).
- **No git** — nem em `.env` commitado, nem em arquivo de config versionado, nem em comentário,
  nem em issue/PR/commit message.
- **Em layer de imagem** — `ARG`/`ENV` persistido, `COPY .env`, `RUN echo $SECRET`. Layer é
  **inspecionável** (`docker history`, extração de camada). Segredo de build só por mecanismo
  **efêmero** (BuildKit secret mount) — a receita e o gate são da
  `schematize-docker -> references/dockerfile.md` e `schematize-docker -> scripts/check-dockerfile.sh`.
- **No bundle do front** — `NEXT_PUBLIC_`/`VITE_`/`PUBLIC_` **expõe por definição**; usar só pra
  valor de outdoor (URL pública, id de analytics público). Service-role key / admin SDK no client
  é CVE.
- **Em log/trace/erro** — segredo, token, JWT, senha **nunca** logados (`observabilidade.md`).
- **Em `localStorage`/`sessionStorage`** — token de sessão vai em cookie `HttpOnly`+`Secure`+
  `SameSite` (regra do front).
- **Em query string / URL** — acaba em log, histórico, referer.

## 2. Onde segredo DEVE estar — o cofre

- **Storage dedicado:** HashiCorp Vault, AWS/GCP/Azure Secret Manager, SOPS+age, ou
  **sealed-secrets**/**External Secrets** no k8s. O segredo é **cifrado em repouso**, com acesso
  **auditado** e **least-privilege** (cada serviço lê só os seus).
- **Referência pelo seed, não valor no seed.** O `/<app>/.env` (seed global — `isolamento.md` §5)
  **referencia** o cofre (`secret://…`, `VAULT_PATH`), não carrega o valor. O valor real é
  **injetado em runtime**, nunca versionado.
- **Injeção em runtime:** o serviço recebe o segredo como env/arquivo montado **no boot**, do
  cofre — não da imagem, não do repo. Rotação no cofre → serviço relê (ou é reciclado).
- **State de IaC pode conter segredo** (`iac.md` §3): trate o backend do state como dado
  confidencial (cifrado, acesso restrito).

## 3. Rotação — documentada e exercida

- **Toda credencial tem política de rotação documentada** (quem, com que frequência, como). Segredo
  eterno é segredo comprometido esperando acontecer.
- **Rotação sem downtime:** suporte a **duas chaves válidas** na janela de troca (a nova e a
  antiga) — emite com a nova, aceita ambas, depois revoga a antiga. Chave de assinatura de JWT,
  API key de terceiro, credencial de banco: todas rotacionáveis sem derrubar o serviço.
- **Credencial de curta duração** onde der (tokens de IAM de nuvem via OIDC/workload identity, não
  chave estática de longa vida). Menos tempo de vida = menos janela de abuso.

## 4. Secret scan — trava antes do merge

- **Secret scan no pipeline** (gitleaks / trufflehog) **travando o merge** — pega o segredo
  **antes** de entrar no histórico. `.env` real fica **fora do git** (`.gitignore` + `.env.example`
  só com placeholders).
- **Scan do histórico** periodicamente (o segredo pode ter entrado antes do scan existir).
- **Pre-commit hook** local como primeira barreira (defesa em profundidade) — mas o gate **é o
  CI**, não a boa vontade do dev.

## 5. Vazou — o procedimento (rotação imediata)

Segredo real encontrado no repo, em log, no rastro do archive, num screenshot — **é incidente**:

1. **Rotacionar imediatamente** a credencial vazada (revoga a antiga no provedor/cofre). Apagar o
   commit **não basta** — o segredo já foi exposto; presuma comprometido.
2. **Purgar do histórico** (`git filter-repo`/BFG) e forçar rotação de qualquer coisa derivada.
3. **Investigar uso indevido** (logs de acesso do provedor) no intervalo em que esteve exposto.
4. **Registrar no archive** (incidente + rotação) e, se recorrente, um ADR de causa-raiz (por que
   um segredo chegou ali? falta de scan? processo? — conserta o processo, não só o sintoma).

> Mecânica de purga do histórico, rotação do que vazou e push protection:
> `schematize-git → references/segredos.md`. Condução da resposta (SEV, papéis, comunicação,
> postmortem): `schematize-incident`.

> A auditoria/o scan que **acha segredo no rastro sinaliza rotação**, nunca só "remova a linha".
> Sanitize evidências: nunca cole segredo/credencial/dado real de cliente em relatório ou archive.

## 6. Segredo no runtime — princípio do menor privilégio

- **Cada serviço lê só os segredos que usa** — política do cofre por serviço/user
  (`isolamento.md`). Um serviço comprometido não drena o cofre inteiro.
- **Sem segredo compartilhado entre serviços** onde der (cada um a sua credencial — rastreável e
  rotacionável isoladamente).
- **Token de CI escopado e efêmero** (`entrega.md` §7): sem segredo amplo, sem admin token; OIDC
  pra nuvem em vez de chave estática no secret do runner.

## 7. Segredo POR AMBIENTE — chave de produção não existe fora de produção

Caso especial e de dano assimétrico: **credencial de provedor de efeito externo** (e-mail/SMS/
push/PSP). Aqui o vazamento não é o único risco — o **uso legítimo, no ambiente errado**, já é o
incidente: um laço em hml com a chave de prd manda e-mail **de verdade**, queima a reputação do
domínio e derruba o transacional de produção (inclusive o **OTP de login**). Piso da casa e
normativa: `schematize-engineering` → `references/efeitos-externos.md`; as camadas de rede/DNS
estão em `iac-efeitos-externos.md` §7.

- **Chave de não-prd é SANDBOX, sempre.** Chave sandbox do provedor (SES sandbox, test key do
  Resend/Postmark/Stripe/Twilio) no seed de dev/hml. **VETADO** "é a mesma chave, é só não usar".
- **A chave de prd não EXISTE fora de prd** — e isso é enforcement do cofre, não disciplina.
  O path é **por ambiente** e a policy do runtime de não-prd simplesmente **não enxerga** o de prd:

```hcl
# Vault policy do runtime de hml — least-privilege literal
path "secret/data/<app>/hml/mail" { capabilities = ["read"] }
# NAO existe stanza para secret/data/<app>/prd/* -> deny-by-default do Vault. Nem le, nem lista.
```

- **Seed por ambiente** (`isolamento.md` §5): `/<app>/.env` de dev/hml referencia o path sandbox
  e traz `MAIL_PROVIDER=sink`; o `.env.example` do repo nunca carrega chave de provedor real,
  nem "comentada pra facilitar".
- **Secret scan com regra própria** pro prefixo do provedor (`SG.`, `re_`, `sk_live_`, `AKIA…`
  com permissão de SES): achar **chave de prd num artefato/seed de não-prd** é **incidente** — vale
  o §5 inteiro (**rotação imediata**), porque presume-se que ela já rodou fora do lugar.
- **CI:** o job de dev/hml **não recebe** o secret de prd (environment protection do GitHub
  Actions com secret escopado por environment, não secret de repo compartilhado — `entrega.md` §7).
- Mesma regra para **PSP** (chave de teste, sempre), **SMS/voz** (credencial de teste + magic
  numbers), **push** (APNs sandbox / projeto FCM de teste) e **webhook de terceiro** (endpoint de
  sink interno, nunca a URL do parceiro).

> Regra de bolso: **o repo, a imagem e o log não guardam segredo — o cofre guarda.** Nunca no
> código, nunca no layer, nunca no bundle, nunca no log. Rotação documentada e exercida; scan que
> trava; vazou = rotaciona **já**. O front pede ao servidor; o servidor lê do cofre.
