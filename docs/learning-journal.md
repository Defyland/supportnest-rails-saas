# Learning Journal

Este journal documenta a história do repositório até o commit `ffc173b`, que é o
`HEAD` gravado no momento desta edição.

## Como este journal usa evidências

- Base primária:
  `git log`, `README.md`, `openapi.yaml`, `docs/architecture/overview.md`,
  `docs/architecture/data-consistency.md`, services de membership/tickets/outbox
  e a suíte de integração, model e relay tests.

- Quando o texto fala de maturidade SaaS:
  a leitura se ancora em isolamento por tenant, lifecycle de token, locking,
  quotas e outbox relay, não em marketing genérico de multitenancy.

- Escopo:
  commits já gravados até `ffc173b`.

## O que o histórico não prova

- O histórico não prova escala alta de throughput multitenant.
- Não prova billing real, só quotas e limites locais.
- Não prova ecossistema grande de consumidores do outbox.

## 1. Objetivo do projeto

SupportNest existe para ensinar como modelar um helpdesk SaaS multi-tenant em
Rails sem vender uma falsa simplicidade. O repo quer deixar visível que os
problemas importantes são:

- bootstrap de tenant;
- membership token lifecycle;
- ticket workflow com optimistic locking;
- audit log;
- outbox relay e replay operacional.

Ao terminar este journal, o leitor deve conseguir:

- seguir uma mutação de ticket do request até o audit log e o outbound event;
- explicar por que owner continuity e quota enforcement existem como decisões de
  plataforma, não de UI;
- apontar onde o projeto usa banco, services e tests para defender fronteiras;
- reconstruir os principais endurecimentos do histórico.

## 2. Como ler o repositório primeiro, em ordem de aprendizado

1. Leia `README.md` e `openapi.yaml`.
2. Leia `docs/architecture/overview.md` e `docs/architecture/data-consistency.md`.
3. Leia `app/controllers/v1/organizations_controller.rb`,
   `app/controllers/v1/memberships_controller.rb` e
   `app/controllers/v1/tickets_controller.rb`.
4. Leia `app/services/organizations/bootstrap.rb`.
5. Leia `app/services/memberships/create.rb`,
   `app/services/memberships/update.rb`,
   `app/services/memberships/rotate_token.rb`,
   `app/services/memberships/revoke_token.rb`,
   `app/services/memberships/ownership_guard.rb`.
6. Leia `app/services/outbound_events/dispatcher.rb`,
   `app/services/outbound_events/relay.rb`,
   `app/services/outbound_events/replay.rb`.
7. Feche com:
   `test/integration/organizations_flow_test.rb`,
   `test/integration/membership_token_lifecycle_test.rb`,
   `test/integration/tickets_flow_test.rb`,
   `test/services/outbound_events_relay_test.rb`,
   `test/services/ticket_concurrency_test.rb`.

### O que ignorar na primeira passada

- Não comece por benchmark.
  Primeiro entenda tenant, token, ticket e outbox.

- Não trate `lock_version` como detalhe de Rails.
  Aqui ele é parte da aula sobre concorrência e segurança de escrita.

## 3. História cronológica da implementação

### Fase 1: baseline, core SaaS e primeira cobertura (`80305f7` a `0003cf3`, 2026-05-28 a 2026-05-29)

- O projeto começou com baseline documental, scaffold Rails API, core de tenant,
  auth, tickets, audit e outbox.
- Logo em seguida entrou cobertura de request/model/job, docs de arquitetura,
  benchmark inicial e compliance spec.
- O recorte é forte: o repo não cresceu primeiro como CRUD de ticket; ele nasceu
  como slice multi-tenant auditável.
- Base usada:
  commits `80305f7`, `64a1ed5`, `63bb1f0`, `bf93976`, `c230d05`, `96b27c2`,
  `c22ff32`, `0003cf3`.

### Fase 2: endurecimento de dados, auth e outbox (`5eb4118` a `a150153`, 2026-05-29 a 2026-05-30)

- Esta fase consolida o que diferencia um SaaS pequeno sério de um tutorial:
  atomicidade de mutações, check constraints, optimistic locking, token
  lifecycle, retry/backoff de outbox, PostgreSQL como banco primário e relay
  operacional.
- Base usada:
  commits `5eb4118`, `e36fe82`, `bb07599`, `8465cd9`, `9658522`, `257182a`,
  `b912f43`, `4489486`, `1b7c596`, `93d58cb`, `a150153`.

### Fase 3: remediações finas de plataforma (`6f55079` a `ffc173b`, 2026-05-31)

- A fase final é quase toda sobre bugs e limites que alguém experiente encontra
  quando para de olhar só a feature feliz.
- Entram validação de query params, throttling, schema locking de rate limit,
  owner continuity, quotas de inbox e seat reactivation, no-op audit filtering e
  host authorization em produção.
- Base usada:
  commits `6f55079`, `82b893f`, `3c67818`, `e2a5138`, `e72006d`, `6f08d5e`,
  `cf04310`, `3c8c14a`, `ffc173b`.

## Features importantes como unidades completas

### Bootstrap do tenant e lifecycle do membership token

- Problema que resolve:
  o primeiro ator da organização precisa nascer com poder suficiente, mas sem
  deixar o sistema preso a um token eterno ou inseguro.

- Commits principais:
  `63bb1f0`, `8465cd9`, `e72006d`, `cf04310`.

- Arquivos principais:
  `app/services/organizations/bootstrap.rb`,
  `app/services/memberships/create.rb`,
  `app/services/memberships/rotate_token.rb`,
  `app/services/memberships/revoke_token.rb`,
  `app/services/memberships/ownership_guard.rb`.

- Testes que protegem a feature:
  `test/integration/organizations_flow_test.rb`,
  `test/integration/membership_token_lifecycle_test.rb`,
  `test/services/membership_ownership_guard_test.rb`.

### Ticket workflow com locking e quotas

- Problema que resolve:
  suporte multi-tenant não pode perder determinismo sob concorrência nem deixar
  tenant exceder limites silenciosamente.

- Commits principais:
  `bb07599`, `6f08d5e`, `82b893f`.

- Arquivos principais:
  `app/controllers/v1/tickets_controller.rb`,
  `app/models/ticket.rb`,
  `test/services/ticket_concurrency_test.rb`,
  `test/integration/tickets_flow_test.rb`.

- Prós:
  torna concorrência e quota parte explícita do design.

- Contras:
  aumenta atrito para clientes da API e complexidade do caminho de escrita.

### Outbox relay, retry e replay

- Problema que resolve:
  integração externa não deve bloquear o request path nem sumir sem trilha.

- Commits principais:
  `63bb1f0`, `9658522`, `1b7c596`, `2410c29`.

- Arquivos principais:
  `app/services/outbound_events/dispatcher.rb`,
  `app/services/outbound_events/relay.rb`,
  `app/services/outbound_events/replay.rb`,
  `app/services/outbound_events/webhook_delivery.rb`.

- Testes que protegem a feature:
  `test/services/outbound_events_relay_test.rb`,
  `test/services/outbound_events_webhook_delivery_test.rb`,
  `test/jobs/outbound_event_dispatch_job_test.rb`.

## 4. Decisão por decisão

- PostgreSQL como banco principal:
  escolhido porque quotas, sequences e locks são parte da aula.

- Token digest e lifecycle explícito:
  escolhido para evitar “secret raw em banco + token eterno”.

- Outbox relay em vez de side effect inline:
  escolhido para dar replay e observabilidade de integração.

- Owner continuity:
  escolhido porque multi-tenant sério não pode se auto-travar por um update
  inocente.

## 5. Prós e contras das escolhas principais

- Relay operacional:
  pró: separa persistência de entrega.
  contra: cria mais estados intermediários para operar.

- Optimistic locking:
  pró: protege mutação concorrente.
  contra: exige mais disciplina do cliente da API.

- Quotas na plataforma:
  pró: torna o limite explícito.
  contra: aumenta o número de regras cross-cutting.

## 6. Erros, correções e endurecimentos

- O histórico mostra que atomicidade de update, owner continuity, quota de inbox,
  seat reactivation e audit no-op precisaram de passes posteriores.
- Isso é exatamente o que um specialist espera: a parte difícil não é criar o
  endpoint, é descobrir onde a plataforma ainda aceita estados ruins.

## 7. Como os testes foram usados

- Primeiro para validar o slice SaaS principal.
- Depois para cercar constraints, relay, locking e mutações concorrentes.
- Por fim para validar contratos públicos e comportamento operacional.

## 8. Quais testes protegem quais decisões

- Tenant bootstrap e lifecycle:
  `test/integration/organizations_flow_test.rb`,
  `test/integration/membership_token_lifecycle_test.rb`.

- Tickets e concorrência:
  `test/integration/tickets_flow_test.rb`,
  `test/services/ticket_concurrency_test.rb`.

- Outbox:
  `test/services/outbound_events_relay_test.rb`,
  `test/services/outbound_events_webhook_delivery_test.rb`,
  `test/jobs/outbound_event_dispatch_job_test.rb`.

- Segurança e isolamento:
  `test/integration/authorization_and_isolation_test.rb`,
  `test/services/security_authorizer_test.rb`,
  `test/services/security_rate_limiter_test.rb`.

## 9. Timeline dos commits atômicos

| Commit | Pergunta que o commit responde | Mudança principal | Prova |
| --- | --- | --- | --- |
| `80305f7` | O que este repo quer ensinar? | baseline documental | docs |
| `64a1ed5` | Como preparar a base Rails API? | scaffold e tooling | setup |
| `63bb1f0` | Qual é o core SaaS? | tenant auth tickets audit outbox | app/services + tests |
| `bf93976` | O slice principal está provado? | request/model/job coverage | tests |
| `c230d05` | Como explicar o produto? | docs de arquitetura e contrato | docs |
| `96b27c2` | Como medir o caminho principal? | k6 baselines | benchmarks |
| `0003cf3` | O repo atende o spec? | compliance guardrails | repository spec |
| `5eb4118` | As mutações são atômicas? | atomicidade de updates | tests |
| `e36fe82` | O banco também protege estado? | check constraints | model/db tests |
| `bb07599` | Ticket update já é seguro? | optimistic locking preconditions | ticket flow |
| `8465cd9` | Token já tem lifecycle? | rotate/revoke/expiry | membership tests |
| `9658522` | Outbox já sabe retry? | retry backoff state | relay tests |
| `257182a` | O OpenAPI ainda bate com runtime? | response shape tests | contract tests |
| `4489486` | SQLite ainda basta? | PostgreSQL como primário | data consistency |
| `1b7c596` | Como operar integrações? | production relay controls | relay/docs |
| `93d58cb` | Como falhar cedo em produção? | readiness guardrails | readiness |
| `a150153` | Como explicar a arquitetura transversal? | transversal docs | docs |
| `6f55079` | Readiness ainda aceitava estados ruins? | production controls hardening | ops tests |
| `82b893f` | Query params de coleção são seguros? | validation fix | API tests |
| `3c67818` | Auth path ainda custa demais? | throttle de last-seen writes | perf/auth |
| `e2a5138` | O schema do rate limit está travado? | schema lock test | db test |
| `e72006d` | Owner pode se perder? | owner access preservation | auth tests |
| `6f08d5e` | Inbox quota estava frouxa? | enforce tenant inbox quotas | ticket tests |
| `cf04310` | Reactivation de membership furava seat quota? | seat quota enforcement | membership tests |
| `3c8c14a` | Audit log estava ruidoso demais? | skip no-op update events | audit behavior |
| `ffc173b` | Produção ainda aceitava host errado? | host authorization | ops |

## 9A. Perguntas de recuperação

- Por que `Membership` é mais importante que um simples `User` neste repo?
- Onde você investigaria primeiro um bug de replay do outbox?
- Qual decisão aqui depende mais de PostgreSQL do que de Rails?

## 10. Comandos de terminal que um specialist usaria aqui

```bash
git log --oneline --reverse
git show --stat 1b7c596
bin/rails test test/integration/tickets_flow_test.rb
bin/rails test test/integration/membership_token_lifecycle_test.rb
bin/rails test test/services/outbound_events_relay_test.rb
bin/rails test test/services/ticket_concurrency_test.rb
bin/rubocop
bin/rails test
```

## 11. Como adicionar a próxima feature sem quebrar a aula

Se a próxima feature for um novo workflow operacional de ticket:

1. declare se ele muda quota, audit ou evento externo;
2. trate optimistic locking cedo;
3. escreva o service antes de espalhar regra no controller;
4. prove o fluxo feliz e o fluxo concorrente.

## 12. Limites de produção deixados de propósito

- não prova ecossistema grande de webhooks/consumidores;
- não ensina billing completo;
- não tenta cobrir UI humana rica;
- mantém foco em plataforma multi-tenant API-first com operabilidade local.

## 13. Addendum: benchmark que depende da porta padrão não é benchmark operável

Um gap posterior apareceu na superfície de benchmark: o runner prometia subir a
app e medir localmente, mas por default tentava bindar a mesma porta `3000`
usada pelo fluxo normal de desenvolvimento.

- Isso é um problema de operabilidade, não de performance.
  O benchmark falhava antes de medir qualquer coisa quando o reviewer já estava
  com outra app rodando na porta padrão.

- A correção certa foi isolar o benchmark server por default.
  O runner agora usa `BENCHMARK_PORT=3203` e mantém `BASE_URL` como override
  explícito para cenários em que o operador já controla o servidor.

- A segunda correção foi de portabilidade do executor.
  O runner deixou de depender de um caminho local fixo para `k6`: agora ele
  valida o binário encontrado e tenta `PATH`, `GOBIN`/`GOPATH` e caminhos
  padrão de Homebrew antes de exigir `K6_BIN`.

- A terceira correção foi de explicabilidade.
  Quando o servidor não sobe ou não fica pronto, a mensagem agora aponta direto
  para o `smoke-server.log`, em vez de deixar o operador adivinhar se o problema
  era boot, bind ou readiness.

## 14. Addendum: CI verde exige artefato publicável e governança executável

Dois outros gaps apareceram quando o `bin/ci` foi executado de ponta a ponta:

- O `docker build` falhava durante `bundle install` porque o stage de build não
  tinha `libyaml-dev`, então o `psych` não conseguia compilar.
  A lição é simples: uma imagem multi-stage só é honesta se o stage de build
  carregar exatamente os headers nativos exigidos pelas gems compiladas.

- A repo spec exigia Conventional Commits em todo o histórico, mas o repositório
  já tinha um commit público legado de publicação de licença.
  Obrigar rewrite de histórico público para voltar a ter CI verde é a regra
  errada. A solução correta aqui foi documentar e tolerar explicitamente esse
  único subject legado, mantendo a exigência dura para todo o resto.

## 15. Addendum: A/B testing só conta quando há assignment e conversão reais

Este ciclo adicionou experimentos determinísticos e auto-routing de ticket como
feature executável, não como documentação sobre growth ou produto.

- Problema que resolve:
  o projeto precisava provar A/B testing, algoritmo de roteamento e automação de
  suporte com código verificável.

- Decisão:
  criar `Experiment`, `ExperimentVariant`, `ExperimentAssignment` e
  `ExperimentConversion`, com assignment determinístico por SHA-256 e conversão
  idempotente por tenant.

- Decisão operacional:
  `Tickets::AutoRouter` usa o experimento `ticket-auto-routing` quando ativo,
  mas ticket creation continua disponível se o experimento não existir ou estiver
  inválido. A fila padrão só considera `admin` e `agent` ativos.

- Prós:
  assignments são estáveis, variantes ponderadas suportam A/B e multivariate, e
  `ticket.created` carrega evidência de roteamento no audit log e no outbox.

- Contras:
  o projeto ganhou quatro tabelas novas e ainda não tem UI/tarefa pública para
  gerenciar experimentos. Essa escolha mantém o loop focado em backend e evita
  adicionar superfície administrativa sem necessidade imediata.

- Evidência:
  `test/services/experiments_assignment_test.rb`,
  `test/services/tickets_auto_router_test.rb`,
  `test/integration/experiments_flow_test.rb`,
  `test/integration/openapi_response_contract_test.rb` e
  `docs/adr/008-deterministic-experiments-for-ticket-routing.md`.
