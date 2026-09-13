import 'package:aprueba_app/data/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Los fixtures son respuestas reales del backend
/// (aprueba_student_web/backend, sembrado con `npm run seed`).
void main() {
  test('Tutor.fromJson parsea la tarjeta del listado', () {
    final tutor = Tutor.fromJson(const {
      'id': 'tut_rodrigo',
      'name': 'Rodrigo Cea',
      'initials': 'RC',
      'avatarColor': '#10B981',
      'textColor': '#FFFFFF',
      'subjects': ['lectora'],
      'subjectsLabel': 'Comp. Lectora',
      'modes': ['online'],
      'modesLabel': 'Online',
      'pricePerHour': 10000,
      'currency': 'CLP',
      'verified': true,
      'featured': true,
      'yearsExperience': 4,
      'rating': 4.7,
      'reviewCount': 86,
    });

    expect(tutor.subjects, ['lectora']);
    expect(tutor.rating, 4.7);
    expect(tutor.reviewCount, 86);
    // Los campos de detalle no viajan en la tarjeta.
    expect(tutor.bio, isNull);
    expect(tutor.contacted, isFalse);
    expect(tutor.canReview, isFalse);
  });

  test('Tutor.fromJson parsea el detalle con criterios y resena destacada', () {
    final tutor = Tutor.fromJson(const {
      'id': 'tut_maria',
      'name': 'Maria Valdes',
      'initials': 'MV',
      'rating': 4.9,
      'reviewCount': 130,
      'bio': 'Ingeniera civil PUC.',
      'ratingByCriterion': [
        {'key': 'teaching', 'label': 'Didactica (claridad)', 'value': 4.9},
        {'key': 'punctuality', 'label': 'Puntualidad', 'value': 4.8},
        {'key': 'mastery', 'label': 'Dominio del tema', 'value': 5},
      ],
      'highlightedReview': {
        'id': 'rev_1',
        'author': {'name': 'Camila Rojas', 'initials': 'CR', 'avatarColor': '#1A365D'},
        'overall': 5,
        'comment': 'Explica increible.',
        'criteria': [
          {'key': 'teaching', 'label': 'Didactica (claridad)', 'value': 5},
        ],
        'createdAt': '2026-07-21T10:00:00.000Z',
      },
      'contacted': true,
      'canReview': true,
      'conversationId': 'cnv_1',
    });

    expect(tutor.bio, isNotNull);
    expect(tutor.ratingByCriterion.length, 3);
    expect(tutor.ratingByCriterion.first.key, 'teaching');
    // El backend puede enviar enteros donde el modelo espera double.
    expect(tutor.ratingByCriterion.last.value, 5);
    expect(tutor.highlightedReview!.authorName, 'Camila Rojas');
    expect(tutor.highlightedReview!.createdAt, isNotNull);
    expect(tutor.conversationId, 'cnv_1');
    expect(tutor.canReview, isTrue);
  });

  test('GapAnalysis ordena de mayor a menor necesidad y trae areas', () {
    final analysis = GapAnalysis.fromJson(const {
      'basedOnExercises': 4,
      'generatedAt': '2026-08-04T11:06:07.000Z',
      'subjects': [
        {
          'testId': 'cien',
          'label': 'Ciencias',
          'color': '#F5B041',
          'mastery': 44,
          'status': 'critical',
          'exercises': 0,
          'hasData': false,
          'areasToReinforce': [],
          'recommendedTutorCount': 1,
        },
        {
          'testId': 'm1',
          'label': 'Matematica M1',
          'color': '#10B981',
          'mastery': 58,
          'status': 'warning',
          'exercises': 3,
          'hasData': true,
          'areasToReinforce': [
            {'area': 'Numeros y Algebra', 'mastery': 33, 'exercises': 3},
          ],
          'recommendedTutorCount': 1,
        },
      ],
    });

    expect(analysis.basedOnExercises, 4);
    expect(analysis.subjects.first.status, 'critical');
    expect(analysis.subjects.first.hasData, isFalse);
    expect(analysis.subjects.last.areasToReinforce.single.area, 'Numeros y Algebra');
    expect(analysis.subjects.last.recommendedTutorCount, 1);
  });

  test('Conversation y ConversationDetail aplanan el tutor', () {
    final conversation = Conversation.fromJson(const {
      'id': 'cnv_1',
      'tutor': {
        'id': 'tut_paula',
        'name': 'Paula Soto',
        'initials': 'PS',
        'avatarColor': '#6366F1',
        'online': false,
      },
      'lastMessagePreview': 'Hola Paula',
      'lastMessageAt': '2026-08-04T11:06:07.996Z',
      'unreadCount': 2,
      'lessonsTaken': 0,
      'contactShared': false,
    });

    expect(conversation.tutorId, 'tut_paula');
    expect(conversation.tutorName, 'Paula Soto');
    expect(conversation.unreadCount, 2);
    expect(conversation.lastMessageAt, isNotNull);

    final detail = ConversationDetail.fromJson(const {
      'id': 'cnv_1',
      'tutor': {'id': 'tut_paula', 'name': 'Paula Soto', 'initials': 'PS', 'online': true},
      'lessonsTaken': 8,
      'unreadCount': 0,
      'contactSharing': {
        'myConsent': true,
        'tutorConsent': true,
        'mutual': true,
        'revealed': {'tutorWhatsapp': '+56933333333', 'myWhatsapp': '+56987654321'},
      },
      'sharedProfile': {
        'name': 'Camila Rojas',
        'initials': 'CA',
        'gradeLabel': 'PAES',
        'goal': null,
        'weakAreas': ['Comprension lectora'],
      },
    });

    expect(detail.tutorOnline, isTrue);
    expect(detail.lessonsTaken, 8);
    expect(detail.contactSharing.mutual, isTrue);
    expect(detail.contactSharing.tutorWhatsapp, '+56933333333');
    expect(detail.sharedProfile!.weakAreas, ['Comprension lectora']);
  });

  test('ContactSharing sin consentimiento mutuo no revela telefonos', () {
    final sharing = ContactSharing.fromJson(const {
      'myConsent': true,
      'tutorConsent': false,
      'mutual': false,
      'revealed': null,
    });

    expect(sharing.myConsent, isTrue);
    expect(sharing.mutual, isFalse);
    expect(sharing.tutorWhatsapp, isNull);
    expect(sharing.myWhatsapp, isNull);
  });

  test('ChatMessage distingue mis mensajes de los del tutor', () {
    final mine = ChatMessage.fromJson(const {
      'id': 'msg_1',
      'text': 'Puedo los jueves',
      'mine': true,
      'senderType': 'user',
      'createdAt': '2026-08-04T11:06:07.996Z',
    });
    final theirs = ChatMessage.fromJson(const {
      'id': 'msg_2',
      'text': 'Tengo cupo martes y jueves',
      'mine': false,
      'senderType': 'tutor',
      'createdAt': '2026-08-04T11:07:07.996Z',
    });

    expect(mine.mine, isTrue);
    expect(theirs.senderType, 'tutor');
    expect(theirs.createdAt!.isAfter(mine.createdAt!), isTrue);
  });

  test('Preferences serializa pais, idioma y grado solo si existen', () {
    const full = Preferences(
      selectedTests: ['lectora', 'm1'],
      format: 'random',
      difficulty: 'd2',
      country: 'CL',
      language: 'es',
      gradeId: 'cl-paes',
    );
    expect(full.toJson()['gradeId'], 'cl-paes');
    expect(full.toJson()['country'], 'CL');

    const partial = Preferences(selectedTests: ['m1']);
    expect(partial.toJson().containsKey('gradeId'), isFalse);
    expect(partial.toJson().containsKey('country'), isFalse);
  });

  test('PhoneCodeHint y PhoneVerification cubren el flujo telefonico', () {
    final hint = PhoneCodeHint.fromJson(const {
      'phone': '+447700900123',
      'masked': '+44******0123',
      'verifier': 'firebase',
      'codeLength': 6,
      'detectedCountry': 'UK',
      'detectedLanguage': 'en',
      'dialCode': '+44',
      'accountExists': false,
    });
    expect(hint.detectedCountry, 'UK');
    expect(hint.detectedLanguage, 'en');
    expect(hint.codeLength, 6);

    final verification = PhoneVerification.fromJson(const {
      'phoneToken': 'eyJhbGciOi',
      'expiresIn': 900,
      'phone': '+56912345678',
      'country': 'CL',
      'language': 'es',
      'accountExists': true,
    });
    expect(verification.phoneToken, isNotEmpty);
    expect(verification.country, 'CL');
    expect(verification.accountExists, isTrue);
  });

  test('User expone telefono, pais y grado del onboarding', () {
    final user = User.fromJson(const {
      'id': 'usr_demo',
      'name': 'Estudiante Demo',
      'plan': 'free',
      'quota': {'used': 5, 'max': 10},
      'medals': {'bronze': 14},
      'authProvider': 'password',
      'phone': '+56912345678',
      'phoneVerified': true,
      'country': 'CL',
      'language': 'es',
      'gradeId': 'cl-paes',
      'onboarded': true,
    });

    expect(user.isPaid, isFalse);
    expect(user.phoneVerified, isTrue);
    expect(user.country, 'CL');
    expect(user.gradeId, 'cl-paes');
    expect(user.authProvider, 'password');
  });

  test('Country y GradeGroup alimentan el onboarding', () {
    final country = Country.fromJson(const {
      'code': 'UK',
      'name': 'Reino Unido',
      'dialCode': '+44',
      'flag': '🇬🇧',
      'languages': ['en', 'es'],
      'defaultLanguage': 'en',
      'currency': 'GBP',
    });
    expect(country.languages, ['en', 'es']);
    expect(country.defaultLanguage, 'en');

    final group = GradeGroup.fromJson(const {
      'key': 'qualifications',
      'label': 'National qualifications',
      'items': [
        {'id': 'uk-gcse', 'label': 'GCSE', 'kind': 'exam'},
        {'id': 'uk-a-levels', 'label': 'A levels', 'kind': 'exam'},
      ],
    });
    expect(group.items.length, 2);
    expect(group.items.first.kind, 'exam');
  });
}
