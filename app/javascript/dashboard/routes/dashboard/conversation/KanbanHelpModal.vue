<script setup>
import Modal from 'dashboard/components/Modal.vue';
import Button from 'dashboard/components-next/button/Button.vue';

defineProps({
  show: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['close']);
</script>

<template>
  <Modal :show="show" :on-close="() => emit('close')">
    <div class="flex h-full max-h-[90vh] w-full max-w-4xl flex-col overflow-hidden rounded-2xl bg-n-surface-1 shadow-2xl">
      <div class="flex items-center justify-between border-b border-n-weak bg-n-slate-2/50 p-6">
        <div>
          <h2 class="flex items-center gap-2 text-2xl font-medium text-n-slate-12">
            <i class="i-lucide-book-open text-n-blue-11" />
            Guia Prático de Uso do Kanban
          </h2>
          <p class="mt-1 text-sm text-n-slate-11">
            Exemplos reais para organizar seu fluxo de trabalho
          </p>
        </div>
        <button 
          @click="emit('close')"
          class="rounded-full p-2 text-n-slate-10 transition-colors hover:bg-n-slate-3"
        >
          <i class="i-lucide-x text-xl" />
        </button>
      </div>

      <div class="custom-scrollbar flex-1 space-y-8 overflow-y-auto p-8">
        
        <div class="rounded-2xl border border-n-brand/20 bg-n-brand/5 p-6">
          <h3 class="mb-2 text-lg font-medium text-n-blue-11">O que é o Kanban?</h3>
          <p class="leading-relaxed text-n-blue-11">
            O Kanban é um método visual para gerenciar o trabalho. Imagine um quadro com colunas onde cada coluna representa uma etapa do seu processo. Os "cartões" (seus clientes) movem-se da esquerda para a direita à medida que progridem.
          </p>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          
          <!-- Example 1 -->
          <div class="rounded-2xl border border-n-weak bg-n-surface-1 p-6 transition-colors hover:bg-n-slate-2/40">
            <div class="flex items-center gap-3 mb-4">
              <div class="rounded-xl bg-n-teal-3 px-2 py-2 text-n-teal-11">
                <i class="i-lucide-shield-check text-xl" />
              </div>
              <h4 class="text-lg font-medium text-n-slate-12">Certificado Digital</h4>
            </div>
            <ul class="space-y-2">
              <li class="flex items-center gap-2 text-sm text-n-slate-11">
                <span class="flex h-6 w-6 items-center justify-center rounded-full bg-n-slate-2 text-xs font-medium text-n-slate-12">1</span>
                Novos Leads
              </li>
              <li class="flex items-center gap-2 text-sm text-n-slate-11">
                <span class="flex h-6 w-6 items-center justify-center rounded-full bg-n-slate-2 text-xs font-medium text-n-slate-12">2</span>
                Em Contato
              </li>
              <li class="flex items-center gap-2 text-sm text-n-slate-11">
                <span class="flex h-6 w-6 items-center justify-center rounded-full bg-n-slate-2 text-xs font-medium text-n-slate-12">3</span>
                Aguardando Documentos
              </li>
              <li class="flex items-center gap-2 text-sm text-n-slate-11">
                <span class="flex h-6 w-6 items-center justify-center rounded-full bg-n-slate-2 text-xs font-medium text-n-slate-12">4</span>
                Validação Agendada
              </li>
              <li class="flex items-center gap-2 text-sm text-n-slate-11">
                <span class="flex h-6 w-6 items-center justify-center rounded-full bg-n-slate-2 text-xs font-medium text-n-slate-12">5</span>
                Concluído
              </li>
            </ul>
          </div>

          <!-- Example 2 -->
          <div class="rounded-2xl border border-n-weak bg-n-surface-1 p-6 transition-colors hover:bg-n-slate-2/40">
            <div class="flex items-center gap-3 mb-4">
              <div class="rounded-xl bg-n-amber-3 px-2 py-2 text-n-amber-11">
                <i class="i-lucide-sun text-xl" />
              </div>
              <h4 class="text-lg font-medium text-n-slate-12">Energia Solar</h4>
            </div>
            <ul class="space-y-2 text-n-slate-11">
              <li class="flex items-center gap-2 text-sm">
                <span class="flex h-6 w-6 items-center justify-center rounded-full bg-n-slate-2 text-xs font-medium text-n-slate-12">1</span>
                Interessados (Leads)
              </li>
              <li class="flex items-center gap-2 text-sm">
                <span class="flex h-6 w-6 items-center justify-center rounded-full bg-n-slate-2 text-xs font-medium text-n-slate-12">2</span>
                Visita Técnica
              </li>
              <li class="flex items-center gap-2 text-sm">
                <span class="flex h-6 w-6 items-center justify-center rounded-full bg-n-slate-2 text-xs font-medium text-n-slate-12">3</span>
                Proposta Enviada
              </li>
              <li class="flex items-center gap-2 text-sm">
                <span class="flex h-6 w-6 items-center justify-center rounded-full bg-n-slate-2 text-xs font-medium text-n-slate-12">4</span>
                Contrato Assinado
              </li>
              <li class="flex items-center gap-2 text-sm">
                <span class="flex h-6 w-6 items-center justify-center rounded-full bg-n-slate-2 text-xs font-medium text-n-slate-12">5</span>
                Instalação / Homologação
              </li>
            </ul>
          </div>

          <!-- Example 3 -->
          <div class="rounded-2xl border border-n-weak bg-n-surface-1 p-6 transition-colors hover:bg-n-slate-2/40">
            <div class="flex items-center gap-3 mb-4">
              <div class="rounded-xl bg-n-ruby-3 px-2 py-2 text-n-ruby-11">
                <i class="i-lucide-heart-pulse text-xl" />
              </div>
              <h4 class="text-lg font-medium text-n-slate-12">Clínicas Médicas</h4>
            </div>
            <ul class="space-y-2 text-n-slate-11">
              <li class="flex items-center gap-2 text-sm">
                <span class="flex h-6 w-6 items-center justify-center rounded-full bg-n-slate-2 text-xs font-medium text-n-slate-12">1</span>
                Solicitação de Agendamento
              </li>
              <li class="flex items-center gap-2 text-sm">
                <span class="flex h-6 w-6 items-center justify-center rounded-full bg-n-slate-2 text-xs font-medium text-n-slate-12">2</span>
                Confirmados
              </li>
              <li class="flex items-center gap-2 text-sm">
                <span class="flex h-6 w-6 items-center justify-center rounded-full bg-n-slate-2 text-xs font-medium text-n-slate-12">3</span>
                Em Atendimento
              </li>
              <li class="flex items-center gap-2 text-sm">
                <span class="flex h-6 w-6 items-center justify-center rounded-full bg-n-slate-2 text-xs font-medium text-n-slate-12">4</span>
                Exames Solicitados
              </li>
              <li class="flex items-center gap-2 text-sm">
                <span class="flex h-6 w-6 items-center justify-center rounded-full bg-n-slate-2 text-xs font-medium text-n-slate-12">5</span>
                Retorno / Alta
              </li>
            </ul>
          </div>

          <!-- Example 4 -->
          <div class="rounded-2xl border border-n-weak bg-n-surface-1 p-6 transition-colors hover:bg-n-slate-2/40">
            <div class="flex items-center gap-3 mb-4">
              <div class="rounded-xl bg-n-blue-3 px-2 py-2 text-n-blue-11">
                <i class="i-lucide-umbrella text-xl" />
              </div>
              <h4 class="text-lg font-medium text-n-slate-12">Corretora de Seguros</h4>
            </div>
            <ul class="space-y-2 text-n-slate-11">
              <li class="flex items-center gap-2 text-sm">
                <span class="flex h-6 w-6 items-center justify-center rounded-full bg-n-slate-2 text-xs font-medium text-n-slate-12">1</span>
                Cotação Solicitada
              </li>
              <li class="flex items-center gap-2 text-sm">
                <span class="flex h-6 w-6 items-center justify-center rounded-full bg-n-slate-2 text-xs font-medium text-n-slate-12">2</span>
                Coletando Dados
              </li>
              <li class="flex items-center gap-2 text-sm">
                <span class="flex h-6 w-6 items-center justify-center rounded-full bg-n-slate-2 text-xs font-medium text-n-slate-12">3</span>
                Cotações Enviadas
              </li>
              <li class="flex items-center gap-2 text-sm">
                <span class="flex h-6 w-6 items-center justify-center rounded-full bg-n-slate-2 text-xs font-medium text-n-slate-12">4</span>
                Proposta Transmitida
              </li>
              <li class="flex items-center gap-2 text-sm">
                <span class="flex h-6 w-6 items-center justify-center rounded-full bg-n-slate-2 text-xs font-medium text-n-slate-12">5</span>
                Apólice Emitida
              </li>
            </ul>
          </div>

        </div>

        <div class="rounded-2xl border border-n-weak bg-n-slate-2/70 p-6">
          <h4 class="mb-3 flex items-center gap-2 font-medium text-n-slate-12">
            <i class="i-lucide-lightbulb text-n-amber-11" />
            Dicas de Ouro
          </h4>
          <ul class="list-inside list-disc space-y-2 text-sm text-n-slate-11">
            <li><strong>Limite o Trabalho:</strong> Não tente atender 50 clientes de uma vez. Foque em fechar os que já estão abertos.</li>
            <li><strong>Mantenha Atualizado:</strong> O Kanban só funciona se refletir a realidade. Moveu o processo? Mova o cartão.</li>
            <li><strong>Revise Sempre:</strong> Uma vez por semana, olhe para quem está parado há muito tempo.</li>
          </ul>
        </div>

      </div>
      
      <div class="flex justify-end border-t border-n-weak bg-n-slate-2/50 p-6">
        <Button @click="emit('close')" slate solid label="Entendi, vamos começar!" />
      </div>
    </div>
  </Modal>
</template>

<style scoped>
.custom-scrollbar::-webkit-scrollbar {
  width: 8px;
}
.custom-scrollbar::-webkit-scrollbar-track {
  background: transparent;
}
.custom-scrollbar::-webkit-scrollbar-thumb {
  background-color: #cbd5e1;
  border-radius: 20px;
  border: 3px solid transparent;
  background-clip: content-box;
}
.custom-scrollbar::-webkit-scrollbar-thumb:hover {
  background-color: #94a3b8;
}
</style>