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
    <div class="group flex flex-col gap-1 rounded-2xl border border-n-weak bg-n-surface-1 p-4 transition-colors hover:bg-n-slate-2/40">
      <div class="flex items-center justify-between">
        <span class="text-xs font-medium uppercase tracking-wide text-n-slate-10">
          {{ t('KANBAN.METRICS.TOTAL_DEALS') }}
        </span>
        <div class="rounded-xl bg-n-brand/10 p-2 text-n-blue-11 transition-colors group-hover:bg-n-brand/15">
          <i class="i-lucide-briefcase text-lg" />
        </div>
      </div>
      <div class="mt-1">
        <span class="text-2xl font-semibold leading-none text-n-slate-12">
          {{ totalDeals }}
        </span>
        <p class="mt-1 text-[10px] text-n-slate-10">Negociações ativas</p>
      </div>
    </div>

    <div class="group flex flex-col gap-1 rounded-2xl border border-n-weak bg-n-surface-1 p-4 transition-colors hover:bg-n-slate-2/40">
      <div class="flex items-center justify-between">
        <span class="text-xs font-medium uppercase tracking-wide text-n-slate-10">
          {{ t('KANBAN.METRICS.TOTAL_VALUE') }}
        </span>
        <div class="rounded-xl bg-n-teal-3/70 p-2 text-n-teal-11 transition-colors group-hover:bg-n-teal-3">
          <i class="i-lucide-dollar-sign text-lg" />
        </div>
      </div>
      <div class="mt-1">
        <span class="text-2xl font-semibold leading-none text-n-teal-11">
          {{ formatCurrency(totalValue) }}
        </span>
        <p class="mt-1 text-[10px] text-n-slate-10">Volume em carteira</p>
      </div>
    </div>

    <div class="group flex flex-col gap-1 rounded-2xl border border-n-weak bg-n-surface-1 p-4 transition-colors hover:bg-n-slate-2/40">
      <div class="flex items-center justify-between">
        <span class="text-xs font-medium uppercase tracking-wide text-n-slate-10">
          {{ t('KANBAN.METRICS.AVG_DEAL_VALUE') }}
        </span>
        <div class="rounded-xl bg-n-blue-3/70 p-2 text-n-blue-11 transition-colors group-hover:bg-n-blue-3">
          <i class="i-lucide-trending-up text-lg" />
        </div>
      </div>
      <div class="mt-1">
        <span class="text-2xl font-semibold leading-none text-n-blue-11">
          {{ formatCurrency(avgDealValue) }}
        </span>
        <p class="mt-1 text-[10px] text-n-slate-10">Ticket médio atual</p>
      </div>
    </div>

    <div class="group flex flex-col gap-1 rounded-2xl border border-n-weak bg-n-surface-1 p-4 transition-colors hover:bg-n-slate-2/40">
      <div class="flex items-center justify-between">
        <span class="text-xs font-medium uppercase tracking-wide text-n-slate-10">
          {{ t('KANBAN.METRICS.CONVERSION_RATE') }}
        </span>
        <div class="rounded-xl bg-n-amber-3/70 p-2 text-n-amber-11 transition-colors group-hover:bg-n-amber-3">
          <i class="i-lucide-target text-lg" />
        </div>
      </div>
      <div class="mt-1">
        <span class="text-2xl font-semibold leading-none text-n-amber-11">
          {{ formatPercentage(conversionRate) }}
        </span>
        <p class="mt-1 text-[10px] text-n-slate-10">Taxa de conversão</p>
      </div>
    </div>

    <div class="group flex flex-col gap-1 rounded-2xl border border-n-weak bg-n-surface-1 p-4 transition-colors hover:bg-n-slate-2/40">
      <div class="flex items-center justify-between">
        <span class="text-xs font-medium uppercase tracking-wide text-n-slate-10">
          Previsão
        </span>
        <div class="rounded-xl bg-n-slate-3 p-2 text-n-slate-11 transition-colors group-hover:bg-n-slate-4">
          <i class="i-lucide-chart-line text-lg" />
        </div>
      </div>
      <div class="mt-1">
        <span class="text-2xl font-semibold leading-none text-n-slate-12">
          {{ formatCurrency(forecastValue) }}
        </span>
        <p class="mt-1 text-[10px] text-n-slate-10">Expectativa de fechamento</p>
      </div>
    </div>
  </div>
</template>

<style scoped>
.group:hover span {
  transition: transform 0.2s ease;
}
</style>
