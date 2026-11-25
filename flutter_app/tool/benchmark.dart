import 'dart:convert';
import 'package:centavus_flutter/domain/benchmark.dart';

void main(List<String> args) {
  // ignore: avoid_print
  print(
    const JsonEncoder.withIndent(
      '  ',
    ).convert(runBenchmark(args.isEmpty ? 50000 : int.parse(args.first))),
  );
}
