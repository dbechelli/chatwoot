# Checklist de Homologacao do Kanban

Este checklist existe para reduzir regressao, garantir validacao por etapas e evitar liberar mudancas incompletas do Kanban.

## 1. Pre-requisitos do ambiente

- Confirmar acesso ao ambiente com Ruby, Bundler e PostgreSQL funcionais.
- Confirmar acesso ao ambiente com Node.js e pnpm funcionais.
- Confirmar que a branch de homologacao contem os commits mais recentes do Kanban.
- Confirmar backup do banco antes de rodar migracoes em ambiente compartilhado.

## 2. Validacao de banco de dados

- Rodar `bin/rails db:migrate`.
- Validar que a coluna `accounts.kanban_config` existe.
- Validar que o indice `index_accounts_on_kanban_config` existe.
- Validar que contas antigas sem `kanban_config` continuam acessando o endpoint sem erro.
- Validar que o fallback em `settings['kanban_config']` nao quebra leitura nem escrita.

Comandos sugeridos:

```bash
bin/rails db:migrate
bin/rails runner "puts Account.column_names.grep(/kanban/).inspect"
bin/rails runner "account = Account.first; puts account.kanban_configuration.to_json"
```

## 3. Validacao automatizada de backend

- Rodar a spec de request do Kanban.
- Rodar specs relacionadas a conversa se houver impacto em `custom_attributes`.
- Validar que criar, editar, listar e excluir board retornam status HTTP corretos.
- Validar que boards com campos avancados retornam payload completo.

Comandos sugeridos:

```bash
bundle exec rspec spec/requests/api/v1/accounts/kanban_settings_spec.rb
```

## 4. Validacao automatizada de frontend

- Rodar ESLint nos arquivos alterados do Kanban.
- Rodar testes JS relacionados ao store e componentes, se existirem.
- Confirmar que nao ha regressao de importacao, i18n ou warnings obvios de compilacao.

Comandos sugeridos:

```bash
pnpm eslint app/javascript/dashboard/components-next/sidebar/Sidebar.vue app/javascript/dashboard/routes/dashboard/conversation/KanbanView.vue app/javascript/dashboard/routes/dashboard/kanban/pages/KanbanBoardEditorPage.vue app/javascript/dashboard/store/modules/kanban.js
```

## 5. Validacao funcional de configuracao

- Criar um quadro em branco.
- Criar um quadro por template.
- Editar um quadro existente.
- Duplicar um quadro.
- Excluir um quadro.
- Validar que o board duplicado mantem etapas e configuracoes esperadas.
- Validar que apenas um board fica marcado como padrao.

## 6. Validacao funcional de persistencia

- Criar board e recarregar a pagina.
- Editar nome, descricao e etapas e recarregar a pagina.
- Validar persistencia de `webhook_url`.
- Validar persistencia de `agent_ids`.
- Validar persistencia de `visible_attributes`.
- Validar persistencia de `auto_assign_inboxes`.
- Validar persistencia de `auto_assign_stage_id`.
- Validar persistencia de `enable_round_robin`.

## 7. Validacao funcional de UX

- Confirmar rolagem horizontal do board quando houver muitas etapas.
- Confirmar rolagem vertical dos cards dentro das colunas.
- Confirmar que a tela nao trava ao usar zoom alto no navegador.
- Confirmar comportamento aceitavel em desktop.
- Confirmar comportamento aceitavel em tablet.
- Confirmar comportamento aceitavel em mobile.
- Confirmar que a hierarquia do menu lateral fica assim:
  - Kanbans
  - Visao geral
  - Funis
  - Quadros dentro de Funis

## 8. Validacao funcional de sincronizacao com conversa

- Adicionar uma conversa ao Kanban pelo painel da conversa.
- Criar ou editar um item pelo modal do Kanban.
- Mover um item entre etapas.
- Confirmar que a conversa refletiu o estagio salvo em `custom_attributes`.
- Confirmar que prioridade e atribuicao continuam sincronizadas.
- Confirmar que remover do Kanban limpa o estagio correspondente.

## 9. Validacao de filtros e visualizacoes

- Validar visao de quadro.
- Validar visao de lista.
- Validar visao de calendario.
- Validar filtro por inbox.
- Validar filtro por agente.
- Validar filtro por status.
- Validar agrupamento por prioridade.
- Validar agrupamento por agente.

## 10. Validacao de webhooks e automacoes existentes

- Validar que mover um card nao gera erro no navegador quando `webhook_url` estiver vazio.
- Validar que `webhook_url` configurado nao bloqueia o fluxo de UI em caso de falha externa.
- Validar que eventos de Kanban existentes continuam despachados no backend.
- Validar que automacao por inbox continua funcionando para `auto_assign_inboxes`.
- Validar round robin quando habilitado e com agentes elegiveis.

## 11. Validacao de seguranca e operacao

- Confirmar que agente nao administrador nao salva configuracao de board.
- Confirmar que administrador consegue criar, editar e excluir boards.
- Confirmar que erros de API nao aparecem silenciosamente sem feedback visual.
- Confirmar que nenhum segredo sensivel fica exposto indevidamente na UI.

## 12. Criterios de aceite para liberar

- Banco migrado sem erro.
- Endpoint `GET /api/v1/accounts/:account_id/kanban_settings` respondendo `200`.
- Endpoint `POST /api/v1/accounts/:account_id/kanban_settings/boards` respondendo `200`.
- Persistencia confirmada apos reload.
- UX de rolagem validada.
- Hierarquia do menu validada.
- Sem erros estaticos nos arquivos alterados.
- Sem erro critico no console durante fluxo principal.

## 13. Bloqueadores de release

Nao liberar se qualquer item abaixo ocorrer:

- `500` ao abrir ou salvar Kanban.
- Board salva mas perde configuracoes apos reload.
- Sem rolagem utilizavel no board.
- Hierarquia lateral inconsistente.
- Automacao movendo conversas para etapas erradas.
- Webhook travando a operacao principal.
- Regressao de permissao para agentes nao administradores.

## 14. Registro de homologacao

Registrar ao final:

- Ambiente validado.
- Responsavel pela homologacao.
- Data da validacao.
- Versao ou commit validado.
- Pendencias conhecidas.
- Decisao final: aprovado, aprovado com ressalvas, ou reprovado.