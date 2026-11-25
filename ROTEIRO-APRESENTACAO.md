# Centavus — roteiro de apresentação (10 minutos)

## 1. Contexto — 1 minuto

O Centavus é um aplicativo para organizar finanças pessoais em uma interface adaptada ao celular. Ele reúne entradas, saídas, contas, cartões, faturas e metas em um único lugar.

## 2. Tecnologia e arquitetura — 1 minuto e 30 segundos

O aplicativo foi desenvolvido em Flutter e Dart. A interface usa widgets, as regras financeiras ficam separadas das telas e o SQLite armazena os dados localmente. Valores monetários são calculados em centavos para evitar perdas de arredondamento. Login e dados são locais; não existe integração bancária ou sincronização automática em nuvem.

## 3. Demonstração — 2 minutos

Abra a prévia web na moldura de celular. Entre na conta local ou crie uma conta de demonstração. Mostre o resumo do mês e cadastre uma receita e uma despesa. Em Meu dinheiro, mostre contas e cartões. Em Planejar, crie uma meta e escolha sua categoria. Abra Análises para mostrar os dados atualizados.

Prévia local: http://127.0.0.1:5180/mobile-preview.html

## 4. Otimizações — 3 minutos e 30 segundos

1. Extrato paginado e lista sob demanda: o aplicativo busca 50 registros por vez e constrói as linhas conforme necessário.
2. Consultas indexadas por usuário, mês e data: reduzem a quantidade de dados consultados para o mês selecionado.
3. Processamento de backup e benchmark com `compute`: no Android e iOS o trabalho pode ocorrer em outro isolate. Na Web, `compute` não garante paralelismo.

O laboratório de desempenho, em Configurações, contém dois cenários sintéticos de lista: eager e lazy, além da comparação de agregação mensal.

## 5. Resultados medidos — 1 minuto e 30 segundos

No computador de desenvolvimento, o benchmark de agregação usou 50.000 movimentações, 84 meses, uma rodada de aquecimento e sete medições. A mediana foi 591.677 microssegundos no algoritmo de referência e 9.607 microssegundos no algoritmo indexado, aproximadamente 61,6 vezes mais rápido nesse cenário. Os resultados foram equivalentes, com o mesmo checksum.

Esses números medem apenas CPU para agregação em memória no computador. Não representam FPS, memória, tempo de inicialização ou desempenho em um celular. O emulador ainda não iniciou porque a virtualização está desativada no firmware do computador; portanto não há métricas de Android para apresentar.

## 6. Lições e próximos passos — 30 segundos

A principal lição foi medir operações equivalentes e manter os cálculos corretos ao otimizar. O próximo passo é testar em um Android, coletar tempos de frame e memória e repetir as medições em condições iguais.

## Antes de apresentar

- Confirme que a prévia local está aberta e crie dados fictícios para demonstração.
- Não compartilhe informações financeiras pessoais.
- Identifique os resultados como medição em computador, não em celular.
- O arquivo de dados do benchmark é `flutter_app/benchmark-vm.json`.
