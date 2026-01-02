<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  conversations: { type: Array, required: true },
  stages: { type: Array, required: true },
});

const { t } = useI18n();

const totalDeals = computed(() => props.conversations.length);

const totalValue = computed(() => {
  return props.conversations.reduce((sum, conv) => {
    return sum + (conv.custom_attributes?.deal_value || 0);
  }, 0);
});

const avgDealValue = computed(() => {
  return totalDeals.value > 0 ? totalValue.value / totalDeals.value : 0;
});

const conversionRate = computed(() => {
  // Ajustado para refletir sua nova chave 'paciente_ativo' (antigo 'won')
  const wonStage = props.stages.find(s => s.stage === 'paciente_ativo' || s.stage === 'won');
  if (!wonStage) return 0;

  const wonConversations = props.conversations.filter(
    conv => conv.custom_attributes?.sales_stage === wonStage.stage
  );

  return totalDeals.value > 0
    ? (wonConversations.length / totalDeals.value) * 100
    : 0;
});

const forecastValue = computed(() => {
  return props.conversations.reduce((sum, conv) => {
    const dealValue = conv.custom_attributes?.deal_value || 0;
    const probability = conv.custom_attributes?.win_probability || 0;
    return sum + (dealValue * probability) / 100;
  }, 0);
});

const formatCurrency = value => {
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
    minimumFractionDigits: 0,
  }).format(value);
};

const formatPercentage = value => {
  return `${value.toFixed(1)}%`;
};
</script>

<template>
  <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-5">
    <div class="group flex flex-col gap-1 rounded-xl border border-slate-200 bg-white p-4 shadow-sm transition-all hover:shadow-md">
      <div class="flex items-center justify-between">
        <span class="text-xs font-bold uppercase tracking-wider text-slate-500">
          {{ t('KANBAN.METRICS.TOTAL_DEALS') }}
        </span>
        <div class="rounded-lg bg-blue-50 p-2 text-blue-600 group-hover:bg-blue-600 group-hover:text-white transition-colors">
          <i class="i-lucide-briefcase text-lg" />
        </div>
      </div>
      <div class="mt-1">
        <span class="text-2xl font-black text-slate-900 leading-none">
          {{ totalDeals }}
        </span>
        <p class="text-[10px] text-slate-400 mt-1">Negociações ativas</p>
      </div>
    </div>

    <div class="group flex flex-col gap-1 rounded-xl border border-slate-200 bg-white p-4 shadow-sm transition-all hover:shadow-md">
      <div class="flex items-center justify-between">
        <span class="text-xs font-bold uppercase tracking-wider text-slate-500">
          {{ t('KANBAN.METRICS.TOTAL_VALUE') }}
        </span>
        <div class="rounded-lg bg-emerald-50 p-2 text-emerald-600 group-hover:bg-emerald-600 group-hover:text-white transition-colors">
          <i class="i-lucide-dollar-sign text-lg" />
        </div>
      </div>
      <div class="mt-1">
        <span class="text-2xl font-black text-emerald-600 leading-none">
          {{ formatCurrency(totalValue) }}
        </span>
        <p class="text-[10px] text-slate-400 mt-1">Volume em carteira</p>
      </div>
    </div>

    <div class="group flex flex-col gap-1 rounded-xl border border-slate-200 bg-white p-4 shadow-sm transition-all hover:shadow-md">
      <div class="flex items-center justify-between">
        <span class="text-xs font-bold uppercase tracking-wider text-slate-500">
          {{ t('KANBAN.METRICS.AVG_DEAL_VALUE') }}
        </span>
        <div class="rounded-lg bg-purple-50 p-2 text-purple-600 group-hover:bg-purple-600 group-hover:text-white transition-colors">
          <i class="i-lucide-trending-up text-lg" />
        </div>
      </div>
      <div class="mt-1">
        <span class="text-2xl font-black text-purple-700 leading-none">
          {{ formatCurrency(avgDealValue) }}
        </span>
        <p class="text-[10px] text-slate-400 mt-1">Ticket médio atual</p>
      </div>
    </div>

    <div class="group flex flex-col gap-1 rounded-xl border border-slate-200 bg-white p-4 shadow-sm transition-all hover:shadow-md">
      <div class="flex items-center justify-between">
        <span class="text-xs font-bold uppercase tracking-wider text-slate-500">
          {{ t('KANBAN.METRICS.CONVERSION_RATE') }}
        </span>
        <div class="rounded-lg bg-orange-50 p-2 text-orange-600 group-hover:bg-orange-600 group-hover:text-white transition-colors">
          <i class="i-lucide-target text-lg" />
        </div>
      </div>
      <div class="mt-1">
        <span class="text-2xl font-black text-orange-700 leading-none">
          {{ formatPercentage(conversionRate) }}
        </span>
        <p class="text-[10px] text-slate-400 mt-1">Taxa de conversão</p>
      </div>
    </div>

    <div class="group flex flex-col gap-1 rounded-xl border border-slate-200 bg-white p-4 shadow-sm transition-all hover:shadow-md">
      <div class="flex items-center justify-between">
        <span class="text-xs font-bold uppercase tracking-wider text-slate-500">
          Previsão
        </span>
        <div class="rounded-lg bg-indigo-50 p-2 text-indigo-600 group-hover:bg-indigo-600 group-hover:text-white transition-colors">
          <i class="i-lucide-chart-line text-lg" />
        </div>
      </div>
      <div class="mt-1">
        <span class="text-2xl font-black text-indigo-700 leading-none">
          {{ formatCurrency(forecastValue) }}
        </span>
        <p class="text-[10px] text-slate-400 mt-1">Expectativa de fechamento</p>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* Efeito de destaque nos números ao passar o mouse */
.group:hover span {
  transition: transform 0.2s ease;
}
</style>
