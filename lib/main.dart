import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/storage/secure_storage_bootstrap.dart';
import 'data/local/database.dart';
import 'providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Base de datos local (caché). Se abre una sola vez y se inyecta vía Riverpod.
  final database = AppDatabase();

  // Estado de sesión inicial: ¿hay refresh token guardado?
  final secureStorage = SecureStorageBootstrap();
  final loggedIn = await secureStorage.hasSession();

  // Firebase y Stripe se inicializan de forma perezosa/segura dentro de sus
  // servicios para no bloquear el arranque si faltan claves de configuración.

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        isLoggedInProvider.overrideWith((ref) => loggedIn),
      ],
      child: const ApruebaApp(),
    ),
  );
}
