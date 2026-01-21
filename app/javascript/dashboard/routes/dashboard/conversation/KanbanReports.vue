<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';

const store = useStore();
const { t } = useI18n();

const selectedBoard = ref(null);
const dateRange = ref('30'); // dias
const isLoading = ref(false);

const kanbanBoards = computed(() => store.getters['kanban/getBoards'] || []);
const allConversations = computed(() => store.getters.getAllConversations || []);
const agents = computed(() => store.getters['agents/getAgents'] || []);

const boardConversations = computed(() => {
  if (!selectedBoard.value) return [];
  const attrKey = selectedBoard.value.customAttributeKey;
  return allConversations.value.filter(
    conv => conv.custom_attributes?.[attrKey]
  );
});

// Métricas por estágio
const stageMetrics = computed(() => {
  if (!selectedBoard.value) return [];
  
  return selectedBoard.value.stages.map(stage => {
    const attrKey = selectedBoard.value.customAttributeKey;
    const conversations = boardConversations.value.filter(
      conv => conv.custom_attributes?.[attrKey] === stage.id
    );
    
    const totalValue = conversations.reduce((sum, conv) => 
      sum + (conv.custom_attributes?.deal_value || 0), 0
    );
    
    return {
      ...stage,
      count: conversations.length,
      totalValue,
      avgValue: conversations.length > 0 ? totalValue / conversations.length : 0,
    };
  });
});

// Métricas por agente
const agentMetrics = computed(() => {
  if (!selectedBoard.value) return [];
  
  const metrics = agents.value.map(agent => {
    const conversations = boardConversations.value.filter(
      conv => conv.meta?.assignee?.id === agent.id
    );
    
    const totalValue = conversations.reduce((sum, conv) => 
      sum + (conv.custom_attributes?.deal_value || 0), 0
    );
    
    return {
      agent,
      count: conversations.length,
      totalValue,
      avgValue: conversations.length > 0 ? totalValue / conversations.length : 0,
    };
  }).filter(m => m.count > 0);
  
  return metrics.sort((a, b) => b.count - a.count);
});

// Taxa de conversão
const conversionRate = computed(() => {
  if (!selectedBoard.value || !stageMetrics.value.length) return 0;
  
  const firstStage = stageMetrics.value[0];
  const lastStage = stageMetrics.value[stageMetrics.value.length - 1];
  
  if (firstStage.count === 0) return 0;
  return (lastStage.count / firstStage.count) * 100;
});

// Tempo médio por estágio (simplificado)
const avgTimePerStage = computed(() => {
  // Implementação simplificada - em produção, calcular com base em timestamps reais
  return stageMetrics.value.map(stage => ({
    ...stage,
    avgDays: Math.floor(Math.random() * 15) + 1, // Mock data
  }));
});

const formatCurrency = (value) => {
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
    minimumFractionDigits: 0,
  }).format(value || 0);
};

const exportToCSV = () => {
  if (!selectedBoard.value) return;
  
  const headers = ['Estágio', 'Quantidade', 'Valor Total', 'Valor Médio'];
  const rows = stageMetrics.value.map(s => [
    s.name,
    s.count,
    s.totalValue,
    s.avgValue
  ]);
  
  const csv = [
    headers.join(','),
    ...rows.map(r => r.join(','))
  ].join('\n');
  
  const blob = new Blob([csv], { type: 'text/csv' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `kanban-report-${selectedBoard.value.name}-${Date.now()}.csv`;
  a.click();
};

onMounted(() => {
  store.dispatch('kanban/fetch');
  store.dispatch('agents/get');
  
  if (kanbanBoards.value.length > 0) {
    selectedBoard.value = kanbanBoards.value.find(b => b.isDefault) || kanbanBoards.value[0];
  }
});
</script>

<template>
  <div class="flex flex-col h-full bg-slate-50">
    <!-- Header -->
    <div class="bg-white border-b border-slate-200 p-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-slate-900 flex items-center gap-3">
            <i class="i-lucide-bar-chart-3 text-woot-600" />
            Relatórios Kanban
          </h1>
          <p class="text-sm text-slate-500 mt-1">
            Análise de desempenho e métricas do seu pipeline
          </p>
        </div>
        
        <button
          v-if="selectedBoard"
          @click="exportToCSV"
          class="inline-flex items-center gap-2 px-4 py-2 bg-woot-600 text-white rounded-lg hover:bg-woot-700 transition-colors shadow-sm"
        >
          <i class="i-lucide-download" />
          Exportar CSV
        </button>
      </div>

      <div class="flex items-center gap-4 mt-4">
        <select
          v-model="selectedBoard"
          class="px-3 py-2 border border-slate-200 rounded-lg focus:border-woot-500 focus:ring-2 focus:ring-woot-100 outline-none"
        >
          <option v-for="board in kanbanBoards" :key="board.id" :value="board">
            {{ board.name }}
          </option>
        </select>

        <select
          v-model="dateRange"
          class="px-3 py-2 border border-slate-200 rounded-lg focus:border-woot-500 focus:ring-2 focus:ring-woot-100 outline-none"
        >
          <option value="7">Últimos 7 dias</option>
          <option value="30">Últimos 30 dias</option>
          <option value="90">Últimos 90 dias</option>
          <option value="365">Último ano</option>
        </select>
      </div>
    </div>

    <!-- Content -->
    <div class="flex-1 overflow-y-auto p-6 space-y-6">
      <div v-if="!selectedBoard" class="flex flex-col items-center justify-center p-12 text-center">
        <i class="i-lucide-bar-chart-3 text-6xl text-slate-300 mb-4" />
        <h3 class="text-lg font-semibold text-slate-700 mb-2">
          Nenhum quadro selecionado
        </h3>
        <p class="text-sm text-slate-500">
          Selecione um quadro para visualizar os relatórios
        </p>
      </div>

      <div v-else class="space-y-6">
        <!-- Resumo Geral -->
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div class="bg-white rounded-xl border border-slate-200 p-6 shadow-sm">
            <div class="flex items-center justify-between mb-2">
              <span class="text-sm font-semibold text-slate-500 uppercase">Total de Tarefas</span>
              <i class="i-lucide-briefcase text-blue-500 text-xl" />
            </div>
            <p class="text-3xl font-black text-slate-900">{{ boardConversations.length }}</p>
          </div>

          <div class="bg-white rounded-xl border border-slate-200 p-6 shadow-sm">
            <div class="flex items-center justify-between mb-2">
              <span class="text-sm font-semibold text-slate-500 uppercase">Valor Total</span>
              <i class="i-lucide-dollar-sign text-emerald-500 text-xl" />
            </div>
            <p class="text-3xl font-black text-emerald-600">
              {{ formatCurrency(stageMetrics.reduce((sum, s) => sum + s.totalValue, 0)) }}
            </p>
          </div>

          <div class="bg-white rounded-xl border border-slate-200 p-6 shadow-sm">
            <div class="flex items-center justify-between mb-2">
              <span class="text-sm font-semibold text-slate-500 uppercase">Taxa de Conversão</span>
              <i class="i-lucide-trending-up text-orange-500 text-xl" />
            </div>
            <p class="text-3xl font-black text-slate-900">{{ conversionRate.toFixed(1) }}%</p>
          </div>

          <div class="bg-white rounded-xl border border-slate-200 p-6 shadow-sm">
            <div class="flex items-center justify-between mb-2">
              <span class="text-sm font-semibold text-slate-500 uppercase">Agentes Ativos</span>
              <i class="i-lucide-users text-purple-500 text-xl" />
            </div>
            <p class="text-3xl font-black text-slate-900">{{ agentMetrics.length }}</p>
          </div>
        </div>

        <!-- Métricas por Estágio -->
        <div class="bg-white rounded-xl border border-slate-200 p-6 shadow-sm">
          <h3 class="text-lg font-bold text-slate-900 mb-4 flex items-center gap-2">
            <i class="i-lucide-layers text-woot-600" />
            Desempenho por Estágio
          </h3>
          
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead class="bg-slate-50 border-b border-slate-200">
                <tr>
                  <th class="text-left p-3 text-xs font-bold text-slate-600 uppercase">Estágio</th>
                  <th class="text-center p-3 text-xs font-bold text-slate-600 uppercase">Quantidade</th>
                  <th class="text-right p-3 text-xs font-bold text-slate-600 uppercase">Valor Total</th>
                  <th class="text-right p-3 text-xs font-bold text-slate-600 uppercase">Valor Médio</th>
                  <th class="text-center p-3 text-xs font-bold text-slate-600 uppercase">% do Total</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="stage in stageMetrics" :key="stage.id" class="border-b border-slate-100 hover:bg-slate-50">
                  <td class="p-3">
                    <div class="flex items-center gap-2">
                      <div class="w-3 h-3 rounded-full" :style="{ backgroundColor: stage.color }" />
                      <span class="font-semibold text-slate-900">{{ stage.name }}</span>
                    </div>
                  </td>
                  <td class="p-3 text-center font-semibold">{{ stage.count }}</td>
                  <td class="p-3 text-right font-semibold text-emerald-600">{{ formatCurrency(stage.totalValue) }}</td>
                  <td class="p-3 text-right text-slate-600">{{ formatCurrency(stage.avgValue) }}</td>
                  <td class="p-3 text-center">
                    <span class="inline-block px-2 py-1 bg-woot-50 text-woot-700 rounded text-xs font-bold">
                      {{ ((stage.count / boardConversations.length) * 100).toFixed(1) }}%
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- Métricas por Agente -->
        <div class="bg-white rounded-xl border border-slate-200 p-6 shadow-sm">
          <h3 class="text-lg font-bold text-slate-900 mb-4 flex items-center gap-2">
            <i class="i-lucide-user-circle text-woot-600" />
            Desempenho por Agente
          </h3>
          
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <div
              v-for="metric in agentMetrics"
              :key="metric.agent.id"
              class="border border-slate-200 rounded-lg p-4 hover:shadow-md transition-shadow"
            >
              <div class="flex items-center gap-3 mb-3">
                <img
                  v-if="metric.agent.thumbnail"
                  :src="metric.agent.thumbnail"
                  :alt="metric.agent.name"
                  class="w-10 h-10 rounded-full object-cover"
                />
                <div class="flex-shrink-0 w-10 h-10 rounded-full bg-blue-100 flex items-center justify-center text-blue-600 font-bold" v-else>
                  {{ metric.agent.name.charAt(0).toUpperCase() }}
                </div>
                <div class="flex-1 min-w-0">
                  <p class="font-semibold text-slate-900 truncate">{{ metric.agent.name }}</p>
                  <p class="text-xs text-slate-500">{{ metric.count }} tarefa(s)</p>
                </div>
              </div>
              
              <div class="space-y-2">
                <div class="flex items-center justify-between text-sm">
                  <span class="text-slate-500">Valor Total:</span>
                  <span class="font-semibold text-emerald-600">{{ formatCurrency(metric.totalValue) }}</span>
                </div>
                <div class="flex items-center justify-between text-sm">
                  <span class="text-slate-500">Ticket Médio:</span>
                  <span class="font-semibold text-slate-700">{{ formatCurrency(metric.avgValue) }}</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
