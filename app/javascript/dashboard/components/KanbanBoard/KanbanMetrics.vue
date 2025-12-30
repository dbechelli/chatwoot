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
  const wonStage = props.stages.find(s => s.stage === 'won');
  if (!wonStage) return 0;

  const wonConversations = props.conversations.filter(
    conv => conv.custom_attributes?.sales_stage === 'won'
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
    <!-- Total Deals -->
    <div
      class="flex flex-col gap-2 rounded-lg border border-n-slate-6 bg-white p-4"
    >
      <div class="flex items-center gap-2">
        <div class="rounded-lg bg-blue-100 p-2">
          <i class="i-lucide-briefcase text-xl text-blue-600" />
        </div>
        <span class="text-sm font-medium text-n-slate-11">
          {{ t('KANBAN.METRICS.TOTAL_DEALS') }}
        </span>
      </div>
      <span class="text-2xl font-bold text-n-slate-12">
        {{ totalDeals }}
      </span>
    </div>

    <!-- Total Value -->
    <div
      class="flex flex-col gap-2 rounded-lg border border-n-slate-6 bg-white p-4"
    >
      <div class="flex items-center gap-2">
        <div class="rounded-lg bg-green-100 p-2">
          <i class="i-lucide-dollar-sign text-xl text-green-600" />
        </div>
        <span class="text-sm font-medium text-n-slate-11">
          {{ t('KANBAN.METRICS.TOTAL_VALUE') }}
        </span>
      </div>
      <span class="text-2xl font-bold text-green-700">
        {{ formatCurrency(totalValue) }}
      </span>
    </div>

    <!-- Average Deal Value -->
    <div
      class="flex flex-col gap-2 rounded-lg border border-n-slate-6 bg-white p-4"
    >
      <div class="flex items-center gap-2">
        <div class="rounded-lg bg-purple-100 p-2">
          <i class="i-lucide-trending-up text-xl text-purple-600" />
        </div>
        <span class="text-sm font-medium text-n-slate-11">
          {{ t('KANBAN.METRICS.AVG_DEAL_VALUE') }}
        </span>
      </div>
      <span class="text-2xl font-bold text-purple-700">
        {{ formatCurrency(avgDealValue) }}
      </span>
    </div>

    <!-- Conversion Rate -->
    <div
      class="flex flex-col gap-2 rounded-lg border border-n-slate-6 bg-white p-4"
    >
      <div class="flex items-center gap-2">
        <div class="rounded-lg bg-orange-100 p-2">
          <i class="i-lucide-target text-xl text-orange-600" />
        </div>
        <span class="text-sm font-medium text-n-slate-11">
          {{ t('KANBAN.METRICS.CONVERSION_RATE') }}
        </span>
      </div>
      <span class="text-2xl font-bold text-orange-700">
        {{ formatPercentage(conversionRate) }}
      </span>
    </div>

    <!-- Forecast -->
    <div
      class="flex flex-col gap-2 rounded-lg border border-n-slate-6 bg-white p-4"
    >
      <div class="flex items-center gap-2">
        <div class="rounded-lg bg-indigo-100 p-2">
          <i class="i-lucide-chart-line text-xl text-indigo-600" />
        </div>
        <span class="text-sm font-medium text-n-slate-11">
          {{ t('KANBAN.METRICS.FORECAST') }}
        </span>
      </div>
      <span class="text-2xl font-bold text-indigo-700">
        {{ formatCurrency(forecastValue) }}
      </span>
    </div>
  </div>
</template>
