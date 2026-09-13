#!/usr/bin/env python3
"""Compara los fromJson de models.dart con respuestas reales de la API.

Genera primero el volcado desde el backend:
    cd ../aprueba_student_web/backend && node src/seed/dump_payloads.js /tmp/payloads.json
y luego:
    python3 tool/check_models.py /tmp/payloads.json
"""
import json, re, sys

import os
# Uso: python3 tool/check_models.py [ruta/payloads.json] [ruta/app]
PAYLOADS = sys.argv[1] if len(sys.argv) > 1 else 'payloads.json'
app = sys.argv[2] if len(sys.argv) > 2 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
models = open(f'{app}/lib/data/models/models.dart', encoding='utf8').read()
payloads = json.load(open(PAYLOADS, encoding='utf8'))

# Bloques de clase: nombre -> texto
blocks = {}
matches = list(re.finditer(r'^class (\w+) \{', models, re.M))
for i, m in enumerate(matches):
    end = matches[i + 1].start() if i + 1 < len(matches) else len(models)
    blocks[m.group(1)] = models[m.start():end]

def read_keys(cls, holder='j'):
    """Claves que el fromJson de esa clase lee del mapa indicado."""
    src = blocks.get(cls, '')
    frag = src[src.find('fromJson'):] if 'fromJson' in src else ''
    keys = set(re.findall(holder + r"\??\['([^']+)'\]", frag))
    return keys

# modelo -> (payload, ruta al objeto de muestra, sub-objetos anidados)
def dig(obj, path):
    for step in path:
        # '*' = primer elemento no vacio de la lista (p. ej. el primer subject
        # con areas a reforzar: los que no tienen datos vienen vacios).
        if step == '*':
            obj = next((x for x in obj if x.get('areasToReinforce')), None)
            if obj is None:
                raise IndexError('sin elementos no vacios')
        else:
            obj = obj[step]
    return obj

CASES = [
    ('AuthSession', 'AuthSession', ['data'], {'user': ('User', ['data', 'user'])}),
    ('PhoneCodeHint', 'PhoneCodeHint', ['data'], {}),
    ('PhoneVerification', 'PhoneVerification', ['data'], {}),
    ('Country', 'Country', ['data', 0], {}),
    ('GradeGroup', 'GradeGroup', ['data', 0], {}),
    ('GradeOption', 'GradeGroup', ['data', 0, 'items', 0], {}),
    ('TestInfo', 'TestInfo', ['data', 0], {}),
    ('User', 'User', ['data'], {}),
    ('Preferences', 'Preferences', ['data'], {}),
    ('Tutor', 'TutorCard', ['data', 0], {}),
    ('Tutor', 'TutorDetail', ['data'], {}),
    ('CriterionValue', 'TutorDetail', ['data', 'ratingByCriterion', 0], {}),
    ('TutorReview', 'TutorReviewPage', ['data', 0], {}),
    ('GapAnalysis', 'GapAnalysis', ['data'], {}),
    ('GapSubject', 'GapAnalysis', ['data', 'subjects', 0], {}),
    ('GapArea', 'GapAnalysis', ['data', 'subjects', '*', 'areasToReinforce', 0], {}),
    ('ContactRequestResult', 'ContactRequestResult', ['data'], {}),
    ('Conversation', 'Conversation', ['data', 0], {}),
    ('ConversationDetail', 'ConversationDetail', ['data'], {}),
    ('ContactSharing', 'ContactSharing', ['data'], {}),
    ('ChatMessage', 'ChatMessage', ['data', 0], {}),
]

problems = []
for cls, payload_key, path, _nested in CASES:
    try:
        sample = dig(payloads[payload_key], path)
    except (KeyError, IndexError, TypeError) as e:
        problems.append(f'{cls}: no pude localizar la muestra en {payload_key}{path} ({e})')
        continue
    if not isinstance(sample, dict):
        problems.append(f'{cls}: la muestra en {payload_key}{path} no es un objeto')
        continue
    actual = set(sample.keys())
    wanted = read_keys(cls)
    # Claves anidadas conocidas (author, tutor, quota, revealed) se validan aparte.
    nested_holders = {'author', 'tutor', 'quota', 'revealed', 'medals', 'contactSharing', 'sharedProfile'}
    # Claves que por diseno solo existen en otra respuesta del mismo modelo.
    optional = {
        ('AuthSession', 'AuthSession'): {'isNewUser', 'phoneVerificationRequired'},
        ('Tutor', 'TutorCard'): {'bio', 'canReview', 'contacted', 'conversationId',
                                 'highlightedReview', 'myReview', 'ratingByCriterion'},
    }.get((cls, payload_key), set())
    missing = sorted(k for k in wanted if k not in actual and k not in nested_holders and k not in optional)
    unused = sorted(k for k in actual if k not in wanted)
    if missing:
        problems.append(f'{cls} <- {payload_key}: lee claves que la API no envia: {missing}')
    print(f'{cls:22s} <- {payload_key:20s} leidas={len(wanted):2d} api={len(actual):2d} sin usar={unused}')

# Sub-objetos con acceso por variable intermedia
NESTED = [
    ('User', 'quota', 'AuthSession', ['data', 'user', 'quota']),
    ('TutorReview', 'author', 'TutorReviewPage', ['data', 0, 'author']),
    ('Conversation', 'tutor', 'Conversation', ['data', 0, 'tutor']),
    ('ConversationDetail', 'tutor', 'ConversationDetail', ['data', 'tutor']),
    ('ContactSharing', 'revealed', 'ContactSharing', ['data', 'revealed']),
    ('SharedProfile', 'j', 'ConversationDetail', ['data', 'sharedProfile']),
]
print()
for cls, holder, payload_key, path in NESTED:
    try:
        sample = dig(payloads[payload_key], path)
    except (KeyError, IndexError, TypeError) as e:
        problems.append(f'{cls}.{holder}: no pude localizar {payload_key}{path} ({e})')
        continue
    if sample is None:
        print(f'{cls}.{holder:12s} <- null en la muestra (se omite)')
        continue
    actual = set(sample.keys())
    wanted = read_keys(cls, holder)
    missing = sorted(k for k in wanted if k not in actual)
    if missing:
        problems.append(f'{cls}.{holder} <- {payload_key}: lee claves inexistentes: {missing}')
    print(f'{cls}.{holder:12s} leidas={len(wanted)} api={len(actual)} sin usar={sorted(actual - wanted)}')

# meta.summary que consume TutorsRepository.reviews
repo = open(f'{app}/lib/data/repositories/tutors_repository.dart', encoding='utf8').read()
summary_keys = set(re.findall(r"summary\['([^']+)'\]", repo))
actual_summary = set(payloads['TutorReviewPage']['meta']['summary'].keys())
missing_summary = sorted(summary_keys - actual_summary)
if missing_summary:
    problems.append(f'meta.summary: claves inexistentes {missing_summary}')
print(f'\nmeta.summary leidas={sorted(summary_keys)} api={sorted(actual_summary)}')

# La reseña publicada se lee como data['review']
if 'review' not in payloads['PublishedReview']['data']:
    problems.append("POST /tutors/:id/reviews: la respuesta no trae 'review'")

print()
if problems:
    print(f'{len(problems)} problemas:')
    for p in problems:
        print(f'  - {p}')
    sys.exit(1)
print('modelos consistentes con la API')
