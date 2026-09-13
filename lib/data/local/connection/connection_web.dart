import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart';

QueryExecutor constructDb() {
  return DatabaseConnection.delayed(Future(() async {
    final result = await WasmDatabase.open(
      databaseName: 'aprueba_db',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    if (result.missingFeatures.isNotEmpty) {
      debugPrint('Drift: Usando ${result.chosenImplementation} (faltan funciones web: ${result.missingFeatures})');
    }
    return result.resolvedExecutor;
  }));
}
