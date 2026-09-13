#!/usr/bin/env python3
"""Verificacion estatica del cliente Flutter (no hay Dart SDK en el sandbox).

Comprueba:
  1. Claves de l10n usadas en el codigo que falten en el catalogo es/en.
  2. Miembros de Endpoints.* referenciados que no existan.
  3. Imports relativos que apunten a archivos inexistentes.
  4. Simbolos eliminados por esta refactorizacion que hayan quedado referenciados.
  5. Balance de parentesis/llaves/corchetes por archivo (sanidad sintactica).
  6. Providers y clases referenciados que no esten declarados en ningun archivo.
"""
import os
import re
import sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else '.'
LIB = os.path.join(ROOT, 'lib')

dart_files = []
for base, _dirs, files in os.walk(ROOT):
    if os.sep + '.dart_tool' in base or os.sep + 'build' in base:
        continue
    for f in files:
        if f.endswith('.dart'):
            dart_files.append(os.path.join(base, f))

sources = {p: open(p, encoding='utf8').read() for p in dart_files}
problems = []
def fail(msg):
    problems.append(msg)

def rel(p):
    return os.path.relpath(p, ROOT).replace('\\', '/')

# ── 1. Claves de l10n ────────────────────────────────────────────────────────
strings_path = os.path.join(LIB, 'core/l10n/app_strings.dart')
strings_src = sources[strings_path]
es_part, en_part = strings_src.split("    'en': {", 1)
KEY_RE = r'''\'([a-z0-9_]+)\':\s*['"]'''
es_keys = set(re.findall(KEY_RE, es_part))
en_keys = set(re.findall(KEY_RE, en_part))

used_keys = set()
for p, src in sources.items():
    used_keys |= set(re.findall(r"\.s\('([a-z0-9_]+)'\)", src))

missing_es = sorted(k for k in used_keys if k not in es_keys)
missing_en = sorted(k for k in used_keys if k not in en_keys)
for k in missing_es:
    fail(f"l10n: falta la clave '{k}' en el catalogo es")
for k in missing_en:
    fail(f"l10n: falta la clave '{k}' en el catalogo en")
only_es = sorted(es_keys - en_keys)
only_en = sorted(en_keys - es_keys)
for k in only_es:
    fail(f"l10n: '{k}' existe en es pero no en en")
for k in only_en:
    fail(f"l10n: '{k}' existe en en pero no en es")

# ── 2. Endpoints ─────────────────────────────────────────────────────────────
endpoints_src = sources[os.path.join(LIB, 'core/network/endpoints.dart')]
declared_endpoints = set(re.findall(r"static (?:const|String)\s+(\w+)", endpoints_src))
for p, src in sources.items():
    if p.endswith('endpoints.dart'):
        continue
    for member in re.findall(r"Endpoints\.(\w+)", src):
        if member not in declared_endpoints:
            fail(f"{rel(p)}: Endpoints.{member} no existe")

# ── 3. Imports relativos ─────────────────────────────────────────────────────
for p, src in sources.items():
    for imp in re.findall(r"import\s+'([^']+)'", src):
        if imp.startswith('package:') or imp.startswith('dart:'):
            continue
        target = os.path.normpath(os.path.join(os.path.dirname(p), imp))
        if not os.path.exists(target):
            fail(f"{rel(p)}: import inexistente -> {imp}")

# ── 4. Simbolos retirados ────────────────────────────────────────────────────
stale = {
    'phoneVerificationToken': 'renombrado a phoneToken',
    'requestPhoneVerification': 'ahora startPhoneVerification',
    'EducationCatalog.sectionsFor': 'ahora gradeGroupsFor',
    'EducationCatalog.subjectsFor': 'ahora subjectsFallback',
    'SubjectOption': 'reemplazado por TestInfo',
    'EducationSection': 'reemplazado por GradeGroup',
    'EducationLevel': 'reemplazado por GradeOption',
    "'GB'": "el backend usa 'UK'",
}
# education_catalog normaliza 'GB' -> 'UK' a proposito.
stale_exempt = {
    'education_catalog.dart': {"'GB'"},
    'education_catalog_test.dart': {"'GB'"},
}
for p, src in sources.items():
    exempt = stale_exempt.get(os.path.basename(p), set())
    for needle, hint in stale.items():
        if needle in exempt:
            continue
        if needle in src:
            fail(f"{rel(p)}: referencia obsoleta {needle} ({hint})")

# ── 5. Balance de delimitadores (ignora strings y comentarios) ───────────────
def strip_noise(src):
    out = []
    i = 0
    n = len(src)
    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ''
        if c == '/' and nxt == '/':
            while i < n and src[i] != '\n':
                i += 1
            continue
        if c == '/' and nxt == '*':
            i += 2
            while i + 1 < n and not (src[i] == '*' and src[i + 1] == '/'):
                i += 1
            i += 2
            continue
        if c == "'" and src[i:i + 3] == "'''":
            i += 3
            while i + 2 < n and src[i:i + 3] != "'''":
                i += 1
            i += 3
            continue
        if c in ('"', "'"):
            quote = c
            i += 1
            while i < n and src[i] != quote:
                if src[i] == '\\':
                    i += 2
                    continue
                # Interpolacion: hay que analizar el interior como codigo.
                if src[i] == '$' and i + 1 < n and src[i + 1] == '{':
                    depth = 0
                    i += 1
                    start = i
                    while i < n:
                        if src[i] == '{':
                            depth += 1
                        elif src[i] == '}':
                            depth -= 1
                            if depth == 0:
                                break
                        i += 1
                    out.append(strip_noise(src[start + 1:i]))
                    i += 1
                    continue
                i += 1
            i += 1
            continue
        out.append(c)
        i += 1
    return ''.join(out)

pairs = {')': '(', ']': '[', '}': '{'}
for p, src in sources.items():
    clean = strip_noise(src)
    stack = []
    for ch in clean:
        if ch in '([{':
            stack.append(ch)
        elif ch in ')]}':
            if not stack or stack[-1] != pairs[ch]:
                fail(f"{rel(p)}: delimitador desbalanceado '{ch}'")
                break
            stack.pop()
    else:
        if stack:
            fail(f"{rel(p)}: quedan {len(stack)} delimitadores sin cerrar {stack[-3:]}")

# ── 6. Providers y clases referenciados ──────────────────────────────────────
declared = set()
for src in sources.values():
    declared |= set(re.findall(r"^final\s+(\w+)\s*=", src, re.M))
    declared |= set(re.findall(r"^(?:abstract\s+)?class\s+(\w+)", src, re.M))
    declared |= set(re.findall(r"^(?:enum|mixin|extension)\s+(\w+)", src, re.M))
    declared |= set(re.findall(r"^(?:const|var)\s+(\w+)\s*=", src, re.M))
    declared |= set(re.findall(r"^\s*(?:static\s+)?(?:final|const)\s+\w+\??\s+(\w+)\s*=", src, re.M))

referenced_providers = set()
for src in sources.values():
    # El nombre debe ir seguido de ) . ( o , : si va seguido de '?' es una
    # expresion condicional, no un provider.
    referenced_providers |= set(re.findall(
        r"(?:ref\.watch|ref\.read|ref\.invalidate|ref\.listen)\(\s*(\w+)\s*(?=[).(,])", src))
for name in sorted(referenced_providers):
    if name not in declared:
        fail(f"provider referenciado sin declarar: {name}")

print(f"archivos analizados: {len(dart_files)}")
print(f"claves l10n usadas: {len(used_keys)} (es={len(es_keys)}, en={len(en_keys)})")
if problems:
    print(f"\n{len(problems)} problemas:")
    for pr in problems:
        print(f"  - {pr}")
    sys.exit(1)
print("\nsin problemas")
