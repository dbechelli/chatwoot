# 🎯 Implementação de Kanban Board no Chatwoot

## 📋 Visão Geral

Este guia apresenta 3 abordagens para implementar um Kanban board no Chatwoot para gerenciar conversas.

---

## ✅ Opção 1: Kanban de Status (Mais Simples - MVP)

### Descrição
Visualizar conversas em colunas baseadas no status (Open, Pending, Snoozed, Resolved).

### Estrutura de Arquivos

```
app/javascript/dashboard/
├── routes/dashboard/conversation/
│   └── KanbanView.vue (NOVO)
├── components/
│   └── KanbanBoard/
│       ├── KanbanColumn.vue (NOVO)
│       ├── KanbanCard.vue (NOVO)
│       └── index.js (NOVO)
└── routes/index.js (MODIFICAR)
```

### Passo 1: Criar KanbanCard.vue

```vue
<script setup>
import { computed } from 'vue';
import { useStore } from 'vuex';
import ConversationCard from 'dashboard/components/widgets/conversation/ConversationCard.vue';

const props = defineProps({
  conversation: { type: Object, required: true },
});

const store = useStore();

const updateStatus = async (newStatus) => {
  await store.dispatch('toggleStatus', {
    conversationId: props.conversation.id,
    status: newStatus,
  });
};
</script>

<template>
  <div class="kanban-card">
    <ConversationCard
      :source="conversation"
      :show-assignee="true"
      compact
    />
  </div>
</template>

<style scoped>
.kanban-card {
  margin-bottom: 0.5rem;
  cursor: move;
}
</style>
```

### Passo 2: Criar KanbanColumn.vue

```vue
<script setup>
import { computed } from 'vue';
import Draggable from 'vuedraggable';
import KanbanCard from './KanbanCard.vue';

const props = defineProps({
  title: { type: String, required: true },
  status: { type: String, required: true },
  conversations: { type: Array, required: true },
  count: { type: Number, default: 0 },
});

const emit = defineEmits(['update:conversations', 'statusChange']);

const localConversations = computed({
  get: () => props.conversations,
  set: (value) => emit('update:conversations', value),
});

const handleChange = (evt) => {
  if (evt.added) {
    // Conversa foi movida para esta coluna
    emit('statusChange', {
      conversationId: evt.added.element.id,
      newStatus: props.status,
    });
  }
};
</script>

<template>
  <div class="kanban-column">
    <div class="kanban-column-header">
      <h3 class="text-base font-medium text-n-slate-12">
        {{ title }}
      </h3>
      <span class="count-badge">{{ count }}</span>
    </div>

    <Draggable
      v-model="localConversations"
      group="conversations"
      item-key="id"
      class="kanban-column-content"
      @change="handleChange"
    >
      <template #item="{ element }">
        <KanbanCard :conversation="element" />
      </template>
    </Draggable>
  </div>
</template>

<style scoped>
.kanban-column {
  background: var(--color-background);
  border-radius: 8px;
  padding: 1rem;
  min-width: 300px;
  max-width: 320px;
  height: calc(100vh - 200px);
  display: flex;
  flex-direction: column;
}

.kanban-column-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
  padding-bottom: 0.5rem;
  border-bottom: 1px solid var(--color-border);
}

.count-badge {
  background: var(--color-background-light);
  padding: 0.25rem 0.5rem;
  border-radius: 12px;
  font-size: 0.75rem;
  font-weight: 600;
}

.kanban-column-content {
  flex: 1;
  overflow-y: auto;
  padding-right: 0.5rem;
}

/* Scrollbar customizado */
.kanban-column-content::-webkit-scrollbar {
  width: 6px;
}

.kanban-column-content::-webkit-scrollbar-thumb {
  background: var(--color-border);
  border-radius: 3px;
}
</style>
```

### Passo 3: Criar KanbanView.vue

```vue
<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useRoute } from 'vue-router';
import KanbanColumn from 'dashboard/components/KanbanBoard/KanbanColumn.vue';
import wootConstants from 'dashboard/constants/globals';

const store = useStore();
const route = useRoute();

const columns = ref([
  {
    status: wootConstants.STATUS_TYPE.OPEN,
    title: 'Open',
    color: '#3b82f6'
  },
  {
    status: wootConstants.STATUS_TYPE.PENDING,
    title: 'Pending',
    color: '#f59e0b'
  },
  {
    status: wootConstants.STATUS_TYPE.SNOOZED,
    title: 'Snoozed',
    color: '#8b5cf6'
  },
  {
    status: wootConstants.STATUS_TYPE.RESOLVED,
    title: 'Resolved',
    color: '#10b981'
  },
]);

const allConversations = computed(() =>
  store.getters['getAllConversations']
);

const conversationsByStatus = computed(() => {
  const grouped = {};

  columns.value.forEach(col => {
    grouped[col.status] = allConversations.value.filter(
      conv => conv.status === col.status
    );
  });

  return grouped;
});

const handleStatusChange = async ({ conversationId, newStatus }) => {
  try {
    await store.dispatch('toggleStatus', {
      conversationId,
      status: newStatus,
    });
  } catch (error) {
    console.error('Failed to update status:', error);
  }
};

const fetchConversations = () => {
  // Buscar todas as conversas (todos os status)
  store.dispatch('fetchAllConversations', {
    status: wootConstants.STATUS_TYPE.ALL,
    assigneeType: wootConstants.ASSIGNEE_TYPE.ALL,
  });
};

onMounted(() => {
  fetchConversations();
});
</script>

<template>
  <div class="kanban-view">
    <div class="kanban-header">
      <h2 class="text-xl font-semibold">Kanban Board</h2>
      <button @click="fetchConversations" class="refresh-button">
        🔄 Refresh
      </button>
    </div>

    <div class="kanban-board">
      <KanbanColumn
        v-for="column in columns"
        :key="column.status"
        :title="column.title"
        :status="column.status"
        :conversations="conversationsByStatus[column.status] || []"
        :count="conversationsByStatus[column.status]?.length || 0"
        @status-change="handleStatusChange"
      />
    </div>
  </div>
</template>

<style scoped>
.kanban-view {
  padding: 1rem;
  height: 100vh;
  display: flex;
  flex-direction: column;
}

.kanban-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
  padding-bottom: 1rem;
  border-bottom: 1px solid var(--color-border);
}

.refresh-button {
  padding: 0.5rem 1rem;
  background: var(--color-primary);
  color: white;
  border-radius: 6px;
  border: none;
  cursor: pointer;
}

.kanban-board {
  display: flex;
  gap: 1rem;
  overflow-x: auto;
  flex: 1;
  padding-bottom: 1rem;
}

/* Scrollbar horizontal */
.kanban-board::-webkit-scrollbar {
  height: 8px;
}

.kanban-board::-webkit-scrollbar-thumb {
  background: var(--color-border);
  border-radius: 4px;
}
</style>
```

### Passo 4: Adicionar Rota

Edite `app/javascript/dashboard/routes/index.js`:

```javascript
// Adicione no topo
import KanbanView from './dashboard/conversation/KanbanView.vue';

// Adicione na lista de rotas (dentro de routes array)
{
  path: 'kanban',
  name: 'kanban',
  meta: {
    permissions: ['administrator', 'agent'],
  },
  component: KanbanView,
},
```

### Passo 5: Adicionar Link na Sidebar

Edite o arquivo de sidebar para adicionar link "Kanban":

```javascript
{
  icon: 'board',
  key: 'kanban',
  toState: 'kanban',
  toolTip: 'Kanban Board',
  toStateName: 'kanban',
}
```

---

## 🚀 Opção 2: Kanban de Custom Attributes (Mais Flexível)

### Descrição
Usar custom attributes para criar pipelines customizáveis (ex: "Novo Lead", "Qualificado", "Negociação", "Fechado").

### Vantagens
- ✅ Totalmente customizável
- ✅ Múltiplos pipelines (vendas, suporte, onboarding)
- ✅ Campos customizados por pipeline

### Passos Adicionais

1. **Criar Custom Attribute "Pipeline Stage"**
   - Tipo: Dropdown
   - Valores: Novo, Qualificado, Negociação, Fechado

2. **Modificar KanbanView.vue**
   ```javascript
   const columns = ref([
     { stage: 'novo', title: 'Novo Lead', color: '#3b82f6' },
     { stage: 'qualificado', title: 'Qualificado', color: '#10b981' },
     { stage: 'negociacao', title: 'Negociação', color: '#f59e0b' },
     { stage: 'fechado', title: 'Fechado', color: '#8b5cf6' },
   ]);

   const conversationsByStage = computed(() => {
     const grouped = {};
     columns.value.forEach(col => {
       grouped[col.stage] = allConversations.value.filter(
         conv => conv.custom_attributes?.pipeline_stage === col.stage
       );
     });
     return grouped;
   });
   ```

3. **Atualizar Custom Attribute ao mover**
   ```javascript
   const handleStageChange = async ({ conversationId, newStage }) => {
     await store.dispatch('updateCustomAttributes', {
       conversationId,
       customAttributes: {
         pipeline_stage: newStage
       }
     });
   };
   ```

---

## 🎨 Opção 3: Kanban de Prioridades (Mais Visual)

### Descrição
Organizar conversas por prioridade (Urgent, High, Medium, Low, None).

### Implementação

Modifique as colunas em KanbanView.vue:

```javascript
const columns = ref([
  {
    priority: 'urgent',
    title: '🔥 Urgent',
    color: '#ef4444'
  },
  {
    priority: 'high',
    title: '⚠️ High',
    color: '#f97316'
  },
  {
    priority: 'medium',
    title: '📋 Medium',
    color: '#3b82f6'
  },
  {
    priority: 'low',
    title: '✅ Low',
    color: '#10b981'
  },
  {
    priority: null,
    title: '⚪ None',
    color: '#6b7280'
  },
]);

const conversationsByPriority = computed(() => {
  const grouped = {};
  columns.value.forEach(col => {
    grouped[col.priority] = allConversations.value.filter(
      conv => conv.priority === col.priority
    );
  });
  return grouped;
});
```

---

## 🔧 Funcionalidades Extras

### 1. Filtros no Kanban

```vue
<template>
  <div class="kanban-filters">
    <select v-model="selectedInbox">
      <option value="">All Inboxes</option>
      <option v-for="inbox in inboxes" :key="inbox.id" :value="inbox.id">
        {{ inbox.name }}
      </option>
    </select>

    <select v-model="selectedAssignee">
      <option value="">All Agents</option>
      <option value="me">My Conversations</option>
      <option value="unassigned">Unassigned</option>
    </select>
  </div>
</template>
```

### 2. Contadores de Tempo

Adicionar tempo em cada status:

```vue
<template>
  <div class="time-badge">
    ⏱️ {{ formatDuration(conversation.time_in_status) }}
  </div>
</template>
```

### 3. Limites de WIP (Work in Progress)

```vue
<script setup>
const wipLimit = ref({
  open: 10,
  pending: 5,
  snoozed: 3,
});

const isOverLimit = (status) => {
  return conversationsByStatus.value[status]?.length > wipLimit.value[status];
};
</script>

<template>
  <div
    class="kanban-column"
    :class="{ 'over-limit': isOverLimit(column.status) }"
  >
    <!-- ... -->
  </div>
</template>
```

### 4. Arrastar Múltiplas Conversas

```vue
<script setup>
import { ref } from 'vue';

const selectedConversations = ref([]);

const selectConversation = (id) => {
  if (selectedConversations.value.includes(id)) {
    selectedConversations.value = selectedConversations.value.filter(
      convId => convId !== id
    );
  } else {
    selectedConversations.value.push(id);
  }
};
</script>
```

---

## 📊 Comparação das Opções

| Feature | Status Kanban | Custom Attributes | Priority Kanban |
|---------|--------------|-------------------|----------------|
| Complexidade | 🟢 Baixa | 🟡 Média | 🟢 Baixa |
| Flexibilidade | 🟡 Média | 🟢 Alta | 🟡 Média |
| Customização | ❌ Limitada | ✅ Total | ❌ Limitada |
| Setup | ✅ Rápido | 🟡 Médio | ✅ Rápido |
| Use Case | Suporte | Vendas/CRM | Triagem |

---

## 🎯 Recomendação

**Para começar rápido:** Opção 1 (Status Kanban)
- Implementação mais simples
- Usa estruturas já existentes
- MVP funcional em 1-2 dias

**Para produção:** Opção 2 (Custom Attributes)
- Mais flexível e escalável
- Permite múltiplos pipelines
- Melhor para casos de uso diversos

---

## 🚀 Deploy

Após implementar, execute:

```bash
# Commit
git add .
git commit -m "feat(kanban): add kanban board view for conversations"

# Push (vai triggar o build automático)
git push origin claude/add-resolved-tab-hESJN

# Aguardar build completar
# Deploy no Coolify
```

---

## 📚 Recursos Adicionais

- **vuedraggable docs**: https://github.com/SortableJS/vue.draggable.next
- **Kanban UX best practices**: https://www.nngroup.com/articles/kanban-boards/
- **Custom Attributes API**: Ver `app/controllers/api/v1/accounts/conversations_controller.rb`

---

## 🎨 Inspirações

Soluções de Kanban existentes na comunidade Chatwoot:
1. **Pipedrive Integration** - Usar webhooks para sincronizar com Pipedrive
2. **Linear Integration** - Já existe integração com Linear (ver `app/javascript/dashboard/routes/dashboard/settings/integrations/Linear.vue`)
3. **Custom Dashboard App** - Criar dashboard app customizado com iframe

---

## 🔐 Permissões

Adicione checagem de permissões:

```javascript
meta: {
  permissions: ['administrator', 'agent'],
  customPermissions: ['conversation_manage'],
}
```

---

## 📝 Próximos Passos

1. [ ] Implementar Opção 1 (Status Kanban)
2. [ ] Testar drag & drop
3. [ ] Adicionar filtros
4. [ ] Implementar limites WIP
5. [ ] Adicionar animações
6. [ ] Testes E2E
7. [ ] Deploy para staging
8. [ ] Documentação de usuário
