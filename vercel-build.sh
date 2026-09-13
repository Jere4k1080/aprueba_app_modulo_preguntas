#!/usr/bin/env bash
# Compilación de la app Flutter Web en Vercel.
#
# Vercel no incluye el SDK de Flutter ni reconoce proyectos Dart, así que el SDK
# se clona aquí. El límite de 256 caracteres del campo buildCommand en
# vercel.json es la razón por la que esta lógica vive en un script aparte.

set -euo pipefail

FLUTTER_CHANNEL="stable"
FLUTTER_DIR="$PWD/flutter"

echo "──> 1/4 · Obteniendo el SDK de Flutter ($FLUTTER_CHANNEL)"
if [ ! -d "$FLUTTER_DIR" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b "$FLUTTER_CHANNEL" "$FLUTTER_DIR"
else
  echo "    El SDK ya estaba en la caché de compilación."
fi

export PATH="$FLUTTER_DIR/bin:$PATH"
flutter --version

echo "──> 2/4 · Resolviendo dependencias"
flutter pub get

echo "──> 3/4 · Generando código (Drift)"
# database.g.dart no se versiona: lo genera build_runner. Sin este paso la
# compilación falla por símbolos inexistentes.
dart run build_runner build --delete-conflicting-outputs

echo "──> 4/4 · Compilando para web"
if [ -z "${API_BASE_URL:-}" ]; then
  echo "    AVISO: API_BASE_URL no está definida. La app compilará, pero usará"
  echo "    el valor por defecto del código y no alcanzará el backend."
fi

flutter build web --release --dart-define=API_BASE_URL="${API_BASE_URL:-}"

echo "──> Listo. Artefacto en build/web"
