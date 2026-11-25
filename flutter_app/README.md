# Centavus — Flutter

Aplicativo financeiro mobile-first em Flutter para Android, iPhone e Web. Esta
é a nova implementação nativa; a versão HTML/Capacitor original permanece em
`../mobile` sem alterações.

## O que funciona

- Login local e perfis separados, com senha derivada por PBKDF2 (não há conta
  em nuvem nem recuperação de senha por e-mail).
- Resumo por competência, lançamentos, pesquisa paginada, receitas, despesas,
  parcelas e recorrências.
- Contas, cartões, faturas, transferências, metas, orçamento, reserva e renda
  fixa; os valores são armazenados em centavos para evitar erros de arredondamento.
- Backup JSON v4, restauração confirmada e importação do backup legado v3.
- Laboratório de desempenho com benchmark CPU equivalente, lista lazy e coleta
  de tempos de frame. As métricas do arquivo `benchmark-vm.json` são do ambiente
  de desenvolvimento, não de um celular.

## Executar

```powershell
cd flutter_app
..\.tooling\flutter\bin\flutter.bat pub get
..\.tooling\flutter\bin\flutter.bat run -d chrome
```

Para abrir o build web já gerado:

```powershell
node tool/serve.mjs
```

Depois acesse `http://127.0.0.1:5180`.

## Validar e gerar

```powershell
..\.tooling\flutter\bin\flutter.bat analyze
..\.tooling\flutter\bin\flutter.bat test
..\.tooling\flutter\bin\flutter.bat build web --release
```

Para Android, instale o Android SDK e um dispositivo/emulador, então use
`flutter build apk --release`. Para iPhone, abra `ios/Runner.xcworkspace` em um
Mac com Xcode e uma conta Apple. A compilação Android/iOS não foi executada
neste computador porque ele não tem Android SDK nem macOS/Xcode.

