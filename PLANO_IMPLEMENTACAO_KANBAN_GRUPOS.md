# 📋 Plano de Implementação - Kanban Personalizável + Grupos WhatsApp

## 🎯 Visão Geral

Este documento detalha a implementação de duas funcionalidades principais:

1. **Sistema de Kanban Personalizável** - Permitir criar múltiplos Kanbans configuráveis por superadmin
2. **Suporte a Grupos WhatsApp** - Implementar todas as funcionalidades de grupos do WhatsApp

---

## 📊 PARTE 1: SISTEMA DE KANBAN PERSONALIZÁVEL

### Objetivo
Permitir que cada empresa configure seus próprios Kanbans com estágios personalizados, cores, limites WIP e múltiplos pipelines.

### Arquitetura Proposta

#### 1.1 Backend - Modelo de Dados

**Migration: Adicionar configuração de Kanban na Account**

```ruby
# db/migrate/YYYYMMDD_add_kanban_config_to_accounts.rb
class AddKanbanConfigToAccounts < ActiveRecord::Migration[7.0]
  def change
    add_column :accounts, :kanban_config, :jsonb, default: {
      enabled: false,
      boards: []
    }
  end
end
```

**Schema JSON esperado:**

```json
{
  "enabled": true,
  "boards": [
    {
      "id": "sales-pipeline",
      "name": "Pipeline de Vendas",
      "description": "Pipeline principal de vendas",
      "stages": [
        {
          "id": "lead",
          "name": "Novo Lead",
          "color": "#3b82f6",
          "order": 1,
          "wipLimit": null
        },
        {
          "id": "qualified",
          "name": "Qualificado",
          "color": "#8b5cf6",
          "order": 2,
          "wipLimit": 20
        }
      ],
      "customAttributeKey": "sales_stage",
      "valueAttributeKey": "deal_value",
      "isDefault": true
    },
    {
      "id": "support-pipeline",
      "name": "Pipeline de Suporte",
      "stages": [
        {
          "id": "new",
          "name": "Novo",
          "color": "#10b981",
          "order": 1,
          "wipLimit": 50
        }
      ],
      "customAttributeKey": "support_stage",
      "isDefault": false
    }
  ]
}
```

**Model: app/models/account.rb**

```ruby
# Adicionar store_accessor
store_accessor :kanban_config, :enabled, :boards

# Validações
validates :kanban_config, presence: true

# Métodos helper
def kanban_enabled?
  kanban_config['enabled'] == true
end

def kanban_boards
  kanban_config['boards'] || []
end

def default_kanban_board
  kanban_boards.find { |b| b['isDefault'] } || kanban_boards.first
end

def find_kanban_board(board_id)
  kanban_boards.find { |b| b['id'] == board_id }
end
```

---

#### 1.2 Backend - API Controller

**Controller: app/controllers/api/v1/accounts/kanban_settings_controller.rb**

```ruby
class Api::V1::Accounts::KanbanSettingsController < Api::V1::Accounts::BaseController
  before_action :check_administrator_authorization

  # GET /api/v1/accounts/:account_id/kanban_settings
  def index
    @kanban_config = Current.account.kanban_config || default_config
  end

  # PUT /api/v1/accounts/:account_id/kanban_settings
  def update
    Current.account.update!(kanban_config: kanban_params)
    @kanban_config = Current.account.kanban_config
    render :index
  end

  # POST /api/v1/accounts/:account_id/kanban_settings/boards
  def create_board
    boards = Current.account.kanban_boards
    new_board = board_params.merge(id: SecureRandom.uuid)
    boards << new_board
    Current.account.update!(kanban_config: { boards: boards })
    render json: new_board
  end

  # PUT /api/v1/accounts/:account_id/kanban_settings/boards/:id
  def update_board
    boards = Current.account.kanban_boards
    board_index = boards.find_index { |b| b['id'] == params[:id] }

    raise ActiveRecord::RecordNotFound if board_index.nil?

    boards[board_index] = boards[board_index].merge(board_params)
    Current.account.update!(kanban_config: { boards: boards })
    render json: boards[board_index]
  end

  # DELETE /api/v1/accounts/:account_id/kanban_settings/boards/:id
  def delete_board
    boards = Current.account.kanban_boards.reject { |b| b['id'] == params[:id] }
    Current.account.update!(kanban_config: { boards: boards })
    head :no_content
  end

  private

  def check_administrator_authorization
    authorize Current.account, :update?
  end

  def kanban_params
    params.require(:kanban_config).permit(
      :enabled,
      boards: [
        :id, :name, :description, :customAttributeKey, :valueAttributeKey, :isDefault,
        stages: [:id, :name, :color, :order, :wipLimit]
      ]
    )
  end

  def board_params
    params.require(:board).permit(
      :name, :description, :customAttributeKey, :valueAttributeKey, :isDefault,
      stages: [:id, :name, :color, :order, :wipLimit]
    )
  end

  def default_config
    {
      enabled: false,
      boards: [
        {
          id: 'default-sales',
          name: 'Pipeline de Vendas',
          stages: [
            { id: 'lead', name: 'Novo Lead', color: '#3b82f6', order: 1, wipLimit: nil },
            { id: 'qualified', name: 'Qualificado', color: '#8b5cf6', order: 2, wipLimit: 20 },
            { id: 'proposal', name: 'Proposta', color: '#f59e0b', order: 3, wipLimit: 15 },
            { id: 'negotiation', name: 'Negociação', color: '#ec4899', order: 4, wipLimit: 10 },
            { id: 'won', name: 'Ganho', color: '#10b981', order: 5, wipLimit: nil },
            { id: 'lost', name: 'Perdido', color: '#ef4444', order: 6, wipLimit: nil }
          ],
          customAttributeKey: 'sales_stage',
          valueAttributeKey: 'deal_value',
          isDefault: true
        }
      ]
    }
  end
end
```

**View: app/views/api/v1/accounts/kanban_settings/index.json.jbuilder**

```jbuilder
json.enabled @kanban_config['enabled']
json.boards @kanban_config['boards'] do |board|
  json.id board['id']
  json.name board['name']
  json.description board['description']
  json.customAttributeKey board['customAttributeKey']
  json.valueAttributeKey board['valueAttributeKey']
  json.isDefault board['isDefault']
  json.stages board['stages'] do |stage|
    json.id stage['id']
    json.name stage['name']
    json.color stage['color']
    json.order stage['order']
    json.wipLimit stage['wipLimit']
  end
end
```

**Routes: config/routes.rb**

```ruby
namespace :accounts do
  resource :kanban_settings, only: [:index, :update] do
    member do
      post 'boards', to: 'kanban_settings#create_board'
      put 'boards/:id', to: 'kanban_settings#update_board'
      delete 'boards/:id', to: 'kanban_settings#delete_board'
    end
  end
end
```

---

#### 1.3 Frontend - Interface de Configuração

**Página de Configuração: app/javascript/dashboard/routes/dashboard/settings/kanban/Index.vue**

```vue
<script setup>
import { ref, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import KanbanBoardEditor from './KanbanBoardEditor.vue';

const store = useStore();
const { t } = useI18n();

const kanbanConfig = ref(null);
const isLoading = ref(true);
const selectedBoard = ref(null);

const loadConfig = async () => {
  isLoading.value = true;
  try {
    const accountId = store.getters.getCurrentAccountId;
    const response = await axios.get(`/api/v1/accounts/${accountId}/kanban_settings`);
    kanbanConfig.value = response.data;
  } catch (error) {
    useAlert(t('KANBAN_SETTINGS.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const saveConfig = async () => {
  try {
    const accountId = store.getters.getCurrentAccountId;
    await axios.put(`/api/v1/accounts/${accountId}/kanban_settings`, {
      kanban_config: kanbanConfig.value
    });
    useAlert(t('KANBAN_SETTINGS.SAVE_SUCCESS'));
  } catch (error) {
    useAlert(t('KANBAN_SETTINGS.SAVE_ERROR'));
  }
};

const createBoard = () => {
  const newBoard = {
    name: t('KANBAN_SETTINGS.NEW_BOARD'),
    stages: [],
    customAttributeKey: 'custom_stage',
    isDefault: false
  };
  selectedBoard.value = newBoard;
};

const deleteBoard = async (boardId) => {
  if (!confirm(t('KANBAN_SETTINGS.CONFIRM_DELETE'))) return;

  try {
    const accountId = store.getters.getCurrentAccountId;
    await axios.delete(`/api/v1/accounts/${accountId}/kanban_settings/boards/${boardId}`);
    await loadConfig();
    useAlert(t('KANBAN_SETTINGS.DELETE_SUCCESS'));
  } catch (error) {
    useAlert(t('KANBAN_SETTINGS.DELETE_ERROR'));
  }
};

onMounted(() => {
  loadConfig();
});
</script>

<template>
  <div class="flex h-full">
    <!-- Sidebar com lista de boards -->
    <div class="w-80 border-r border-n-weak p-4">
      <div class="flex items-center justify-between mb-4">
        <h2 class="text-lg font-semibold">{{ t('KANBAN_SETTINGS.BOARDS') }}</h2>
        <button
          class="px-3 py-1.5 bg-n-brand text-white rounded-lg"
          @click="createBoard"
        >
          {{ t('KANBAN_SETTINGS.NEW_BOARD') }}
        </button>
      </div>

      <div class="space-y-2">
        <div
          v-for="board in kanbanConfig?.boards"
          :key="board.id"
          class="p-3 rounded-lg border border-n-weak hover:border-n-brand cursor-pointer"
          :class="{ 'border-n-brand bg-n-brand/5': selectedBoard?.id === board.id }"
          @click="selectedBoard = board"
        >
          <div class="flex items-center justify-between">
            <span class="font-medium">{{ board.name }}</span>
            <span
              v-if="board.isDefault"
              class="px-2 py-0.5 bg-n-brand/20 text-n-brand text-xs rounded"
            >
              {{ t('KANBAN_SETTINGS.DEFAULT') }}
            </span>
          </div>
          <p class="text-sm text-n-slate-11 mt-1">
            {{ board.stages?.length || 0 }} {{ t('KANBAN_SETTINGS.STAGES') }}
          </p>
        </div>
      </div>
    </div>

    <!-- Editor do board selecionado -->
    <div class="flex-1 p-6">
      <KanbanBoardEditor
        v-if="selectedBoard"
        :board="selectedBoard"
        @save="saveConfig"
        @delete="deleteBoard(selectedBoard.id)"
      />
      <div
        v-else
        class="flex items-center justify-center h-full text-n-slate-11"
      >
        {{ t('KANBAN_SETTINGS.SELECT_BOARD') }}
      </div>
    </div>
  </div>
</template>
```

**Editor de Board: app/javascript/dashboard/routes/dashboard/settings/kanban/KanbanBoardEditor.vue**

```vue
<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import draggable from 'vuedraggable';

const props = defineProps({
  board: {
    type: Object,
    required: true
  }
});

const emit = defineEmits(['save', 'delete']);

const { t } = useI18n();

const addStage = () => {
  if (!props.board.stages) {
    props.board.stages = [];
  }

  props.board.stages.push({
    id: `stage-${Date.now()}`,
    name: t('KANBAN_SETTINGS.NEW_STAGE'),
    color: '#3b82f6',
    order: props.board.stages.length + 1,
    wipLimit: null
  });
};

const removeStage = (index) => {
  props.board.stages.splice(index, 1);
  // Reordenar
  props.board.stages.forEach((stage, i) => {
    stage.order = i + 1;
  });
};

const colorPresets = [
  '#3b82f6', '#8b5cf6', '#f59e0b', '#ec4899',
  '#10b981', '#ef4444', '#6366f1', '#64748b'
];
</script>

<template>
  <div class="space-y-6">
    <!-- Header -->
    <div class="flex items-center justify-between">
      <div>
        <h2 class="text-2xl font-bold">{{ board.name || t('KANBAN_SETTINGS.UNTITLED') }}</h2>
        <p class="text-sm text-n-slate-11">{{ board.description }}</p>
      </div>
      <div class="flex gap-2">
        <button
          class="px-4 py-2 border border-n-weak rounded-lg hover:bg-n-slate-2"
          @click="$emit('delete')"
        >
          {{ t('KANBAN_SETTINGS.DELETE_BOARD') }}
        </button>
        <button
          class="px-4 py-2 bg-n-brand text-white rounded-lg"
          @click="$emit('save')"
        >
          {{ t('KANBAN_SETTINGS.SAVE') }}
        </button>
      </div>
    </div>

    <!-- Configurações básicas -->
    <div class="grid grid-cols-2 gap-4">
      <div>
        <label class="block text-sm font-medium mb-2">
          {{ t('KANBAN_SETTINGS.BOARD_NAME') }}
        </label>
        <input
          v-model="board.name"
          type="text"
          class="w-full px-3 py-2 border border-n-weak rounded-lg"
        />
      </div>

      <div>
        <label class="block text-sm font-medium mb-2">
          {{ t('KANBAN_SETTINGS.CUSTOM_ATTRIBUTE_KEY') }}
        </label>
        <input
          v-model="board.customAttributeKey"
          type="text"
          class="w-full px-3 py-2 border border-n-weak rounded-lg"
          placeholder="sales_stage"
        />
      </div>

      <div class="col-span-2">
        <label class="flex items-center gap-2">
          <input
            v-model="board.isDefault"
            type="checkbox"
            class="w-4 h-4 rounded border-n-slate-6"
          />
          <span class="text-sm">{{ t('KANBAN_SETTINGS.SET_AS_DEFAULT') }}</span>
        </label>
      </div>
    </div>

    <!-- Estágios -->
    <div>
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-semibold">{{ t('KANBAN_SETTINGS.STAGES') }}</h3>
        <button
          class="px-3 py-1.5 bg-n-brand text-white rounded-lg text-sm"
          @click="addStage"
        >
          + {{ t('KANBAN_SETTINGS.ADD_STAGE') }}
        </button>
      </div>

      <draggable
        v-model="board.stages"
        item-key="id"
        class="space-y-3"
        handle=".drag-handle"
      >
        <template #item="{ element, index }">
          <div class="flex items-center gap-3 p-4 border border-n-weak rounded-lg bg-white">
            <!-- Drag handle -->
            <div class="drag-handle cursor-move text-n-slate-11">
              <i class="i-lucide-grip-vertical" />
            </div>

            <!-- Nome do estágio -->
            <div class="flex-1">
              <input
                v-model="element.name"
                type="text"
                class="w-full px-3 py-2 border border-n-weak rounded-lg"
                :placeholder="t('KANBAN_SETTINGS.STAGE_NAME')"
              />
            </div>

            <!-- Cor -->
            <div class="flex items-center gap-2">
              <div
                class="w-10 h-10 rounded border-2 border-white shadow-sm cursor-pointer"
                :style="{ backgroundColor: element.color }"
              />
              <select
                v-model="element.color"
                class="px-2 py-2 border border-n-weak rounded-lg"
              >
                <option
                  v-for="color in colorPresets"
                  :key="color"
                  :value="color"
                >
                  {{ color }}
                </option>
              </select>
            </div>

            <!-- WIP Limit -->
            <div class="w-24">
              <input
                v-model.number="element.wipLimit"
                type="number"
                class="w-full px-3 py-2 border border-n-weak rounded-lg text-center"
                :placeholder="t('KANBAN_SETTINGS.NO_LIMIT')"
              />
            </div>

            <!-- Deletar -->
            <button
              class="p-2 text-red-600 hover:bg-red-50 rounded"
              @click="removeStage(index)"
            >
              <i class="i-lucide-trash-2" />
            </button>
          </div>
        </template>
      </draggable>
    </div>
  </div>
</template>
```

---

#### 1.4 Frontend - Modificar KanbanView.vue

**Modificações em: app/javascript/dashboard/routes/dashboard/conversation/KanbanView.vue**

```vue
<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';

const store = useStore();
const { t } = useI18n();

// Carregar configurações do Kanban
const kanbanConfig = ref(null);
const selectedBoardId = ref(null);

const loadKanbanConfig = async () => {
  try {
    const accountId = store.getters.getCurrentAccountId;
    const response = await axios.get(`/api/v1/accounts/${accountId}/kanban_settings`);
    kanbanConfig.value = response.data;

    // Selecionar board padrão
    const defaultBoard = kanbanConfig.value.boards.find(b => b.isDefault);
    selectedBoardId.value = defaultBoard?.id || kanbanConfig.value.boards[0]?.id;
  } catch (error) {
    // Usar configuração padrão
    kanbanConfig.value = getDefaultConfig();
  }
};

// Board selecionado
const currentBoard = computed(() => {
  if (!kanbanConfig.value) return null;
  return kanbanConfig.value.boards.find(b => b.id === selectedBoardId.value);
});

// Estágios do board atual
const salesStages = computed(() => {
  return currentBoard.value?.stages || [];
});

// Substituir hardcoded stages pelo config
const conversationsByStage = computed(() => {
  const grouped = {};

  salesStages.value.forEach(stage => {
    const attributeKey = currentBoard.value.customAttributeKey || 'sales_stage';

    let filtered = allConversations.value.filter(conv =>
      conv.custom_attributes?.[attributeKey] === stage.id
    );

    // Aplicar outros filtros (inbox, assignee, etc)
    // ... resto da lógica

    grouped[stage.id] = {
      stage,
      conversations: filtered,
      totalValue: filtered.reduce((sum, c) =>
        sum + (c.custom_attributes?.deal_value || 0), 0
      )
    };
  });

  return grouped;
});

onMounted(() => {
  loadKanbanConfig();
  fetchConversations();
});
</script>

<template>
  <div class="flex h-screen flex-col bg-n-slate-1">
    <!-- Header com seletor de board -->
    <div class="flex items-center justify-between p-4 border-b border-n-weak">
      <div class="flex items-center gap-3">
        <i class="i-lucide-kanban-square text-2xl text-n-brand" />
        <h1 class="text-2xl font-bold">{{ currentBoard?.name || t('KANBAN.TITLE') }}</h1>
      </div>

      <!-- Seletor de board -->
      <select
        v-if="kanbanConfig?.boards?.length > 1"
        v-model="selectedBoardId"
        class="px-4 py-2 border border-n-weak rounded-lg"
      >
        <option
          v-for="board in kanbanConfig.boards"
          :key="board.id"
          :value="board.id"
        >
          {{ board.name }}
        </option>
      </select>
    </div>

    <!-- Resto do template (columns, etc) -->
  </div>
</template>
```

---

### Resumo da Implementação - Kanban

**Backend:**
1. ✅ Migration para `kanban_config` na tabela `accounts`
2. ✅ Model `Account` com validações e métodos helper
3. ✅ Controller `KanbanSettingsController` com CRUD de boards
4. ✅ Routes para API
5. ✅ View JBuilder para serialização

**Frontend:**
1. ✅ Página de configuração (`/settings/kanban`)
2. ✅ Editor de boards com drag & drop
3. ✅ Seletor de cores e WIP limits
4. ✅ Modificar `KanbanView.vue` para usar config dinâmica
5. ✅ Traduções

**Permissões:**
- ✅ Apenas administrators podem configurar
- ✅ Política usando `authorize Current.account, :update?`

---

## 📱 PARTE 2: SUPORTE A GRUPOS WHATSAPP

### Objetivo
Implementar suporte completo a grupos WhatsApp, incluindo:
- Receber mensagens de grupos
- Enviar mensagens para grupos
- Criar grupos
- Adicionar/remover membros
- Alterar nome e descrição
- Promover/rebaixar admins
- Identificar remetente no grupo

### Desafios Identificados

**Problema Atual:**
```ruby
# app/services/whatsapp/zapi_handlers/received_callback.rb:35
def should_process_message?
  !@raw_message[:isGroup] &&  # ← BLOQUEIA GRUPOS
  !@raw_message[:isNewsletter] &&
  !@raw_message[:broadcast]
end
```

**Source ID:**
- Atualmente: apenas números `\d{1,15}`
- Grupos: precisam aceitar formato `120363123456789123-1234567890@g.us`

---

### 2.1 Backend - Modificações no Modelo

**Migration: Adicionar suporte a grupos**

```ruby
# db/migrate/YYYYMMDD_add_whatsapp_group_support.rb
class AddWhatsappGroupSupport < ActiveRecord::Migration[7.0]
  def change
    # Adicionar flag para identificar contatos de grupo
    add_column :contacts, :is_whatsapp_group, :boolean, default: false

    # Adicionar metadata de grupo em conversation
    # Usar additional_attributes que já existe como JSONB

    # Criar tabela para membros de grupo (opcional, para funcionalidades avançadas)
    create_table :whatsapp_group_members do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.string :phone_number, null: false
      t.string :name
      t.boolean :is_admin, default: false
      t.datetime :joined_at
      t.timestamps
    end

    add_index :whatsapp_group_members, [:conversation_id, :contact_id], unique: true
  end
end
```

**Model: app/models/whatsapp_group_member.rb** (novo)

```ruby
class WhatsappGroupMember < ApplicationRecord
  belongs_to :conversation
  belongs_to :contact, optional: true

  validates :phone_number, presence: true
  validates :conversation_id, uniqueness: { scope: :phone_number }

  scope :admins, -> { where(is_admin: true) }
  scope :members, -> { where(is_admin: false) }
end
```

**Model: app/models/conversation.rb** (adicionar métodos)

```ruby
# app/models/conversation.rb
has_many :whatsapp_group_members, dependent: :destroy

def whatsapp_group?
  additional_attributes&.dig('is_whatsapp_group') == true
end

def whatsapp_group_id
  additional_attributes&.dig('whatsapp_group_id')
end

def whatsapp_group_name
  additional_attributes&.dig('whatsapp_group_name')
end

def update_whatsapp_group_info(group_data)
  self.additional_attributes ||= {}
  self.additional_attributes['is_whatsapp_group'] = true
  self.additional_attributes['whatsapp_group_id'] = group_data[:id]
  self.additional_attributes['whatsapp_group_name'] = group_data[:name]
  self.additional_attributes['whatsapp_group_description'] = group_data[:description]
  self.additional_attributes['whatsapp_group_participants_count'] = group_data[:participants]&.length
  save!
end

def add_whatsapp_group_member(phone_number, name: nil, is_admin: false)
  whatsapp_group_members.find_or_create_by!(phone_number: phone_number) do |member|
    member.name = name
    member.is_admin = is_admin
    member.joined_at = Time.current
  end
end
```

**Model: app/models/contact.rb** (adicionar métodos)

```ruby
# app/models/contact.rb
scope :whatsapp_groups, -> { where(is_whatsapp_group: true) }
scope :individuals, -> { where(is_whatsapp_group: false) }

def whatsapp_group?
  is_whatsapp_group == true
end
```

---

### 2.2 Backend - Atualizar Validação de Source ID

**lib/regex_helper.rb**

```ruby
module RegexHelper
  # Aceitar tanto números individuais quanto IDs de grupo WhatsApp
  # Formato individual: 5511987654321
  # Formato grupo: 120363123456789123-1234567890@g.us
  WHATSAPP_CHANNEL_REGEX = Regexp.new('^(\d{1,15}|[\w\-@.]+)$')

  # Identificar se é grupo
  def self.whatsapp_group_id?(source_id)
    source_id =~ /@g\.us$/ || source_id.include?('-')
  end
end
```

**app/models/contact_inbox.rb**

```ruby
# Atualizar validação para aceitar grupos
def validate_whatsapp_source_id
  return if WHATSAPP_CHANNEL_REGEX.match?(source_id)

  errors.add(:source_id, "invalid source id for whatsapp inbox")
end
```

---

### 2.3 Backend - Processar Mensagens de Grupo

**app/services/whatsapp/zapi_handlers/received_callback.rb**

```ruby
class Whatsapp::ZapiHandlers::ReceivedCallback < Whatsapp::ZapiHandlers::BaseHandler
  def process
    return unless should_process_message?

    set_contact
    set_conversation
    create_message

    # Para grupos, atualizar informações
    update_group_info if @raw_message[:isGroup]
  end

  private

  def should_process_message?
    # REMOVER verificação que bloqueia grupos
    !@raw_message[:isNewsletter] &&
      !@raw_message[:broadcast] &&
      !@raw_message[:isStatusReply] &&
      !@raw_message.key?(:notification)
  end

  def set_contact
    if @raw_message[:isGroup]
      # Para grupos, criar/buscar contact especial
      set_group_contact
    else
      # Lógica atual para contatos individuais
      set_individual_contact
    end
  end

  def set_group_contact
    # Contact do grupo
    @group_contact = @inbox.contacts.find_or_create_by!(
      source_id: @raw_message[:chatLid] || @raw_message[:from]
    ) do |contact|
      contact.name = @raw_message[:chatName] || "Grupo WhatsApp"
      contact.is_whatsapp_group = true
    end

    # Contact do remetente individual (quem enviou no grupo)
    @sender_contact = @inbox.contacts.find_or_create_by!(
      source_id: @raw_message[:author] || @raw_message[:from]
    ) do |contact|
      contact.name = @raw_message[:senderName] || extract_phone(@raw_message[:author])
    end

    @contact = @group_contact
  end

  def set_individual_contact
    # Lógica atual...
  end

  def set_conversation
    @conversation = @contact_inbox.conversations.last

    return unless @conversation.nil?

    @conversation = ::Conversation.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id,
      additional_attributes: @raw_message[:isGroup] ? group_attributes : {}
    )
  end

  def group_attributes
    {
      is_whatsapp_group: true,
      whatsapp_group_id: @raw_message[:chatLid],
      whatsapp_group_name: @raw_message[:chatName],
      whatsapp_group_participants_count: @raw_message[:participants]&.length
    }
  end

  def create_message
    @message = @conversation.messages.create!(
      content: @raw_message[:text][:message] || '',
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :incoming,
      sender: @raw_message[:isGroup] ? @sender_contact : @contact,
      source_id: @raw_message[:messageId],
      additional_attributes: message_additional_attributes
    )
  end

  def message_additional_attributes
    attrs = {}

    if @raw_message[:isGroup]
      attrs[:group_message] = true
      attrs[:group_sender_id] = @raw_message[:author]
      attrs[:group_sender_name] = @raw_message[:senderName]
    end

    # Anexos, localização, etc
    # ... resto da lógica

    attrs
  end

  def update_group_info
    return unless @conversation

    @conversation.update_whatsapp_group_info({
      id: @raw_message[:chatLid],
      name: @raw_message[:chatName],
      description: @raw_message[:groupDescription],
      participants: @raw_message[:participants]
    })

    # Atualizar membros
    sync_group_members if @raw_message[:participants].present?
  end

  def sync_group_members
    @raw_message[:participants].each do |participant|
      @conversation.add_whatsapp_group_member(
        participant[:id],
        name: participant[:name],
        is_admin: participant[:isAdmin] || participant[:isSuperAdmin]
      )
    end
  end
end
```

---

### 2.4 Backend - Enviar Mensagens para Grupo

**app/services/whatsapp/providers/whatsapp_zapi_service.rb**

```ruby
# Adicionar método para enviar para grupo
def send_group_message(phone_number, message, group_id)
  response = HTTParty.post(
    "#{phone_number_id}/send-text",
    headers: api_headers,
    body: {
      phone: group_id,  # ID do grupo ao invés de número individual
      message: message
    }.to_json
  )

  process_response(response)
end

# Atualizar send_message para detectar grupos
def send_message(phone_number, message)
  # Detectar se é grupo
  if RegexHelper.whatsapp_group_id?(phone_number)
    send_group_message(phone_number_id, message, phone_number)
  else
    # Lógica atual para mensagens individuais
    send_individual_message(phone_number, message)
  end
end
```

---

### 2.5 Backend - API para Gerenciar Grupos

**Controller: app/controllers/api/v1/accounts/whatsapp_groups_controller.rb** (novo)

```ruby
class Api::V1::Accounts::WhatsappGroupsController < Api::V1::Accounts::BaseController
  before_action :set_conversation
  before_action :check_whatsapp_group

  # GET /api/v1/accounts/:account_id/conversations/:conversation_id/whatsapp_group
  def show
    @group_info = {
      id: @conversation.whatsapp_group_id,
      name: @conversation.whatsapp_group_name,
      description: @conversation.additional_attributes['whatsapp_group_description'],
      participants_count: @conversation.whatsapp_group_members.count,
      members: @conversation.whatsapp_group_members.includes(:contact)
    }
  end

  # PUT /api/v1/accounts/:account_id/conversations/:conversation_id/whatsapp_group/name
  def update_name
    service = Whatsapp::GroupService.new(conversation: @conversation)
    service.update_name(params[:name])

    render json: { success: true, name: params[:name] }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # PUT /api/v1/accounts/:account_id/conversations/:conversation_id/whatsapp_group/description
  def update_description
    service = Whatsapp::GroupService.new(conversation: @conversation)
    service.update_description(params[:description])

    render json: { success: true, description: params[:description] }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /api/v1/accounts/:account_id/conversations/:conversation_id/whatsapp_group/members
  def add_member
    service = Whatsapp::GroupService.new(conversation: @conversation)
    service.add_member(params[:phone_number])

    render json: { success: true }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # DELETE /api/v1/accounts/:account_id/conversations/:conversation_id/whatsapp_group/members/:phone_number
  def remove_member
    service = Whatsapp::GroupService.new(conversation: @conversation)
    service.remove_member(params[:phone_number])

    render json: { success: true }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # PUT /api/v1/accounts/:account_id/conversations/:conversation_id/whatsapp_group/members/:phone_number/promote
  def promote_admin
    service = Whatsapp::GroupService.new(conversation: @conversation)
    service.promote_admin(params[:phone_number])

    render json: { success: true }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # PUT /api/v1/accounts/:account_id/conversations/:conversation_id/whatsapp_group/members/:phone_number/demote
  def demote_admin
    service = Whatsapp::GroupService.new(conversation: @conversation)
    service.demote_admin(params[:phone_number])

    render json: { success: true }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_conversation
    @conversation = Current.account.conversations.find(params[:conversation_id])
  end

  def check_whatsapp_group
    render json: { error: 'Not a WhatsApp group' }, status: :unprocessable_entity unless @conversation.whatsapp_group?
  end
end
```

**Service: app/services/whatsapp/group_service.rb** (novo)

```ruby
class Whatsapp::GroupService
  def initialize(conversation:)
    @conversation = conversation
    @inbox = conversation.inbox
    @provider = get_provider_service
  end

  def update_name(new_name)
    @provider.update_group_name(@conversation.whatsapp_group_id, new_name)
    @conversation.additional_attributes['whatsapp_group_name'] = new_name
    @conversation.save!
  end

  def update_description(new_description)
    @provider.update_group_description(@conversation.whatsapp_group_id, new_description)
    @conversation.additional_attributes['whatsapp_group_description'] = new_description
    @conversation.save!
  end

  def add_member(phone_number)
    @provider.add_group_participant(@conversation.whatsapp_group_id, phone_number)
    @conversation.add_whatsapp_group_member(phone_number)
  end

  def remove_member(phone_number)
    @provider.remove_group_participant(@conversation.whatsapp_group_id, phone_number)
    member = @conversation.whatsapp_group_members.find_by(phone_number: phone_number)
    member&.destroy
  end

  def promote_admin(phone_number)
    @provider.promote_group_admin(@conversation.whatsapp_group_id, phone_number)
    member = @conversation.whatsapp_group_members.find_by(phone_number: phone_number)
    member&.update!(is_admin: true)
  end

  def demote_admin(phone_number)
    @provider.demote_group_admin(@conversation.whatsapp_group_id, phone_number)
    member = @conversation.whatsapp_group_members.find_by(phone_number: phone_number)
    member&.update!(is_admin: false)
  end

  private

  def get_provider_service
    case @inbox.channel.provider
    when 'zapi'
      Whatsapp::Providers::WhatsappZapiService.new(whatsapp_channel: @inbox.channel)
    when 'whatsapp_cloud'
      Whatsapp::Providers::WhatsappCloudService.new(whatsapp_channel: @inbox.channel)
    else
      raise "Unsupported provider: #{@inbox.channel.provider}"
    end
  end
end
```

**Adicionar métodos no provider ZAPI:**

```ruby
# app/services/whatsapp/providers/whatsapp_zapi_service.rb
def update_group_name(group_id, new_name)
  HTTParty.put(
    "#{phone_number_id}/group/#{group_id}/name",
    headers: api_headers,
    body: { name: new_name }.to_json
  )
end

def update_group_description(group_id, new_description)
  HTTParty.put(
    "#{phone_number_id}/group/#{group_id}/description",
    headers: api_headers,
    body: { description: new_description }.to_json
  )
end

def add_group_participant(group_id, phone_number)
  HTTParty.post(
    "#{phone_number_id}/group/#{group_id}/participants",
    headers: api_headers,
    body: { phones: [phone_number] }.to_json
  )
end

def remove_group_participant(group_id, phone_number)
  HTTParty.delete(
    "#{phone_number_id}/group/#{group_id}/participants",
    headers: api_headers,
    body: { phones: [phone_number] }.to_json
  )
end

def promote_group_admin(group_id, phone_number)
  HTTParty.put(
    "#{phone_number_id}/group/#{group_id}/admins",
    headers: api_headers,
    body: { phones: [phone_number] }.to_json
  )
end

def demote_group_admin(group_id, phone_number)
  HTTParty.delete(
    "#{phone_number_id}/group/#{group_id}/admins",
    headers: api_headers,
    body: { phones: [phone_number] }.to_json
  )
end
```

---

### 2.6 Frontend - UI para Grupos

**Identificador de Grupo em ConversationCard.vue**

```vue
<!-- Adicionar badge de grupo -->
<div v-if="chat.additional_attributes?.is_whatsapp_group" class="flex items-center gap-1">
  <i class="i-lucide-users text-sm text-n-brand" />
  <span class="text-xs text-n-slate-11">
    {{ chat.additional_attributes.whatsapp_group_participants_count }} membros
  </span>
</div>
```

**Painel de Informações do Grupo: app/javascript/dashboard/components/WhatsappGroupPanel.vue**

```vue
<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';

const props = defineProps({
  conversationId: {
    type: Number,
    required: true
  }
});

const store = useStore();
const { t } = useI18n();

const groupInfo = ref(null);
const isLoading = ref(true);
const newMemberPhone = ref('');

const conversation = computed(() =>
  store.getters.getConversationById(props.conversationId)
);

const loadGroupInfo = async () => {
  isLoading.value = true;
  try {
    const accountId = store.getters.getCurrentAccountId;
    const response = await axios.get(
      `/api/v1/accounts/${accountId}/conversations/${props.conversationId}/whatsapp_group`
    );
    groupInfo.value = response.data;
  } catch (error) {
    useAlert(t('WHATSAPP_GROUP.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const updateGroupName = async () => {
  const newName = prompt(t('WHATSAPP_GROUP.ENTER_NEW_NAME'), groupInfo.value.name);
  if (!newName) return;

  try {
    const accountId = store.getters.getCurrentAccountId;
    await axios.put(
      `/api/v1/accounts/${accountId}/conversations/${props.conversationId}/whatsapp_group/name`,
      { name: newName }
    );
    groupInfo.value.name = newName;
    useAlert(t('WHATSAPP_GROUP.NAME_UPDATED'));
  } catch (error) {
    useAlert(t('WHATSAPP_GROUP.UPDATE_ERROR'));
  }
};

const addMember = async () => {
  if (!newMemberPhone.value) return;

  try {
    const accountId = store.getters.getCurrentAccountId;
    await axios.post(
      `/api/v1/accounts/${accountId}/conversations/${props.conversationId}/whatsapp_group/members`,
      { phone_number: newMemberPhone.value }
    );
    newMemberPhone.value = '';
    await loadGroupInfo();
    useAlert(t('WHATSAPP_GROUP.MEMBER_ADDED'));
  } catch (error) {
    useAlert(t('WHATSAPP_GROUP.ADD_MEMBER_ERROR'));
  }
};

const removeMember = async (phoneNumber) => {
  if (!confirm(t('WHATSAPP_GROUP.CONFIRM_REMOVE'))) return;

  try {
    const accountId = store.getters.getCurrentAccountId;
    await axios.delete(
      `/api/v1/accounts/${accountId}/conversations/${props.conversationId}/whatsapp_group/members/${phoneNumber}`
    );
    await loadGroupInfo();
    useAlert(t('WHATSAPP_GROUP.MEMBER_REMOVED'));
  } catch (error) {
    useAlert(t('WHATSAPP_GROUP.REMOVE_ERROR'));
  }
};

onMounted(() => {
  loadGroupInfo();
});
</script>

<template>
  <div class="p-4 space-y-4">
    <!-- Header do grupo -->
    <div class="flex items-center gap-3">
      <div class="w-12 h-12 bg-n-brand/10 rounded-full flex items-center justify-center">
        <i class="i-lucide-users text-2xl text-n-brand" />
      </div>
      <div class="flex-1">
        <h3 class="font-semibold text-lg">{{ groupInfo?.name }}</h3>
        <p class="text-sm text-n-slate-11">
          {{ groupInfo?.participants_count }} {{ t('WHATSAPP_GROUP.MEMBERS') }}
        </p>
      </div>
      <button
        class="p-2 hover:bg-n-slate-3 rounded-lg"
        @click="updateGroupName"
      >
        <i class="i-lucide-edit-2" />
      </button>
    </div>

    <!-- Descrição -->
    <div v-if="groupInfo?.description" class="p-3 bg-n-slate-2 rounded-lg">
      <p class="text-sm">{{ groupInfo.description }}</p>
    </div>

    <!-- Adicionar membro -->
    <div class="flex gap-2">
      <input
        v-model="newMemberPhone"
        type="tel"
        :placeholder="t('WHATSAPP_GROUP.ENTER_PHONE')"
        class="flex-1 px-3 py-2 border border-n-weak rounded-lg"
      />
      <button
        class="px-4 py-2 bg-n-brand text-white rounded-lg"
        @click="addMember"
      >
        {{ t('WHATSAPP_GROUP.ADD') }}
      </button>
    </div>

    <!-- Lista de membros -->
    <div class="space-y-2">
      <h4 class="font-medium">{{ t('WHATSAPP_GROUP.MEMBERS') }}</h4>
      <div
        v-for="member in groupInfo?.members"
        :key="member.id"
        class="flex items-center justify-between p-2 hover:bg-n-slate-2 rounded-lg"
      >
        <div class="flex items-center gap-2">
          <div class="w-8 h-8 bg-n-slate-3 rounded-full" />
          <div>
            <p class="text-sm font-medium">{{ member.name || member.phone_number }}</p>
            <p class="text-xs text-n-slate-11">{{ member.phone_number }}</p>
          </div>
        </div>
        <div class="flex items-center gap-2">
          <span
            v-if="member.is_admin"
            class="px-2 py-0.5 bg-n-brand/20 text-n-brand text-xs rounded"
          >
            Admin
          </span>
          <button
            class="p-1 text-red-600 hover:bg-red-50 rounded"
            @click="removeMember(member.phone_number)"
          >
            <i class="i-lucide-trash-2 text-sm" />
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
```

**Indicador de Remetente em Mensagens de Grupo:**

```vue
<!-- ConversationMessage.vue -->
<div v-if="message.additional_attributes?.group_message" class="text-xs text-n-brand font-medium mb-1">
  {{ message.additional_attributes.group_sender_name }}
</div>
<div class="message-content">
  {{ message.content }}
</div>
```

---

### Resumo da Implementação - Grupos WhatsApp

**Backend:**
1. ✅ Migration para `is_whatsapp_group` em contacts
2. ✅ Tabela `whatsapp_group_members`
3. ✅ Atualizar regex para aceitar IDs de grupo
4. ✅ Modificar `received_callback.rb` para processar grupos
5. ✅ Service `WhatsappGroupService` para operações
6. ✅ Controller `WhatsappGroupsController` com API
7. ✅ Adicionar métodos no provider ZAPI

**Frontend:**
1. ✅ Badge de grupo em ConversationCard
2. ✅ Painel `WhatsappGroupPanel` para gerenciar
3. ✅ Indicador de remetente em mensagens
4. ✅ UI para adicionar/remover membros
5. ✅ UI para alterar nome/descrição

**Funcionalidades Suportadas:**
- ✅ Receber mensagens de grupos
- ✅ Enviar mensagens para grupos
- ✅ Identificar quem enviou no grupo
- ✅ Adicionar membros
- ✅ Remover membros
- ✅ Promover/rebaixar admins
- ✅ Alterar nome do grupo
- ✅ Alterar descrição do grupo
- ✅ Listar membros

---

## 📝 Próximos Passos

Qual funcionalidade você gostaria de implementar primeiro?

**Opção A: Kanban Personalizável**
- Tempo estimado: ~2-3 dias
- Complexidade: Média
- Impacto: Alto (permite personalização por empresa)

**Opção B: Grupos WhatsApp**
- Tempo estimado: ~3-5 dias
- Complexidade: Alta
- Impacto: Muito Alto (nova funcionalidade completa)

**Opção C: Implementar ambas em sequência**
- Começar com Kanban (mais simples)
- Depois Grupos WhatsApp

Qual você prefere que eu comece a implementar agora?
