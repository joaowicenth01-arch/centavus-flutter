# Centavus Flutter Implementation Plan

**Goal:** Migrar o aplicativo para widgets Flutter e regras Dart, mantendo a versão anterior.
**Architecture:** Material 3; domínio puro em centavos; repositório SQLite consultado por mês; controller observável; telas por área.
**Tech Stack:** Flutter stable, Dart, sqflite_common_ffi/web, cryptography, shared_preferences, file_picker, share_plus.
**Spec:** docs/superpowers/specs/2026-11-24-centavus-flutter-design.md

## Constraints
Android/iOS/Web; sem backend presumido; valores inteiros; dados isolados por usuário; confirmação antes de restaurar; não fabricar métricas; paridade explícita.

## Review focus
Parcelas atravessando anos; datas no fim do mês; pagamentos de fatura sem despesa duplicada; falha de persistência; backup legado inválido.

## Tasks
- [x] 1. Preparar SDK oficial e projeto separado flutter_app, inventariar compatibilidade e ferramentas.
- [x] 2. Testar e implementar domínio: dinheiro, parcelas, competência, fatura e transferências.
- [x] 3. Testar e implementar SQLite, autenticação local com PBKDF2, isolamento, backup legado v3 e novo v4.
- [x] 4. Implementar login, resumo, extrato lazy, editor de movimentações, contas/cartões/faturas, planejamento/análises/configurações e controles expansíveis. Testar principais fluxos.
- [x] 5. Implementar benchmark equivalente baseline/indexação, importação em isolate e monitor de frames.
- [x] 6. Analisar, testar, compilar Web, conferir visual; revisar e empacotar fonte sem SDK/caches; registrar limites Android/iOS.

## Progress ledger
24/11: plano aprovado; execução inline. Ruling: usar pasta flutter_app como isolamento de produto autorizado, sem tocar no HTML/Capacitor nem criar worktree que excluiria arquivos mobile não rastreados. SDK em .tooling/flutter (não distribuir).

24/11: revisão final corrigiu três riscos: recorrências legadas respeitam `proxIso` para não duplicar cópias históricas; cartões legados iniciam no próximo vencimento; saldo inicial negativo é aceito para contas. `flutter analyze` sem problemas e 18 testes passaram. Web release recompilado. Android/iOS continuam exigindo seus ambientes nativos.
