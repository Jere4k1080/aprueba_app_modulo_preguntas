import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'data/local/database.dart';
import 'firebase_options.dart';
import 'providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Base de datos local (caché). Se abre una sola vez y se inyecta vía Riverpod.
  final database = AppDatabase();

  // La sesión es la de Firebase Auth. El primer evento de authStateChanges
  // llega cuando Firebase terminó de restaurar la sesión guardada.
  // Si Firebase no carga (en web, sin acceso a gstatic.com; en escritorio, sin
  // opciones) la app arranca sin sesión en vez de quedar en blanco.
  var loggedIn = false;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
        .timeout(const Duration(seconds: 10));
    loggedIn = await FirebaseAuth.instance
            .authStateChanges()
            .first
            .timeout(const Duration(seconds: 5)) !=
        null;
  } catch (e) {
    debugPrint('Firebase no disponible: $e');
  }

  // Stripe se inicializa de forma perezosa dentro de su servicio.

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
