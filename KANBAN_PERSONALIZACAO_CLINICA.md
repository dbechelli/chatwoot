# 🏥 Personalização do Kanban para Clínicas Multidisciplinares

## 📋 Visão Geral

Este guia ensina como personalizar o Kanban do Chatwoot para gerenciar o pipeline de pacientes em uma clínica multidisciplinar, com integração N8N para preenchimento automático de dados.

---

## 🎯 Estágios Recomendados para Clínicas

### Opção 1: Pipeline Simples (6 estágios)

```
📥 Novo Contato → 🔍 Qualificação → 📅 Agendamento → ✅ Agendado → 🔄 Pós-Consulta → ⭐ Paciente Ativo
```

### Opção 2: Pipeline Completo (7 estágios)

```
📥 Novo Contato → 🔍 Qualificação → 📅 Agendamento → ✅ Agendado → 🔄 Pós-Consulta → ⭐ Paciente Ativo → ❄️ Inativo
```

---

## 🛠️ Como Personalizar os Estágios

### Passo 1: Editar o Arquivo KanbanView.vue

Abra o arquivo:
```
app/javascript/dashboard/routes/dashboard/conversation/KanbanView.vue
```

Localize a linha ~20 onde está definido `salesStages`:

```javascript
const salesStages = ref([
  { stage: 'lead', title: 'Novo Lead', color: '#3b82f6', wipLimit: null },
  { stage: 'qualified', title: 'Qualificado', color: '#8b5cf6', wipLimit: 20 },
  { stage: 'proposal', title: 'Proposta Enviada', color: '#f59e0b', wipLimit: 15 },
  { stage: 'negotiation', title: 'Negociação', color: '#ec4899', wipLimit: 10 },
  { stage: 'won', title: 'Ganho', color: '#10b981', wipLimit: null },
  { stage: 'lost', title: 'Perdido', color: '#ef4444', wipLimit: null },
]);
```

### Passo 2: Substituir pelos Estágios da Clínica

```javascript
const salesStages = ref([
  { stage: 'novo_contato', title: t('KANBAN.STAGES.NEW_CONTACT'), color: '#3b82f6', wipLimit: null },
  { stage: 'qualificacao', title: t('KANBAN.STAGES.QUALIFICATION'), color: '#8b5cf6', wipLimit: 30 },
  { stage: 'agendamento_pendente', title: t('KANBAN.STAGES.PENDING_APPOINTMENT'), color: '#f59e0b', wipLimit: 20 },
  { stage: 'agendado', title: t('KANBAN.STAGES.SCHEDULED'), color: '#10b981', wipLimit: null },
  { stage: 'pos_consulta', title: t('KANBAN.STAGES.POST_CONSULT'), color: '#ec4899', wipLimit: 15 },
  { stage: 'paciente_ativo', title: t('KANBAN.STAGES.ACTIVE_PATIENT'), color: '#6366f1', wipLimit: null },
  { stage: 'inativo', title: t('KANBAN.STAGES.INACTIVE'), color: '#64748b', wipLimit: null },
]);
```

**Campos explicados:**
- `stage`: Chave única usada no custom attribute `sales_stage`
- `title`: Título exibido (use `t()` para i18n ou string direta)
- `color`: Cor hexadecimal da coluna
- `wipLimit`: Limite de trabalho em andamento (null = sem limite)

### Passo 3: Adicionar Traduções

Edite `/app/javascript/dashboard/i18n/locale/pt_BR/kanban.json`:

```json
{
  "KANBAN": {
    "TITLE": "Pipeline de Pacientes",
    "STAGES": {
      "NEW_CONTACT": "📥 Novo Contato",
      "QUALIFICATION": "🔍 Qualificação",
      "PENDING_APPOINTMENT": "📅 Agendamento Pendente",
      "SCHEDULED": "✅ Agendado",
      "POST_CONSULT": "🔄 Pós-Consulta",
      "ACTIVE_PATIENT": "⭐ Paciente Ativo",
      "INACTIVE": "❄️ Inativo"
    },
    // ... resto do arquivo
  }
}
```

---

## 🎨 Paleta de Cores Recomendada

| Cor | Código Hex | Uso Recomendado |
|-----|------------|-----------------|
| 🔵 Azul | `#3b82f6` | Novos contatos, início do funil |
| 🟣 Roxo | `#8b5cf6` | Qualificação, avaliação |
| 🟠 Laranja | `#f59e0b` | Pendências, aguardando ação |
| 🟢 Verde | `#10b981` | Agendado, confirmado |
| 🩷 Rosa | `#ec4899` | Follow-up, pós-consulta |
| 🔷 Índigo | `#6366f1` | Pacientes ativos, recorrentes |
| ⚪ Cinza | `#64748b` | Inativos, arquivados |

---

## 📊 Custom Attributes (Atributos Personalizados)

### Passo 1: Criar os Atributos no Chatwoot

Acesse **Configurações → Atributos Personalizados → Conversas**

#### Atributos Obrigatórios

| Display Name | Key | Tipo | Descrição |
|--------------|-----|------|-----------|
| Estágio do Paciente | `sales_stage` | Lista | Estágio atual no pipeline |

**Valores da Lista** (se escolher tipo Lista):
```
novo_contato
qualificacao
agendamento_pendente
agendado
pos_consulta
paciente_ativo
inativo
```

#### Atributos Recomendados (preenchidos pelo N8N)

| Display Name | Key | Tipo | Descrição |
|--------------|-----|------|-----------|
| Especialidade | `especialidade` | Texto | Ex: Psicologia, Nutrição |
| Profissional | `profissional` | Texto | Nome do profissional responsável |
| Convênio | `convenio` | Texto | Ex: Unimed, Particular |
| Data Última Consulta | `data_ultima_consulta` | Data | Última consulta realizada |
| Próxima Consulta | `proxima_consulta` | Data | Próxima consulta agendada |
| Origem do Lead | `origem_lead` | Texto | Instagram, Google, Indicação |
| Valor da Consulta | `deal_value` | Número | Valor em R$ |

---

## 🤖 Integração com N8N

### Endpoint para Atualizar Atributos

```javascript
// Exemplo de requisição do N8N para o Chatwoot
POST https://seu-chatwoot.com/api/v1/accounts/{account_id}/conversations/{conversation_id}/custom_attributes

Headers:
  api_access_token: SEU_TOKEN_API
  Content-Type: application/json

Body:
{
  "custom_attributes": {
    "sales_stage": "agendado",
    "especialidade": "Psicologia",
    "profissional": "Dra. Maria Silva",
    "convenio": "Unimed",
    "proxima_consulta": "2025-01-15",
    "deal_value": 250
  }
}
```

### Workflow N8N Recomendado

1. **Trigger**: Webhook do sistema de gestão da clínica
2. **Buscar Contato**: `GET /api/v1/accounts/{account_id}/contacts/search?q={telefone}`
3. **Atualizar Atributos**: Endpoint acima
4. **Notificar**: Enviar mensagem WhatsApp confirmando agendamento

---

## 🔄 Automações Recomendadas

### Automação 1: Novo Lead

**Gatilho**: Conversa criada
**Condição**: Primeira interação do contato
**Ações**:
- Adicionar custom attribute: `sales_stage = novo_contato`
- Adicionar tag: `novo-lead`

### Automação 2: Paciente Inativo

**Gatilho**: Sem interação há 90 dias
**Ações**:
- Atualizar custom attribute: `sales_stage = inativo`
- Adicionar tag: `reativar`

### Automação 3: Pós-Consulta Automático

**Gatilho**: Campo `data_ultima_consulta` atualizado
**Ações**:
- Atualizar custom attribute: `sales_stage = pos_consulta`
- Enviar template de satisfação

---

## 🏗️ Permitir Admin Escolher Estágios (Avançado)

Para permitir que cada instalação configure seus próprios estágios:

### Opção 1: Configuração via Custom Attributes da Conta

1. Crie um atributo da **Conta** chamado `kanban_stages` (tipo JSON)
2. Modifique `KanbanView.vue` para ler desse atributo:

```javascript
const accountSettings = computed(() =>
  store.getters['accounts/getAccount'].custom_attributes
);

const salesStages = ref(
  accountSettings.value?.kanban_stages || DEFAULT_STAGES
);

const DEFAULT_STAGES = [
  { stage: 'novo_contato', title: 'Novo Contato', color: '#3b82f6', wipLimit: null },
  // ... estágios padrão
];
```

3. Admin define via Settings:
```json
{
  "kanban_stages": [
    { "stage": "novo_contato", "title": "📥 Novo", "color": "#3b82f6", "wipLimit": null },
    { "stage": "qualificacao", "title": "🔍 Avaliação", "color": "#8b5cf6", "wipLimit": 20 }
  ]
}
```

### Opção 2: Criar Interface de Configuração

Crie uma página em **Settings → Kanban Settings**:

1. Criar controller Rails: `app/controllers/api/v1/accounts/kanban_settings_controller.rb`
2. Criar tabela: `kanban_stages` (account_id, stage_key, title, color, wip_limit, position)
3. Criar Vue component: `KanbanSettings.vue` com drag & drop para reordenar estágios
4. Modificar `KanbanView.vue` para carregar da API:

```javascript
const salesStages = ref([]);

onMounted(async () => {
  const response = await axios.get(`/api/v1/accounts/${accountId}/kanban_settings`);
  salesStages.value = response.data.stages;
  fetchConversations();
});
```

---

## 📱 Exemplo de Uso Prático

### Fluxo: Novo Paciente WhatsApp

1. **Paciente envia mensagem**: "Olá, gostaria de agendar consulta"
2. **Chatwoot cria conversa**: Automação move para estágio `novo_contato`
3. **Atendente qualifica**: Identifica especialidade necessária
   - Move manualmente (arrastar) para `qualificacao`
4. **N8N recebe webhook**: Sistema de gestão atualiza custom attributes:
   - `especialidade = "Psicologia"`
   - `profissional = "Dra. Maria"`
5. **Atendente agenda**: Move para `agendamento_pendente`
6. **Confirmação**: N8N atualiza para `agendado` + `proxima_consulta`
7. **Pós-consulta**: Automação move para `pos_consulta` após data passar
8. **Retorno agendado**: Move para `paciente_ativo`

---

## 🐛 Troubleshooting

### Problema: Conversas não aparecem no Kanban

**Solução**: Verifique se o `sales_stage` está definido:
```javascript
// No console do navegador
conversation.custom_attributes?.sales_stage
```

### Problema: Drag & Drop não funciona

**Solução**:
1. Limpe cache do navegador (Ctrl+Shift+Del)
2. Verifique permissões do usuário
3. Veja console do browser (F12) para erros

### Problema: Cores não aparecem

**Solução**: Use códigos hex válidos (`#RRGGBB`)

---

## 📚 Recursos Adicionais

- [Documentação Chatwoot API](https://www.chatwoot.com/docs/product/channels/api/client-apis)
- [N8N Workflows](https://n8n.io/workflows)
- [Tailwind Colors](https://tailwindcss.com/docs/customizing-colors)

---

## ✅ Checklist de Implementação

- [ ] Definir estágios do pipeline da clínica
- [ ] Editar `KanbanView.vue` com novos estágios
- [ ] Adicionar traduções em `pt_BR/kanban.json`
- [ ] Criar custom attributes no Chatwoot
- [ ] Configurar automações básicas
- [ ] Integrar N8N com sistema de gestão
- [ ] Testar fluxo completo com paciente teste
- [ ] Treinar equipe no uso do Kanban
- [ ] (Opcional) Implementar configuração por instalação

---

**Desenvolvido para Chatwoot com ❤️**
