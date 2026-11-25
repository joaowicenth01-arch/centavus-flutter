# Migração do Centavus para Flutter

## Objetivo
Reescrever o aplicativo existente em Flutter e Dart para Android e iPhone, preservando o visual mobile verde, a navegação simples e os cálculos financeiros. A versão HTML/Capacitor permanece disponível em mobile/.

## Abordagem
A única abordagem compatível com a migração solicitada é uma interface Flutter real com regras financeiras em Dart. Um WebView manteria o aplicativo HTML existente e não realizaria a reescrita. Redesenhar o produto do zero perderia comportamentos que o usuário já definiu.

## Escopo
- Projeto independente em flutter_app/, com destinos Android, iOS e Web para conferência.
- Login e cadastro local, sessão e dados separados por usuário, equivalentes ao modo local atual. Não apresentar autenticação local como serviço de autenticação remoto.
- Movimentação do mês com saldo consolidado, entradas e saídas; seleção de mês e extrato.
- Cadastro, edição e exclusão de receitas e despesas, incluindo parcelas e cálculo em centavos.
- Contas, cartões e faturas com fechamento, vencimento, limite e pagamentos.
- Planejamento com metas, limites, reserva e análises derivadas dos dados.
- Seções expansíveis, inclusive contas e faturas, com preferência persistida.
- Persistência local, backup e restauração com validação. Não ler nem transferir silenciosamente os dados do navegador; oferecer importação explícita dos backups compatíveis.

## Arquitetura proposta
Widgets Material 3 com tema Centavus, camadas separadas para modelos, cálculos, persistência e telas. Datas de competência e vencimento explícitas. Valores monetários inteiros em centavos e distribuição de parcelas sem perda de centavos. Persistir antes de comunicar sucesso; apresentar erros recuperáveis na interface.

## Limites e compatibilidade
Nenhum backend remoto ou integração bancária é presumido. Voz e assistente atuais precisam ser inventariados; funções dependentes de serviços externos só serão declaradas disponíveis quando integradas e verificadas. Figma não executa diretamente um projeto Flutter: a versão Flutter será conferida como aplicativo ou Flutter Web; o arquivo Figma existente permanece uma apresentação separada.

O SDK Flutter não foi encontrado no PATH na inspeção inicial. Será necessário localizar ou preparar o SDK para análise, testes e compilação. APK depende das ferramentas Android; distribuição iOS depende de macOS, Xcode e assinatura.

## Verificação
Testes de saldo por mês, competência, distribuição de parcelas, faturas e persistência; testes de interface de cadastro de movimentação e expansão de seções; análise estática e build Web. Compilação Android/iOS somente quando os respectivos ambientes estiverem disponíveis. Registrar funções migradas, pendências e verificações executadas, sem chamar uma migração parcial de completa.

## Decisões propostas pelo implementador
Material 3, dinheiro em centavos, projeto separado e modo local inicial. Preservar dados e versão antiga. A migração não inclui publicar em lojas nem substituir o arquivo Figma por código Flutter.

## Requisitos da disciplina (PDF fornecido em 24/11/2026)
O PDF pede demonstração funcional e, como parte central da avaliação, duas ou três otimizações realmente aplicadas, além de comparação antes/depois com resultados reais de profiling. Não exige Flutter especificamente: Flutter é a escolha solicitada pelo usuário.

Adicionar ao projeto:
- Listas construídas sob demanda (ListView.builder) para extratos extensos.
- Agregação mensal e processamento de backups grandes fora do isolate de interface quando apropriado, com benchmark de referência equivalente.
- Persistência local e consultas por competência, evitando carregar todo o histórico para renderizar uma tela.
- Cenário reproduzível com dados sintéticos, baseline e versão otimizada; coletar duração de processamento e tempos de frames em modo profile no mesmo dispositivo, documentando ambiente e limites. Nunca inventar números de RAM, FPS ou cold start.
- Separar regras de negócio, persistência e widgets; descartar controllers, listeners e subscriptions corretamente.

## Revisão do escopo
Inventariar também transferências entre contas, renda fixa, cofrinho, configurações, exportações e assistente. Importação usa o formato de backup realmente produzido pelo app atual; substituição de dados exige confirmação na interface. Reproduzir as regras de competência e fechamento existentes após leitura do JavaScript. Login local usa derivação de senha com salt e armazenamento adequado, sem alegação de segurança de servidor. A conclusão exige checklist de paridade; compilação e distribuição por plataforma ficam registradas separadamente.
