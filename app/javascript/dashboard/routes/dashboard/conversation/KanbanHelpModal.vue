<script setup>
import Modal from 'dashboard/components/Modal.vue';

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
    <div class="flex flex-col h-full max-h-[90vh] w-full max-w-4xl bg-white rounded-xl shadow-2xl overflow-hidden">
      <!-- Header -->
      <div class="flex items-center justify-between p-6 border-b border-slate-100 bg-slate-50/50">
        <div>
          <h2 class="text-2xl font-bold text-slate-800 flex items-center gap-2">
            <i class="i-lucide-book-open text-blue-600" />
            Guia Prático de Uso do Kanban
          </h2>
          <p class="text-sm text-slate-500 mt-1">
            Exemplos reais para organizar seu fluxo de trabalho
          </p>
        </div>
        <button 
          @click="emit('close')"
          class="p-2 hover:bg-slate-200 rounded-full transition-colors text-slate-500"
        >
          <i class="i-lucide-x text-xl" />
        </button>
      </div>

      <!-- Content -->
      <div class="flex-1 overflow-y-auto p-8 space-y-8 custom-scrollbar">
        
        <!-- Intro -->
        <div class="bg-blue-50 p-6 rounded-xl border border-blue-100">
          <h3 class="text-lg font-semibold text-blue-900 mb-2">O que é o Kanban?</h3>
          <p class="text-blue-800 leading-relaxed">
            O Kanban é um método visual para gerenciar o trabalho. Imagine um quadro com colunas onde cada coluna representa uma etapa do seu processo. Os "cartões" (seus clientes) movem-se da esquerda para a direita à medida que progridem.
          </p>
        </div>

        <!-- Examples Grid -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          
          <!-- Example 1 -->
          <div class="border border-slate-200 rounded-xl p-6 hover:shadow-md transition-shadow">
            <div class="flex items-center gap-3 mb-4">
              <div class="p-2 bg-green-100 text-green-600 rounded-lg">
                <i class="i-lucide-shield-check text-xl" />
              </div>
              <h4 class="text-lg font-bold text-slate-800">Certificado Digital</h4>
            </div>
            <ul class="space-y-2">
              <li class="flex items-center gap-2 text-sm text-slate-600">
                <span class="w-6 h-6 flex items-center justify-center bg-slate-100 rounded-full text-xs font-bold">1</span>
                Novos Leads
              </li>
              <li class="flex items-center gap-2 text-sm text-slate-600">
                <span class="w-6 h-6 flex items-center justify-center bg-slate-100 rounded-full text-xs font-bold">2</span>
                Em Contato
              </li>
              <li class="flex items-center gap-2 text-sm text-slate-600">
                <span class="w-6 h-6 flex items-center justify-center bg-slate-100 rounded-full text-xs font-bold">3</span>
                Aguardando Documentos
              </li>
              <li class="flex items-center gap-2 text-sm text-slate-600">
                <span class="w-6 h-6 flex items-center justify-center bg-slate-100 rounded-full text-xs font-bold">4</span>
                Validação Agendada
              </li>
              <li class="flex items-center gap-2 text-sm text-slate-600">
                <span class="w-6 h-6 flex items-center justify-center bg-slate-100 rounded-full text-xs font-bold">5</span>
                Concluído
              </li>
            </ul>
          </div>

          <!-- Example 2 -->
          <div class="border border-slate-200 rounded-xl p-6 hover:shadow-md transition-shadow">
            <div class="flex items-center gap-3 mb-4">
              <div class="p-2 bg-yellow-100 text-yellow-600 rounded-lg">
                <i class="i-lucide-sun text-xl" />
              </div>
              <h4 class="text-lg font-bold text-slate-800">Energia Solar</h4>
            </div>
            <ul class="space-y-2">
              <li class="flex items-center gap-2 text-sm text-slate-600">
                <span class="w-6 h-6 flex items-center justify-center bg-slate-100 rounded-full text-xs font-bold">1</span>
                Interessados (Leads)
              </li>
              <li class="flex items-center gap-2 text-sm text-slate-600">
                <span class="w-6 h-6 flex items-center justify-center bg-slate-100 rounded-full text-xs font-bold">2</span>
                Visita Técnica
              </li>
              <li class="flex items-center gap-2 text-sm text-slate-600">
                <span class="w-6 h-6 flex items-center justify-center bg-slate-100 rounded-full text-xs font-bold">3</span>
                Proposta Enviada
              </li>
              <li class="flex items-center gap-2 text-sm text-slate-600">
                <span class="w-6 h-6 flex items-center justify-center bg-slate-100 rounded-full text-xs font-bold">4</span>
                Contrato Assinado
              </li>
              <li class="flex items-center gap-2 text-sm text-slate-600">
                <span class="w-6 h-6 flex items-center justify-center bg-slate-100 rounded-full text-xs font-bold">5</span>
                Instalação / Homologação
              </li>
            </ul>
          </div>

          <!-- Example 3 -->
          <div class="border border-slate-200 rounded-xl p-6 hover:shadow-md transition-shadow">
            <div class="flex items-center gap-3 mb-4">
              <div class="p-2 bg-red-100 text-red-600 rounded-lg">
                <i class="i-lucide-heart-pulse text-xl" />
              </div>
              <h4 class="text-lg font-bold text-slate-800">Clínicas Médicas</h4>
            </div>
            <ul class="space-y-2">
              <li class="flex items-center gap-2 text-sm text-slate-600">
                <span class="w-6 h-6 flex items-center justify-center bg-slate-100 rounded-full text-xs font-bold">1</span>
                Solicitação de Agendamento
              </li>
              <li class="flex items-center gap-2 text-sm text-slate-600">
                <span class="w-6 h-6 flex items-center justify-center bg-slate-100 rounded-full text-xs font-bold">2</span>
                Confirmados
              </li>
              <li class="flex items-center gap-2 text-sm text-slate-600">
                <span class="w-6 h-6 flex items-center justify-center bg-slate-100 rounded-full text-xs font-bold">3</span>
                Em Atendimento
              </li>
              <li class="flex items-center gap-2 text-sm text-slate-600">
                <span class="w-6 h-6 flex items-center justify-center bg-slate-100 rounded-full text-xs font-bold">4</span>
                Exames Solicitados
              </li>
              <li class="flex items-center gap-2 text-sm text-slate-600">
                <span class="w-6 h-6 flex items-center justify-center bg-slate-100 rounded-full text-xs font-bold">5</span>
                Retorno / Alta
              </li>
            </ul>
          </div>

          <!-- Example 4 -->
          <div class="border border-slate-200 rounded-xl p-6 hover:shadow-md transition-shadow">
            <div class="flex items-center gap-3 mb-4">
              <div class="p-2 bg-purple-100 text-purple-600 rounded-lg">
                <i class="i-lucide-umbrella text-xl" />
              </div>
              <h4 class="text-lg font-bold text-slate-800">Corretora de Seguros</h4>
            </div>
            <ul class="space-y-2">
              <li class="flex items-center gap-2 text-sm text-slate-600">
                <span class="w-6 h-6 flex items-center justify-center bg-slate-100 rounded-full text-xs font-bold">1</span>
                Cotação Solicitada
              </li>
              <li class="flex items-center gap-2 text-sm text-slate-600">
                <span class="w-6 h-6 flex items-center justify-center bg-slate-100 rounded-full text-xs font-bold">2</span>
                Coletando Dados
              </li>
              <li class="flex items-center gap-2 text-sm text-slate-600">
                <span class="w-6 h-6 flex items-center justify-center bg-slate-100 rounded-full text-xs font-bold">3</span>
                Cotações Enviadas
              </li>
              <li class="flex items-center gap-2 text-sm text-slate-600">
                <span class="w-6 h-6 flex items-center justify-center bg-slate-100 rounded-full text-xs font-bold">4</span>
                Proposta Transmitida
              </li>
              <li class="flex items-center gap-2 text-sm text-slate-600">
                <span class="w-6 h-6 flex items-center justify-center bg-slate-100 rounded-full text-xs font-bold">5</span>
                Apólice Emitida
              </li>
            </ul>
          </div>

        </div>

        <!-- Footer Tips -->
        <div class="bg-slate-50 p-6 rounded-xl border border-slate-200">
          <h4 class="font-bold text-slate-800 mb-3 flex items-center gap-2">
            <i class="i-lucide-lightbulb text-yellow-500" />
            Dicas de Ouro
          </h4>
          <ul class="list-disc list-inside space-y-2 text-sm text-slate-600">
            <li><strong>Limite o Trabalho:</strong> Não tente atender 50 clientes de uma vez. Foque em fechar os que já estão abertos.</li>
            <li><strong>Mantenha Atualizado:</strong> O Kanban só funciona se refletir a realidade. Moveu o processo? Mova o cartão.</li>
            <li><strong>Revise Sempre:</strong> Uma vez por semana, olhe para quem está parado há muito tempo.</li>
          </ul>
        </div>

      </div>
      
      <!-- Footer Actions -->
      <div class="p-6 border-t border-slate-100 bg-slate-50/50 flex justify-end">
        <button 
          @click="emit('close')"
          class="px-6 py-2.5 bg-slate-900 text-white rounded-lg font-medium hover:bg-slate-800 transition-colors"
        >
          Entendi, vamos começar!
        </button>
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