# 📊 Guia de Uso - Funil de Vendas (Kanban)

## 🎯 O que é o Kanban?

O Kanban é um quadro visual que permite gerenciar seu pipeline de vendas, movendo conversas entre diferentes estágios do funil:

- **Lead** → Cliente em potencial inicial
- **Qualificado** → Lead validado e interessado
- **Proposta** → Proposta comercial enviada
- **Negociação** → Em discussão de valores/termos
- **Ganho** ✅ → Venda fechada com sucesso
- **Perdido** ❌ → Oportunidade perdida

## ⚙️ Configuração Inicial

### Passo 1: Criar Atributos Personalizados

Primeiro, você precisa criar os atributos personalizados que o Kanban usa:

1. Acesse **Configurações** → **Atributos Personalizados** → **Conversas**
2. Clique em **+ Adicionar Atributo Personalizado**
3. Crie os seguintes atributos:

#### Atributo 1: Estágio de Vendas
- **Nome de Exibição**: `Estágio de Vendas`
- **Chave do Atributo**: `sales_stage`
- **Tipo**: `Lista` (ou `Texto`)
- **Valores** (se escolher Lista):
  - `lead`
  - `qualified`
  - `proposal`
  - `negotiation`
  - `won`
  - `lost`

#### Atributo 2: Valor do Negócio
- **Nome de Exibição**: `Valor do Negócio`
- **Chave do Atributo**: `deal_value`
- **Tipo**: `Número`
- **Descrição**: `Valor em R$ da oportunidade`

#### Atributo 3: Probabilidade de Ganho (Opcional)
- **Nome de Exibição**: `Probabilidade de Ganho`
- **Chave do Atributo**: `win_probability`
- **Tipo**: `Número`
- **Descrição**: `Probabilidade de fechar (0-100)`

### Passo 2: Atribuir Conversas ao Funil

Agora você pode adicionar conversas ao funil de vendas:

#### Opção A: Manualmente pela Conversa

1. Abra uma conversa
2. No painel direito, procure por **Atributos Personalizados**
3. Configure os atributos:
   - **Estágio de Vendas**: Escolha o estágio inicial (ex: `lead`)
   - **Valor do Negócio**: Digite o valor (ex: `5000`)
   - **Probabilidade de Ganho**: Digite a probabilidade (ex: `30`)
4. Clique em **Atualizar**

#### Opção B: Automaticamente via Automações

Você pode criar automações para atribuir conversas automaticamente:

1. Vá em **Configurações** → **Automações**
2. Crie uma nova regra:
   - **Nome**: "Adicionar ao Funil de Vendas"
   - **Evento**: "Conversa Criada" ou "Mensagem Criada"
   - **Condições**:
     - Ex: "Mensagem contém palavra-chave" → "orçamento", "proposta", "preço"
   - **Ações**:
     - "Adicionar atributo personalizado"
     - `sales_stage` = `lead`
     - `deal_value` = `0`

#### Opção C: Em Massa via API

```bash
# Exemplo usando curl
curl -X PATCH "https://seu-chatwoot.com/api/v1/accounts/{account_id}/conversations/{conversation_id}/custom_attributes" \\
  -H "api_access_token: SEU_TOKEN" \\
  -H "Content-Type: application/json" \\
  -d '{
    "custom_attributes": {
      "sales_stage": "lead",
      "deal_value": 5000,
      "win_probability": 30
    }
  }'
```

## 🎨 Usando o Kanban

### Acessando o Kanban

1. No menu lateral, clique em **"Funil de Vendas"** (ícone de Kanban)
2. Você verá 6 colunas representando os estágios

### Movendo Conversas

- **Arrastar e Soltar**: Clique e arraste um card de uma coluna para outra
- Ao soltar, o `sales_stage` será atualizado automaticamente
- A conversa aparecerá no novo estágio instantaneamente

### Filtrando Conversas

Use os filtros no topo:

- **Caixa de Entrada**: Filtre por canal específico (WhatsApp, Email, etc.)
- **Responsável**:
  - **Todos**: Mostra todas as conversas
  - **Eu**: Apenas conversas atribuídas a você
  - **Não atribuído**: Conversas sem responsável

### Visualizando Métricas

Clique no botão **"Mostrar/Ocultar Métricas"** para ver:

- **Total de Negócios**: Quantidade de conversas no funil
- **Valor Total**: Soma de todos os valores
- **Ticket Médio**: Valor médio por negócio
- **Taxa de Conversão**: % de negócios ganhos
- **Previsão**: Valor ponderado pela probabilidade

## 💡 Dicas de Uso

### Limites WIP (Work In Progress)

Algumas colunas têm limites configurados:
- **Qualificado**: Máximo 20 conversas
- **Proposta**: Máximo 15 conversas
- **Negociação**: Máximo 10 conversas

Quando o limite é atingido, aparece um aviso amarelo.

### Boas Práticas

1. **Atualize o valor do negócio**: Sempre que souber o valor real da oportunidade
2. **Use probabilidades realistas**: Ajuda na previsão de vendas
3. **Mova rapidamente**: Não deixe conversas paradas em um estágio
4. **Analise perdidos**: Entenda por que perdeu para melhorar
5. **Celebre ganhos**: Use as métricas para acompanhar seu desempenho

### Personalizando Estágios

Quer mudar os nomes ou adicionar estágios? Edite o arquivo:
`app/javascript/dashboard/routes/dashboard/conversation/KanbanView.vue`

Procure por `salesStages` (linha ~20) e modifique:

```javascript
const salesStages = ref([
  { stage: 'lead', title: 'Lead', color: '#3b82f6', wipLimit: null },
  { stage: 'qualified', title: 'Qualificado', color: '#8b5cf6', wipLimit: 20 },
  // Adicione ou modifique estágios aqui
]);
```

### Personalizando Cores

As cores seguem o Tailwind CSS. Você pode mudar em cada estágio:
- `#3b82f6` - Azul
- `#8b5cf6` - Roxo
- `#f59e0b` - Laranja
- `#ec4899` - Rosa
- `#10b981` - Verde
- `#ef4444` - Vermelho

## 🔧 Solução de Problemas

### "Não vejo nenhuma conversa no Kanban"

**Causa**: As conversas não têm o atributo `sales_stage` configurado.

**Solução**:
1. Verifique se os atributos personalizados foram criados
2. Atribua o `sales_stage` em pelo menos uma conversa
3. Clique em "Atualizar" no Kanban

### "Não consigo arrastar os cards"

**Causa**: Pode ser problema de permissões ou cache do navegador.

**Solução**:
1. Atualize a página (Ctrl+F5)
2. Verifique se você tem permissão para editar conversas
3. Limpe o cache do navegador

### "As métricas estão erradas"

**Causa**: Valores de `deal_value` ou `win_probability` não configurados.

**Solução**:
- Garanta que todas as conversas tenham valores válidos
- `deal_value` deve ser número positivo
- `win_probability` deve estar entre 0 e 100

## 📱 Compatibilidade

- ✅ Desktop (Chrome, Firefox, Safari, Edge)
- ✅ Tablet (modo landscape recomendado)
- ⚠️ Mobile (visualização limitada, use filtros)

## 🆘 Suporte

Dúvidas ou problemas? Abra uma issue no GitHub do projeto!
