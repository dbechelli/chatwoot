<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

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
  <div class="flex h-full flex-col bg-n-slate-2">
    <div class="border-b border-n-weak bg-n-surface-1 p-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="flex items-center gap-3 text-2xl font-medium text-n-slate-12">
            <i class="i-lucide-bar-chart-3 text-n-blue-11" />
            Relatórios Kanban
          </h1>
          <p class="mt-1 text-sm text-n-slate-11">
            Análise de desempenho e métricas do seu pipeline
          </p>
        </div>
        
        <Button
          v-if="selectedBoard"
          @click="exportToCSV"
          blue
          solid
          icon="i-lucide-download"
          label="Exportar CSV"
        />
      </div>

      <div class="flex items-center gap-4 mt-4">
        <select
          v-model="selectedBoard"
          class="rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
        >
          <option v-for="board in kanbanBoards" :key="board.id" :value="board">
            {{ board.name }}
          </option>
        </select>

        <select
          v-model="dateRange"
          class="rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
        >
          <option value="7">Últimos 7 dias</option>
          <option value="30">Últimos 30 dias</option>
          <option value="90">Últimos 90 dias</option>
          <option value="365">Último ano</option>
        </select>
      </div>
    </div>

    <div class="flex-1 overflow-y-auto p-6 space-y-6">
      <div v-if="!selectedBoard" class="flex flex-col items-center justify-center p-12 text-center">
        <i class="i-lucide-bar-chart-3 mb-4 text-6xl text-n-slate-8" />
        <h3 class="mb-2 text-lg font-medium text-n-slate-12">
          Nenhum quadro selecionado
        </h3>
        <p class="text-sm text-n-slate-11">
          Selecione um quadro para visualizar os relatórios
        </p>
      </div>

      <div v-else class="space-y-6">
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div class="rounded-2xl border border-n-weak bg-n-surface-1 p-6">
            <div class="flex items-center justify-between mb-2">
              <span class="text-sm font-medium uppercase text-n-slate-10">Total de Tarefas</span>
              <i class="i-lucide-briefcase text-xl text-n-blue-11" />
            </div>
            <p class="text-3xl font-semibold text-n-slate-12">{{ boardConversations.length }}</p>
          </div>

          <div class="rounded-2xl border border-n-weak bg-n-surface-1 p-6">
            <div class="flex items-center justify-between mb-2">
              <span class="text-sm font-medium uppercase text-n-slate-10">Valor Total</span>
              <i class="i-lucide-dollar-sign text-xl text-n-teal-11" />
            </div>
            <p class="text-3xl font-semibold text-n-teal-11">
              {{ formatCurrency(stageMetrics.reduce((sum, s) => sum + s.totalValue, 0)) }}
            </p>
          </div>

          <div class="rounded-2xl border border-n-weak bg-n-surface-1 p-6">
            <div class="flex items-center justify-between mb-2">
              <span class="text-sm font-medium uppercase text-n-slate-10">Taxa de Conversão</span>
              <i class="i-lucide-trending-up text-xl text-n-amber-11" />
            </div>
            <p class="text-3xl font-semibold text-n-slate-12">{{ conversionRate.toFixed(1) }}%</p>
          </div>

          <div class="rounded-2xl border border-n-weak bg-n-surface-1 p-6">
            <div class="flex items-center justify-between mb-2">
              <span class="text-sm font-medium uppercase text-n-slate-10">Agentes Ativos</span>
              <i class="i-lucide-users text-xl text-n-blue-11" />
            </div>
            <p class="text-3xl font-semibold text-n-slate-12">{{ agentMetrics.length }}</p>
          </div>
        </div>

        <div class="rounded-2xl border border-n-weak bg-n-surface-1 p-6">
          <h3 class="mb-4 flex items-center gap-2 text-lg font-medium text-n-slate-12">
            <i class="i-lucide-layers text-n-blue-11" />
            Desempenho por Estágio
          </h3>
          
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead class="border-b border-n-weak bg-n-slate-2/80">
                <tr>
                  <th class="p-3 text-left text-xs font-medium uppercase text-n-slate-10">Estágio</th>
                  <th class="p-3 text-center text-xs font-medium uppercase text-n-slate-10">Quantidade</th>
                  <th class="p-3 text-right text-xs font-medium uppercase text-n-slate-10">Valor Total</th>
                  <th class="p-3 text-right text-xs font-medium uppercase text-n-slate-10">Valor Médio</th>
                  <th class="p-3 text-center text-xs font-medium uppercase text-n-slate-10">% do Total</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="stage in stageMetrics" :key="stage.id" class="border-b border-n-weak/70 hover:bg-n-slate-2/40">
                  <td class="p-3">
                    <div class="flex items-center gap-2">
                      <div class="w-3 h-3 rounded-full" :style="{ backgroundColor: stage.color }" />
                      <span class="font-medium text-n-slate-12">{{ stage.name }}</span>
                    </div>
                  </td>
                  <td class="p-3 text-center font-semibold">{{ stage.count }}</td>
                  <td class="p-3 text-right font-medium text-n-teal-11">{{ formatCurrency(stage.totalValue) }}</td>
                  <td class="p-3 text-right text-n-slate-11">{{ formatCurrency(stage.avgValue) }}</td>
                  <td class="p-3 text-center">
                    <span class="inline-block rounded-lg bg-n-brand/10 px-2 py-1 text-xs font-medium text-n-blue-11">
                      {{ ((stage.count / boardConversations.length) * 100).toFixed(1) }}%
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div class="rounded-2xl border border-n-weak bg-n-surface-1 p-6">
          <h3 class="mb-4 flex items-center gap-2 text-lg font-medium text-n-slate-12">
            <i class="i-lucide-user-circle text-n-blue-11" />
            Desempenho por Agente
          </h3>
          
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <div
              v-for="metric in agentMetrics"
              :key="metric.agent.id"
              class="rounded-2xl border border-n-weak p-4 transition-colors hover:bg-n-slate-2/40"
            >
              <div class="flex items-center gap-3 mb-3">
                <img
                  v-if="metric.agent.thumbnail"
                  :src="metric.agent.thumbnail"
                  :alt="metric.agent.name"
                  class="h-10 w-10 rounded-full border border-n-weak object-cover"
                />
                <div class="flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-full bg-n-brand/10 font-medium text-n-blue-11" v-else>
                  {{ metric.agent.name.charAt(0).toUpperCase() }}
                </div>
                <div class="flex-1 min-w-0">
                  <p class="truncate font-medium text-n-slate-12">{{ metric.agent.name }}</p>
                  <p class="text-xs text-n-slate-10">{{ metric.count }} tarefa(s)</p>
                </div>
              </div>
              
              <div class="space-y-2">
                <div class="flex items-center justify-between text-sm">
                  <span class="text-n-slate-10">Valor Total:</span>
                  <span class="font-medium text-n-teal-11">{{ formatCurrency(metric.totalValue) }}</span>
                </div>
                <div class="flex items-center justify-between text-sm">
                  <span class="text-n-slate-10">Ticket Médio:</span>
                  <span class="font-medium text-n-slate-12">{{ formatCurrency(metric.avgValue) }}</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
