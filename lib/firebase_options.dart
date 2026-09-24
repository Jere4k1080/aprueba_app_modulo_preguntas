// Formato de FlutterFire CLI, escrito a mano a partir de los archivos de
// configuración de la consola de Firebase. `flutterfire configure` lo reemplaza.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
///
/// Estos valores identifican el proyecto aprueba-app-modulo-preguntas ante
/// Firebase y viajan dentro de cualquier build de la app, así que no son
/// secretos. El acceso a los datos lo controlan firestore.rules y el backend.
/// La cuenta de servicio del backend sí es secreta y nunca va en este archivo.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDivYIliC9EIPHGfaNRBKYj90gHnu-Odmc',
    appId: '1:1073481331997:web:a2f8c3778cef76717dddf4',
    messagingSenderId: '1073481331997',
    projectId: 'aprueba-app-modulo-preguntas',
    authDomain: 'aprueba-app-modulo-preguntas.firebaseapp.com',
    databaseURL: 'https://aprueba-app-modulo-preguntas-default-rtdb.firebaseio.com',
    storageBucket: 'aprueba-app-modulo-preguntas.firebasestorage.app',
    measurementId: 'G-Y348LDW9SD',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDbjs4GmER4lgt-BHSHiQ0YC2R5k6CCwKY',
    appId: '1:1073481331997:android:7507404966c5cd997dddf4',
    messagingSenderId: '1073481331997',
    projectId: 'aprueba-app-modulo-preguntas',
    databaseURL: 'https://aprueba-app-modulo-preguntas-default-rtdb.firebaseio.com',
    storageBucket: 'aprueba-app-modulo-preguntas.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAWT36hUQPDFRm2NROShN9rVCGG5DhFEzM',
    appId: '1:1073481331997:ios:532b60a907cf5d397dddf4',
    messagingSenderId: '1073481331997',
    projectId: 'aprueba-app-modulo-preguntas',
    databaseURL: 'https://aprueba-app-modulo-preguntas-default-rtdb.firebaseio.com',
    storageBucket: 'aprueba-app-modulo-preguntas.firebasestorage.app',
    iosBundleId: 'cl.aprueba.apruebaApp',
  );
}
