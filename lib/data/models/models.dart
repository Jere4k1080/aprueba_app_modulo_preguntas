// Modelos de dominio expuestos por la API de Aprueba (modelo lógico).
// Plain Dart con fromJson para mantener el proyecto sin codegen extra.

T? _as<T>(dynamic v) => v is T ? v : null;
int _int(dynamic v, [int d = 0]) => v is int ? v : (v is num ? v.toInt() : d);
double _double(dynamic v, [double d = 0]) =>
    v is num ? v.toDouble() : d;
bool _bool(dynamic v, [bool d = false]) => v is bool ? v : d;
String _str(dynamic v, [String d = '']) => v is String ? v : d;
List<Map<String, dynamic>> _listMap(dynamic v) =>
    (v is List ? v : const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();

class User {
  User({
    required this.id,
    required this.name,
    this.email = '',
    this.plan = 'free',
    this.streak = 0,
    this.quotaUsed = 0,
    this.quotaMax = 10,
    this.medals = const Medals(),
    this.school,
    this.region,
    this.age,
    this.authProvider,
    this.phone,
    this.phoneVerified = false,
    this.country,
    this.language = 'es',
    this.gradeId,
    this.onboarded = false,
  });

  final String id;
  final String name;
  final String email;
  final String plan; // free | uni | all
  final int streak;
  final int quotaUsed;
  final int quotaMax;
  final Medals medals;
  final String? school;
  final String? region;
  final int? age;
  final String? authProvider;
  final String? phone;
  final bool phoneVerified;
  final String? country; // CL | UK
  final String language; // es | en
  final String? gradeId;
  final bool onboarded;

  bool get isPaid => plan != 'free';

  factory User.fromJson(Map<String, dynamic> j) {
    final quota = _as<Map>(j['quota'])?.cast<String, dynamic>();
    return User(
      id: _str(j['id']),
      name: _str(j['name']),
      email: _str(j['email']),
      plan: _str(j['plan'], 'free'),
      streak: _int(j['streak']),
      quotaUsed: _int(quota?['used']),
      quotaMax: _int(quota?['max'], 10),
      medals: Medals.fromJson(_as<Map>(j['medals'])?.cast<String, dynamic>() ?? const {}),
      school: _as<String>(j['school']),
      region: _as<String>(j['region']),
      age: _as<int>(j['age']),
      authProvider: _as<String>(j['authProvider']),
      phone: _as<String>(j['phone']),
      phoneVerified: _bool(j['phoneVerified']),
      country: _as<String>(j['country']),
      language: _str(j['language'], 'es'),
      gradeId: _as<String>(j['gradeId']),
      onboarded: _bool(j['onboarded']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'plan': plan,
        'streak': streak,
        'quota': {'used': quotaUsed, 'max': quotaMax},
        'medals': medals.toJson(),
        'school': school,
        'region': region,
        'age': age,
        'authProvider': authProvider,
        'phone': phone,
        'phoneVerified': phoneVerified,
        'country': country,
        'language': language,
        'gradeId': gradeId,
        'onboarded': onboarded,
      };
}

class Medals {
  const Medals({
    this.bronze = 0,
    this.silver = 0,
    this.gold = 0,
    this.diamond = 0,
    this.platinum = 0,
  });
  final int bronze, silver, gold, diamond, platinum;

  int byTier(String t) => {
        'bronze': bronze,
        'silver': silver,
        'gold': gold,
        'diamond': diamond,
        'platinum': platinum,
      }[t] ??
      0;

  static const tiers = ['bronze', 'silver', 'gold', 'diamond', 'platinum'];
  static String? nextTier(String t) {
    final i = tiers.indexOf(t);
    return (i >= 0 && i < tiers.length - 1) ? tiers[i + 1] : null;
  }

  factory Medals.fromJson(Map<String, dynamic> j) => Medals(
        bronze: _int(j['bronze']),
        silver: _int(j['silver']),
        gold: _int(j['gold']),
        diamond: _int(j['diamond']),
        platinum: _int(j['platinum']),
      );

  Map<String, dynamic> toJson() => {
        'bronze': bronze,
        'silver': silver,
        'gold': gold,
        'diamond': diamond,
        'platinum': platinum,
      };
}

class AuthSession {
  AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    this.isNewUser = false,
    this.phoneVerificationRequired = false,
  });
  final User user;
  final String accessToken;
  final String refreshToken;
  final bool isNewUser;

  /// El login social devuelve true mientras la cuenta no tenga teléfono
  /// verificado: el cliente debe pasar por /onboarding/phone.
  final bool phoneVerificationRequired;

  factory AuthSession.fromJson(Map<String, dynamic> j) => AuthSession(
        user: User.fromJson(_as<Map>(j['user'])?.cast<String, dynamic>() ?? const {}),
        accessToken: _str(j['accessToken']),
        refreshToken: _str(j['refreshToken']),
        isNewUser: _bool(j['isNewUser']),
        phoneVerificationRequired: _bool(j['phoneVerificationRequired']),
      );
}

/// Respuesta de POST /auth/phone/send-code: no envía SMS (lo hace Firebase en el
/// cliente), pero valida el número y deduce país/idioma del prefijo.
class PhoneCodeHint {
  const PhoneCodeHint({
    required this.phone,
    this.masked = '',
    this.detectedCountry,
    this.detectedLanguage,
    this.dialCode,
    this.accountExists = false,
    this.codeLength = 6,
  });
  final String phone;
  final String masked;
  final String? detectedCountry;
  final String? detectedLanguage;
  final String? dialCode;
  final bool accountExists;
  final int codeLength;

  factory PhoneCodeHint.fromJson(Map<String, dynamic> j) => PhoneCodeHint(
        phone: _str(j['phone']),
        masked: _str(j['masked']),
        detectedCountry: _as<String>(j['detectedCountry']),
        detectedLanguage: _as<String>(j['detectedLanguage']),
        dialCode: _as<String>(j['dialCode']),
        accountExists: _bool(j['accountExists']),
        codeLength: _int(j['codeLength'], 6),
      );
}

/// Respuesta de POST /auth/phone/verify-code.
class PhoneVerification {
  const PhoneVerification({
    required this.phoneToken,
    required this.phone,
    this.country,
    this.language,
    this.accountExists = false,
    this.expiresIn = 900,
  });
  final String phoneToken;
  final String phone;
  final String? country;
  final String? language;
  final bool accountExists;
  final int expiresIn;

  factory PhoneVerification.fromJson(Map<String, dynamic> j) => PhoneVerification(
        phoneToken: _str(j['phoneToken']),
        phone: _str(j['phone']),
        country: _as<String>(j['country']),
        language: _as<String>(j['language']),
        accountExists: _bool(j['accountExists']),
        expiresIn: _int(j['expiresIn'], 900),
      );
}

/// GET /countries
class Country {
  const Country({
    required this.code,
    required this.name,
    required this.dialCode,
    this.flag = '',
    this.languages = const ['es'],
    this.defaultLanguage = 'es',
  });
  final String code; // CL | UK
  final String name;
  final String dialCode;
  final String flag;
  final List<String> languages;
  final String defaultLanguage;

  factory Country.fromJson(Map<String, dynamic> j) => Country(
        code: _str(j['code']),
        name: _str(j['name']),
        dialCode: _str(j['dialCode']),
        flag: _str(j['flag']),
        languages: (j['languages'] as List?)?.map((e) => e.toString()).toList() ?? const ['es'],
        defaultLanguage: _str(j['defaultLanguage'], 'es'),
      );
}

/// Un grado o prueba dentro de un grupo del catálogo educativo.
class GradeOption {
  const GradeOption({required this.id, required this.label, this.kind = 'school'});
  final String id;
  final String label;
  final String kind; // school | exam

  factory GradeOption.fromJson(Map<String, dynamic> j) => GradeOption(
        id: _str(j['id']),
        label: _str(j['label']),
        kind: _str(j['kind'], 'school'),
      );
}

/// GET /countries/:code/grades
class GradeGroup {
  const GradeGroup({required this.key, required this.label, this.items = const []});
  final String key;
  final String label;
  final List<GradeOption> items;

  factory GradeGroup.fromJson(Map<String, dynamic> j) => GradeGroup(
        key: _str(j['key']),
        label: _str(j['label']),
        items: _listMap(j['items']).map(GradeOption.fromJson).toList(),
      );
}

class TestInfo {
  TestInfo({required this.id, required this.label, required this.color, this.hasQuestions = true});
  final String id;
  final String label;
  final String color;

  /// false para asignaturas escolares que aún no tienen banco de preguntas.
  final bool hasQuestions;

  factory TestInfo.fromJson(Map<String, dynamic> j) => TestInfo(
        id: _str(j['id']),
        label: _str(j['label']),
        color: _str(j['color'], '#1A365D'),
        hasQuestions: _bool(j['hasQuestions'], true),
      );
  Map<String, dynamic> toJson() =>
      {'id': id, 'label': label, 'color': color, 'hasQuestions': hasQuestions};
}

class Preferences {
  const Preferences({
    this.selectedTests = const [],
    this.format = 'random',
    this.difficulty = 'd1',
    this.country,
    this.language,
    this.gradeId,
    this.onboarded = false,
  });
  final List<String> selectedTests;
  final String format; // random | facsim
  final String difficulty; // d1..d4

  /// País, idioma y grado del onboarding (PUT /me/preferences los persiste).
  final String? country; // CL | UK
  final String? language; // es | en
  final String? gradeId;
  final bool onboarded;

  factory Preferences.fromJson(Map<String, dynamic> j) => Preferences(
        selectedTests: (j['selectedTests'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        format: _str(j['format'], 'random'),
        difficulty: _str(j['difficulty'], 'd1'),
        country: _as<String>(j['country']),
        language: _as<String>(j['language']),
        gradeId: _as<String>(j['gradeId']),
        onboarded: _bool(j['onboarded']),
      );

  Map<String, dynamic> toJson() => {
        'selectedTests': selectedTests,
        'format': format,
        'difficulty': difficulty,
        if (country != null) 'country': country,
        if (language != null) 'language': language,
        if (gradeId != null) 'gradeId': gradeId,
      };

  Preferences copyWith({
    List<String>? selectedTests,
    String? format,
    String? difficulty,
    String? country,
    String? language,
    String? gradeId,
    bool? onboarded,
  }) =>
      Preferences(
        selectedTests: selectedTests ?? this.selectedTests,
        format: format ?? this.format,
        difficulty: difficulty ?? this.difficulty,
        country: country ?? this.country,
        language: language ?? this.language,
        gradeId: gradeId ?? this.gradeId,
        onboarded: onboarded ?? this.onboarded,
      );
}

class Question {
  Question({
    required this.id,
    required this.testId,
    this.axis,
    this.skillId,
    this.difficulty,
    required this.statement,
    required this.options,
    this.correctAnswer,
    this.explanation,
    this.status = 'active',
    this.progressCurrent,
    this.progressTotal,
  });
  final String id;
  final String testId;
  final String? axis;

  /// FK a la colección `skills`. Nullable porque preguntas antiguas pueden no tenerlo.
  final String? skillId;
  final String? difficulty;
  final String statement;
  final List<String> options;

  /// Letra correcta (A–E). No se envía al alumno antes de responder.
  final String? correctAnswer;

  /// Explicación corta (resumen). La explicación detallada viaja en otro endpoint.
  final String? explanation;

  /// Estado del documento en Firestore: `active` | `draft` | `disabled`.
  final String status;
  final int? progressCurrent;
  final int? progressTotal;

  factory Question.fromJson(Map<String, dynamic> j) {
    final prog = _as<Map>(j['progress'])?.cast<String, dynamic>();
    return Question(
      id: _str(j['id']),
      testId: _str(j['testId']),
      axis: _as<String>(j['axis']),
      skillId: _as<String>(j['skillId']),
      difficulty: _as<String>(j['difficulty']),
      statement: _str(j['statement']),
      options: (j['options'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      correctAnswer: _as<String>(j['correctAnswer']),
      explanation: _as<String>(j['explanation']),
      status: _str(j['status'], 'active'),
      progressCurrent: prog == null ? null : _int(prog['current']),
      progressTotal: prog == null ? null : _int(prog['total']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'testId': testId,
        if (axis != null) 'axis': axis,
        if (skillId != null) 'skillId': skillId,
        if (difficulty != null) 'difficulty': difficulty,
        'statement': statement,
        'options': options,
        if (correctAnswer != null) 'correctAnswer': correctAnswer,
        if (explanation != null) 'explanation': explanation,
        'status': status,
        if (progressCurrent != null || progressTotal != null)
          'progress': {
            if (progressCurrent != null) 'current': progressCurrent,
            if (progressTotal != null) 'total': progressTotal,
          },
      };
}

class AnswerResult {
  AnswerResult({
    required this.correct,
    required this.correctAnswer,
    required this.shortExplanation,
    this.cohortPercentile,
    this.medalTier,
    this.medalAmount = 0,
    this.quotaUsed = 0,
    this.quotaMax = 0,
  });
  final bool correct;
  final String correctAnswer; // letra A..E
  final String shortExplanation;
  final int? cohortPercentile;
  final String? medalTier;
  final int medalAmount;
  final int quotaUsed;
  final int quotaMax;

  factory AnswerResult.fromJson(Map<String, dynamic> j) {
    final medal = _as<Map>(j['medalAwarded'])?.cast<String, dynamic>();
    final quota = _as<Map>(j['quota'])?.cast<String, dynamic>();
    return AnswerResult(
      correct: _bool(j['correct']),
      correctAnswer: _str(j['correctAnswer']),
      shortExplanation: _str(j['shortExplanation']),
      cohortPercentile: _as<int>(j['cohortPercentile']),
      medalTier: medal?['tier'] as String?,
      medalAmount: _int(medal?['amount']),
      quotaUsed: _int(quota?['used']),
      quotaMax: _int(quota?['max']),
    );
  }
}

class ExplanationStep {
  ExplanationStep(this.label, this.body);
  final String label;
  final String body;
}

class Explanation {
  Explanation({required this.title, required this.subject, required this.steps, this.verification, this.keyConcept});
  final String title;
  final String subject;
  final List<ExplanationStep> steps;
  final String? verification;
  final String? keyConcept;
  factory Explanation.fromJson(Map<String, dynamic> j) => Explanation(
        title: _str(j['title']),
        subject: _str(j['subject']),
        steps: _listMap(j['steps']).map((m) => ExplanationStep(_str(m['label']), _str(m['body']))).toList(),
        verification: _as<String>(j['verification']),
        keyConcept: _as<String>(j['keyConcept']),
      );
}

class SkillInfo {
  SkillInfo({
    required this.name,
    required this.test,
    required this.level,
    required this.maxLevel,
    required this.masteryPercent,
    required this.masteryCorrect,
    required this.masteryTotal,
    required this.masteryStatus,
    required this.prerequisites,
    required this.resources,
  });
  final String name;
  final String test;
  final int level;
  final int maxLevel;
  final int masteryPercent;
  final int masteryCorrect;
  final int masteryTotal;
  final String masteryStatus;
  final List<({String name, String status})> prerequisites;
  final List<({String type, String title, String? duration, String? source, String? url})> resources;

  factory SkillInfo.fromJson(Map<String, dynamic> j) {
    final skill = _as<Map>(j['skill'])?.cast<String, dynamic>() ?? const {};
    final mastery = _as<Map>(j['mastery'])?.cast<String, dynamic>() ?? const {};
    return SkillInfo(
      name: _str(skill['name']),
      test: _str(skill['test']),
      level: _int(skill['level']),
      maxLevel: _int(skill['maxLevel'], 4),
      masteryPercent: _int(mastery['percent']),
      masteryCorrect: _int(mastery['correct']),
      masteryTotal: _int(mastery['total']),
      masteryStatus: _str(mastery['status'], 'in_progress'),
      prerequisites: _listMap(j['prerequisites'])
          .map((m) => (name: _str(m['name']), status: _str(m['status'], 'locked')))
          .toList(),
      resources: _listMap(j['resources'])
          .map((m) => (
                type: _str(m['type'], 'video'),
                title: _str(m['title']),
                duration: _as<String>(m['duration']),
                source: _as<String>(m['source']),
                url: _as<String>(m['url'])
              ))
          .toList(),
    );
  }
}

class QuotaState {
  QuotaState({
    required this.used,
    required this.max,
    this.base = 10,
    this.schoolBonus = false,
    this.addressBonus = false,
    this.unlimited = false,
    this.resetsAt,
  });
  final int used, max, base;
  final bool schoolBonus, addressBonus, unlimited;
  final DateTime? resetsAt;
  factory QuotaState.fromJson(Map<String, dynamic> j) {
    final bonuses = _as<Map>(j['bonuses'])?.cast<String, dynamic>();
    return QuotaState(
      used: _int(j['used']),
      max: _int(j['max'], 10),
      base: _int(j['base'], 10),
      schoolBonus: _bool(bonuses?['school']),
      addressBonus: _bool(bonuses?['address']),
      unlimited: _bool(j['unlimited']),
      resetsAt: DateTime.tryParse(_str(j['resetsAt'])),
    );
  }

  Map<String, dynamic> toJson() => {
        'used': used,
        'max': max,
        'base': base,
        'bonuses': {'school': schoolBonus, 'address': addressBonus},
        'unlimited': unlimited,
        if (resetsAt != null) 'resetsAt': resetsAt!.toIso8601String(),
      };
}

class ProgressItem {
  ProgressItem(this.testId, this.label, this.percent);
  final String testId;
  final String label;
  final int percent;
  factory ProgressItem.fromJson(Map<String, dynamic> j) =>
      ProgressItem(_str(j['testId']), _str(j['label']), _int(j['percent']));
}

class Correction {
  Correction({
    required this.id,
    this.userId,
    required this.questionId,
    required this.reason,
    this.comment,
    required this.status,
    this.rewardAmount,
    this.potentialReward,
    this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
  });
  final String id;

  /// UID del alumno que reportó. Puede ser null en respuestas del backend
  /// que no lo incluyan (el backend lo infiere del token).
  final String? userId;
  final String questionId;
  final String reason;

  /// Cinco valores tipificados de la causa de reporte.
  static const reasons = ['wrong_answer', 'ambiguous', 'typo', 'bad_explanation', 'other'];

  /// Tres estados del ciclo de vida de la recorrección.
  static const statuses = ['pending', 'confirmed', 'rejected'];

  /// Comentario libre del alumno (opcional).
  final String? comment;
  final String status; // pending | confirmed | rejected
  final int? rewardAmount;

  /// Recompensa potencial en medallas si el reporte es confirmado.
  final int? potentialReward;
  final DateTime? createdAt;

  /// Fecha en que un revisor procesó la solicitud.
  final DateTime? reviewedAt;

  /// UID del revisor (admin/moderador).
  final String? reviewedBy;

  factory Correction.fromJson(Map<String, dynamic> j) {
    final reward = _as<Map>(j['rewardGranted'])?.cast<String, dynamic>() ??
        _as<Map>(j['potentialReward'])?.cast<String, dynamic>();
    final potReward = _as<Map>(j['potentialReward']) != null
        ? _int(_as<Map>(j['potentialReward'])!['amount'])
        : (j['potentialReward'] is num ? _int(j['potentialReward']) : null);
    return Correction(
      id: _str(j['id']),
      userId: _as<String>(j['userId']),
      questionId: _str(j['questionId']),
      reason: _str(j['reason']),
      comment: _as<String>(j['comment']),
      status: _str(j['status'], 'pending'),
      rewardAmount: reward == null ? null : _int(reward['amount']),
      potentialReward: potReward,
      createdAt: DateTime.tryParse(_str(j['createdAt'])),
      reviewedAt: DateTime.tryParse(_str(j['reviewedAt'])),
      reviewedBy: _as<String>(j['reviewedBy']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (userId != null) 'userId': userId,
        'questionId': questionId,
        'reason': reason,
        if (comment != null) 'comment': comment,
        'status': status,
        if (rewardAmount != null) 'rewardGranted': {'amount': rewardAmount},
        if (potentialReward != null) 'potentialReward': {'amount': potentialReward},
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (reviewedAt != null) 'reviewedAt': reviewedAt!.toIso8601String(),
        if (reviewedBy != null) 'reviewedBy': reviewedBy,
      };
}

class MedalWalletState {
  MedalWalletState({required this.wallet, this.progress = const {}});
  final Medals wallet;
  final Map<String, ({int have, int needed, String next})> progress;
  factory MedalWalletState.fromJson(Map<String, dynamic> j) {
    final prog = <String, ({int have, int needed, String next})>{};
    final p = _as<Map>(j['progress'])?.cast<String, dynamic>() ?? const {};
    p.forEach((k, v) {
      final m = (v as Map).cast<String, dynamic>();
      prog[k] = (have: _int(m['have']), needed: _int(m['needed'], 5), next: _str(m['next']));
    });
    return MedalWalletState(
      wallet: Medals.fromJson(_as<Map>(j['wallet'])?.cast<String, dynamic>() ?? const {}),
      progress: prog,
    );
  }
}

class GiftFriend {
  GiftFriend({required this.userId, required this.name, this.giftedToday = 0});
  final String userId;
  final String name;
  final int giftedToday;
  factory GiftFriend.fromJson(Map<String, dynamic> j) =>
      GiftFriend(userId: _str(j['userId']), name: _str(j['name']), giftedToday: _int(j['giftedToday']));
}

class GiftState {
  GiftState({required this.dailyUsed, required this.dailyMax, required this.bronzeAvailable, required this.friends});
  final int dailyUsed, dailyMax, bronzeAvailable;
  final List<GiftFriend> friends;
  factory GiftState.fromJson(Map<String, dynamic> j) {
    final daily = _as<Map>(j['daily'])?.cast<String, dynamic>();
    return GiftState(
      dailyUsed: _int(daily?['used']),
      dailyMax: _int(daily?['max'], 10),
      bronzeAvailable: _int(j['bronzeAvailable']),
      friends: _listMap(j['friends']).map(GiftFriend.fromJson).toList(),
    );
  }
}

class Benefit {
  Benefit({required this.id, required this.name, required this.description, this.costPlatinum = 5, this.unlocked = false, this.sponsor});
  final String id, name, description;
  final int costPlatinum;
  final bool unlocked;
  final String? sponsor;
  factory Benefit.fromJson(Map<String, dynamic> j) => Benefit(
        id: _str(j['id']),
        name: _str(j['name']),
        description: _str(j['description']),
        costPlatinum: _int(j['costPlatinum'], 5),
        unlocked: _bool(j['unlocked']),
        sponsor: _as<String>(j['sponsor']),
      );
}

class GroupMember {
  GroupMember({required this.userId, required this.name, this.score, this.activeToday = false});
  final String userId;
  final String name;
  final int? score;
  final bool activeToday;
  factory GroupMember.fromJson(Map<String, dynamic> j) => GroupMember(
        userId: _str(j['userId']),
        name: _str(j['name']),
        score: _as<int>(j['score']),
        activeToday: _bool(j['activeToday']),
      );
}

class Group {
  Group({
    required this.id,
    required this.name,
    required this.subject,
    this.memberCount = 1,
    this.avgScore,
    this.yourScore,
    this.members = const [],
  });
  final String id, name, subject;
  final int memberCount;
  final int? avgScore, yourScore;
  final List<GroupMember> members;
  factory Group.fromJson(Map<String, dynamic> j) => Group(
        id: _str(j['id']),
        name: _str(j['name']),
        subject: _str(j['subject']),
        memberCount: _int(j['memberCount'], 1),
        avgScore: _as<int>(j['avgScore']),
        yourScore: _as<int>(j['yourScore']),
        members: _listMap(j['members']).map(GroupMember.fromJson).toList(),
      );
}

class GroupStats {
  GroupStats({required this.avgScore, required this.memberCount, required this.best, required this.weak});
  final int avgScore, memberCount;
  final List<({String area, int avg})> best, weak;
  static List<({String area, int avg})> _areas(dynamic v) =>
      _listMap(v).map((m) => (area: _str(m['area']), avg: _int(m['avg']))).toList();
  factory GroupStats.fromJson(Map<String, dynamic> j) => GroupStats(
        avgScore: _int(j['avgScore']),
        memberCount: _int(j['memberCount']),
        best: _areas(j['best']),
        weak: _areas(j['weak']),
      );
}

class Post {
  Post({required this.id, required this.authorName, required this.text, this.questionId, this.likes = 0, this.comments = 0, this.liked = false, this.createdAt});
  final String id, authorName, text;
  final String? questionId;
  final int likes, comments;
  final bool liked;
  final DateTime? createdAt;
  factory Post.fromJson(Map<String, dynamic> j) => Post(
        id: _str(j['id']),
        authorName: _str(_as<Map>(j['author'])?['name']),
        text: _str(j['text']),
        questionId: _as<Map>(j['question'])?['id'] as String?,
        likes: _int(j['likes']),
        comments: _int(j['comments']),
        liked: _bool(j['liked']),
        createdAt: DateTime.tryParse(_str(j['createdAt'])),
      );
}

class Plan {
  Plan({required this.id, required this.name, this.popular = false, this.features = const [], this.priceMonthly = 0, this.priceYearly = 0});
  final String id, name;
  final bool popular;
  final List<String> features;
  final num priceMonthly, priceYearly;
  factory Plan.fromJson(Map<String, dynamic> j) {
    final price = _as<Map>(j['price'])?.cast<String, dynamic>();
    return Plan(
      id: _str(j['id']),
      name: _str(j['name']),
      popular: _bool(j['popular']),
      features: (j['features'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      priceMonthly: _double(price?['monthly']),
      priceYearly: _double(price?['yearly']),
    );
  }
}

class Subscription {
  Subscription({required this.id, required this.plan, required this.billingCycle, required this.status, this.currentPeriodEnd, this.cancelAtPeriodEnd = false, this.cardBrand, this.cardLast4});
  final String id, plan, billingCycle, status;
  final String? currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final String? cardBrand, cardLast4;
  factory Subscription.fromJson(Map<String, dynamic> j) {
    final pm = _as<Map>(j['paymentMethod'])?.cast<String, dynamic>();
    return Subscription(
      id: _str(j['id']),
      plan: _str(j['plan']),
      billingCycle: _str(j['billingCycle'], 'monthly'),
      status: _str(j['status'], 'active'),
      currentPeriodEnd: _as<String>(j['currentPeriodEnd']),
      cancelAtPeriodEnd: _bool(j['cancelAtPeriodEnd']),
      cardBrand: pm?['brand'] as String?,
      cardLast4: pm?['last4'] as String?,
    );
  }
}

class CheckoutSession {
  CheckoutSession({required this.checkoutSessionId, required this.clientSecret, required this.amount, required this.currency, required this.plan, required this.billingCycle});
  final String checkoutSessionId, clientSecret, currency, plan, billingCycle;
  final num amount;
  factory CheckoutSession.fromJson(Map<String, dynamic> j) => CheckoutSession(
        checkoutSessionId: _str(j['checkoutSessionId']),
        clientSecret: _str(j['clientSecret']),
        amount: _double(j['amount']),
        currency: _str(j['currency'], 'USD'),
        plan: _str(j['plan']),
        billingCycle: _str(j['billingCycle'], 'monthly'),
      );
}

class NotificationItem {
  NotificationItem({required this.id, required this.type, required this.title, required this.body, this.read = false, this.createdAt});
  final String id, type, title, body;
  final bool read;
  final DateTime? createdAt;
  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
        id: _str(j['id']),
        type: _str(j['type']),
        title: _str(j['title']),
        body: _str(j['body']),
        read: _bool(j['read']),
        createdAt: DateTime.tryParse(_str(j['createdAt'])),
      );
}

class AppSettings {
  AppSettings({this.locale = 'es', this.theme = 'light', this.dailyReminder = true, this.reminderTime = '19:00', this.selectedTests = const [], this.format = 'random', this.difficulty = 'd2'});
  final String locale, theme;
  final bool dailyReminder;
  final String reminderTime;
  final List<String> selectedTests;
  final String format, difficulty;
  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        locale: _str(j['locale'], 'es'),
        theme: _str(j['theme'], 'light'),
        dailyReminder: _bool(j['dailyReminder'], true),
        reminderTime: _str(j['reminderTime'], '19:00'),
        selectedTests: (j['selectedTests'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        format: _str(j['format'], 'random'),
        difficulty: _str(j['difficulty'], 'd2'),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Marketplace de tutores (GET /tutors, /tutors/:id, reseñas, chat y análisis)
// ─────────────────────────────────────────────────────────────────────────────

/// Valor de uno de los tres criterios de valoración del wireframe.
class CriterionValue {
  const CriterionValue({required this.key, required this.label, this.value});
  final String key; // teaching | punctuality | mastery
  final String label;
  final double? value;

  factory CriterionValue.fromJson(Map<String, dynamic> j) => CriterionValue(
        key: _str(j['key']),
        label: _str(j['label']),
        value: j['value'] == null ? null : _double(j['value']),
      );
}

class Tutor {
  const Tutor({
    required this.id,
    required this.name,
    this.initials = '',
    this.avatarColor = '#1A365D',
    this.textColor = '#FFFFFF',
    this.subjects = const [],
    this.subjectsLabel = '',
    this.modes = const [],
    this.modesLabel = '',
    this.pricePerHour = 0,
    this.currency = 'CLP',
    this.verified = false,
    this.featured = false,
    this.yearsExperience = 0,
    this.rating = 0,
    this.reviewCount = 0,
    // Solo presentes en el detalle (GET /tutors/:id)
    this.bio,
    this.ratingByCriterion = const [],
    this.highlightedReview,
    this.myReview,
    this.conversationId,
    this.contacted = false,
    this.canReview = false,
  });

  final String id;
  final String name;
  final String initials;
  final String avatarColor;
  final String textColor;
  final List<String> subjects;
  final String subjectsLabel;
  final List<String> modes; // online | in_person
  final String modesLabel;
  final int pricePerHour;
  final String currency;
  final bool verified;
  final bool featured;
  final int yearsExperience;
  final double rating;
  final int reviewCount;
  final String? bio;
  final List<CriterionValue> ratingByCriterion;
  final TutorReview? highlightedReview;
  final TutorReview? myReview;
  final String? conversationId;
  final bool contacted;
  final bool canReview;

  factory Tutor.fromJson(Map<String, dynamic> j) => Tutor(
        id: _str(j['id']),
        name: _str(j['name']),
        initials: _str(j['initials']),
        avatarColor: _str(j['avatarColor'], '#1A365D'),
        textColor: _str(j['textColor'], '#FFFFFF'),
        subjects: (j['subjects'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        subjectsLabel: _str(j['subjectsLabel']),
        modes: (j['modes'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        modesLabel: _str(j['modesLabel']),
        pricePerHour: _int(j['pricePerHour']),
        currency: _str(j['currency'], 'CLP'),
        verified: _bool(j['verified']),
        featured: _bool(j['featured']),
        yearsExperience: _int(j['yearsExperience']),
        rating: _double(j['rating']),
        reviewCount: _int(j['reviewCount']),
        bio: _as<String>(j['bio']),
        ratingByCriterion: _listMap(j['ratingByCriterion']).map(CriterionValue.fromJson).toList(),
        highlightedReview: _as<Map>(j['highlightedReview']) == null
            ? null
            : TutorReview.fromJson((j['highlightedReview'] as Map).cast<String, dynamic>()),
        myReview: _as<Map>(j['myReview']) == null
            ? null
            : TutorReview.fromJson((j['myReview'] as Map).cast<String, dynamic>()),
        conversationId: _as<String>(j['conversationId']),
        contacted: _bool(j['contacted']),
        canReview: _bool(j['canReview']),
      );
}

class TutorReview {
  const TutorReview({
    required this.id,
    required this.authorName,
    this.authorInitials = '',
    this.avatarColor = '#1A365D',
    this.overall = 0,
    this.comment = '',
    this.criteria = const [],
    this.createdAt,
  });
  final String id;
  final String authorName;
  final String authorInitials;
  final String avatarColor;
  final double overall;
  final String comment;
  final List<CriterionValue> criteria;
  final DateTime? createdAt;

  factory TutorReview.fromJson(Map<String, dynamic> j) {
    final author = _as<Map>(j['author'])?.cast<String, dynamic>() ?? const {};
    return TutorReview(
      id: _str(j['id']),
      authorName: _str(author['name']),
      authorInitials: _str(author['initials']),
      avatarColor: _str(author['avatarColor'], '#1A365D'),
      overall: _double(j['overall']),
      comment: _str(j['comment']),
      criteria: _listMap(j['criteria']).map(CriterionValue.fromJson).toList(),
      createdAt: DateTime.tryParse(_str(j['createdAt'])),
    );
  }
}

/// Página de reseñas + resumen que viaja en `meta.summary`.
class TutorReviewPage {
  const TutorReviewPage({
    this.reviews = const [],
    this.overall = 0,
    this.reviewCount = 0,
    this.byCriterion = const [],
    this.nextCursor,
  });
  final List<TutorReview> reviews;
  final double overall;
  final int reviewCount;
  final List<CriterionValue> byCriterion;
  final String? nextCursor;
}

/// Resultado de POST /tutors/:id/contact-requests.
class ContactRequestResult {
  const ContactRequestResult({required this.conversationId, this.created = false, this.requestId});
  final String conversationId;
  final bool created;
  final String? requestId;

  factory ContactRequestResult.fromJson(Map<String, dynamic> j) => ContactRequestResult(
        conversationId: _str(j['conversationId']),
        created: _bool(j['created']),
        requestId: _as<String>(j['requestId']),
      );
}

// ── Análisis de falencias (GET /me/gap-analysis) ─────────────────────────────

class GapArea {
  const GapArea({required this.area, this.mastery = 0, this.exercises = 0});
  final String area;
  final int mastery;
  final int exercises;

  factory GapArea.fromJson(Map<String, dynamic> j) => GapArea(
        area: _str(j['area']),
        mastery: _int(j['mastery']),
        exercises: _int(j['exercises']),
      );
}

class GapSubject {
  const GapSubject({
    required this.testId,
    required this.label,
    this.color = '#1A365D',
    this.mastery = 0,
    this.status = 'ok',
    this.exercises = 0,
    this.hasData = false,
    this.areasToReinforce = const [],
    this.recommendedTutorCount = 0,
  });
  final String testId;
  final String label;
  final String color;
  final int mastery;
  final String status; // critical | warning | ok
  final int exercises;
  final bool hasData;
  final List<GapArea> areasToReinforce;
  final int recommendedTutorCount;

  factory GapSubject.fromJson(Map<String, dynamic> j) => GapSubject(
        testId: _str(j['testId']),
        label: _str(j['label']),
        color: _str(j['color'], '#1A365D'),
        mastery: _int(j['mastery']),
        status: _str(j['status'], 'ok'),
        exercises: _int(j['exercises']),
        hasData: _bool(j['hasData']),
        areasToReinforce: _listMap(j['areasToReinforce']).map(GapArea.fromJson).toList(),
        recommendedTutorCount: _int(j['recommendedTutorCount']),
      );
}

class GapAnalysis {
  const GapAnalysis({this.basedOnExercises = 0, this.subjects = const [], this.generatedAt});
  final int basedOnExercises;
  final List<GapSubject> subjects;
  final DateTime? generatedAt;

  factory GapAnalysis.fromJson(Map<String, dynamic> j) => GapAnalysis(
        basedOnExercises: _int(j['basedOnExercises']),
        subjects: _listMap(j['subjects']).map(GapSubject.fromJson).toList(),
        generatedAt: DateTime.tryParse(_str(j['generatedAt'])),
      );
}

// ── Chat con tutores ────────────────────────────────────────────────────────

class Conversation {
  const Conversation({
    required this.id,
    required this.tutorId,
    required this.tutorName,
    this.tutorInitials = '',
    this.tutorColor = '#1A365D',
    this.lastMessagePreview = '',
    this.lastMessageAt,
    this.unreadCount = 0,
    this.lessonsTaken = 0,
    this.contactShared = false,
    this.tutorOnline = false,
  });
  final String id;
  final String tutorId;
  final String tutorName;
  final String tutorInitials;
  final String tutorColor;
  final String lastMessagePreview;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final int lessonsTaken;
  final bool contactShared;
  final bool tutorOnline;

  factory Conversation.fromJson(Map<String, dynamic> j) {
    final tutor = _as<Map>(j['tutor'])?.cast<String, dynamic>() ?? const {};
    return Conversation(
      id: _str(j['id']),
      tutorId: _str(tutor['id']),
      tutorName: _str(tutor['name']),
      tutorInitials: _str(tutor['initials']),
      tutorColor: _str(tutor['avatarColor'], '#1A365D'),
      lastMessagePreview: _str(j['lastMessagePreview']),
      lastMessageAt: DateTime.tryParse(_str(j['lastMessageAt'])),
      unreadCount: _int(j['unreadCount']),
      lessonsTaken: _int(j['lessonsTaken']),
      contactShared: _bool(j['contactShared']),
      tutorOnline: _bool(tutor['online']),
    );
  }
}

/// Estado de compartir contacto: solo se revela con consentimiento mutuo.
class ContactSharing {
  const ContactSharing({
    this.myConsent = false,
    this.tutorConsent = false,
    this.mutual = false,
    this.tutorWhatsapp,
    this.myWhatsapp,
  });
  final bool myConsent;
  final bool tutorConsent;
  final bool mutual;
  final String? tutorWhatsapp;
  final String? myWhatsapp;

  factory ContactSharing.fromJson(Map<String, dynamic> j) {
    final revealed = _as<Map>(j['revealed'])?.cast<String, dynamic>();
    return ContactSharing(
      myConsent: _bool(j['myConsent']),
      tutorConsent: _bool(j['tutorConsent']),
      mutual: _bool(j['mutual']),
      tutorWhatsapp: _as<String>(revealed?['tutorWhatsapp']),
      myWhatsapp: _as<String>(revealed?['myWhatsapp']),
    );
  }
}

/// Perfil del alumno compartido con el tutor al enviar la solicitud.
class SharedProfile {
  const SharedProfile({
    required this.name,
    this.initials = '',
    this.gradeLabel,
    this.goal,
    this.weakAreas = const [],
  });
  final String name;
  final String initials;
  final String? gradeLabel;
  final String? goal;
  final List<String> weakAreas;

  factory SharedProfile.fromJson(Map<String, dynamic> j) => SharedProfile(
        name: _str(j['name']),
        initials: _str(j['initials']),
        gradeLabel: _as<String>(j['gradeLabel']),
        goal: _as<String>(j['goal']),
        weakAreas: (j['weakAreas'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );
}

class ConversationDetail {
  const ConversationDetail({
    required this.id,
    required this.tutorId,
    required this.tutorName,
    this.tutorInitials = '',
    this.tutorColor = '#1A365D',
    this.tutorOnline = false,
    this.lessonsTaken = 0,
    this.unreadCount = 0,
    this.contactSharing = const ContactSharing(),
    this.sharedProfile,
  });
  final String id;
  final String tutorId;
  final String tutorName;
  final String tutorInitials;
  final String tutorColor;
  final bool tutorOnline;
  final int lessonsTaken;
  final int unreadCount;
  final ContactSharing contactSharing;
  final SharedProfile? sharedProfile;

  factory ConversationDetail.fromJson(Map<String, dynamic> j) {
    final tutor = _as<Map>(j['tutor'])?.cast<String, dynamic>() ?? const {};
    final sharing = _as<Map>(j['contactSharing'])?.cast<String, dynamic>();
    final profile = _as<Map>(j['sharedProfile'])?.cast<String, dynamic>();
    return ConversationDetail(
      id: _str(j['id']),
      tutorId: _str(tutor['id']),
      tutorName: _str(tutor['name']),
      tutorInitials: _str(tutor['initials']),
      tutorColor: _str(tutor['avatarColor'], '#1A365D'),
      tutorOnline: _bool(tutor['online']),
      lessonsTaken: _int(j['lessonsTaken']),
      unreadCount: _int(j['unreadCount']),
      contactSharing: sharing == null ? const ContactSharing() : ContactSharing.fromJson(sharing),
      sharedProfile: profile == null ? null : SharedProfile.fromJson(profile),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    this.mine = false,
    this.senderType = 'user',
    this.createdAt,
  });
  final String id;
  final String text;
  final bool mine;
  final String senderType; // user | tutor
  final DateTime? createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: _str(j['id']),
        text: _str(j['text']),
        mine: _bool(j['mine']),
        senderType: _str(j['senderType'], 'user'),
        createdAt: DateTime.tryParse(_str(j['createdAt'])),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Iteración 2 — Modelos de colecciones Firestore
// ─────────────────────────────────────────────────────────────────────────────

/// Documento de la colección `tests` (cinco pruebas PAES).
class FirestoreTest {
  const FirestoreTest({
    required this.id,
    required this.label,
    required this.color,
    this.hasQuestions = true,
  });
  final String id; // lectora | m1 | m2 | cien | hist
  final String label;
  final String color;
  final bool hasQuestions;

  factory FirestoreTest.fromJson(Map<String, dynamic> j) => FirestoreTest(
        id: _str(j['id']),
        label: _str(j['label']),
        color: _str(j['color'], '#1A365D'),
        hasQuestions: _bool(j['hasQuestions'], true),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'color': color,
        'hasQuestions': hasQuestions,
      };
}

/// Recurso de aprendizaje embebido en [FirestoreSkill].
class SkillResource {
  const SkillResource({
    required this.type,
    required this.title,
    this.url,
    this.duration,
    this.source,
  });

  /// Tipo de recurso: `video` | `pdf` | `exercise`.
  final String type;
  final String title;
  final String? url;
  final String? duration;
  final String? source;

  factory SkillResource.fromJson(Map<String, dynamic> j) => SkillResource(
        type: _str(j['type'], 'video'),
        title: _str(j['title']),
        url: _as<String>(j['url']),
        duration: _as<String>(j['duration']),
        source: _as<String>(j['source']),
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        if (url != null) 'url': url,
        if (duration != null) 'duration': duration,
        if (source != null) 'source': source,
      };
}

/// Documento de la colección `skills` (habilidad de una prueba).
class FirestoreSkill {
  const FirestoreSkill({
    required this.id,
    required this.name,
    required this.testId,
    required this.domain,
    this.level = 1,
    this.maxLevel = 4,
    this.prerequisiteIds = const [],
    this.status = 'active',
    this.resources = const [],
  });
  final String id;
  final String name;
  final String testId; // FK a tests
  final String domain;
  final int level;
  final int maxLevel;

  /// IDs de habilidades prerrequisito (árbol de dependencias).
  final List<String> prerequisiteIds;

  /// Estado del nodo en el árbol: `done` | `active` | `locked`.
  final String status;
  final List<SkillResource> resources;

  factory FirestoreSkill.fromJson(Map<String, dynamic> j) => FirestoreSkill(
        id: _str(j['id']),
        name: _str(j['name']),
        testId: _str(j['testId']),
        domain: _str(j['domain']),
        level: _int(j['level'], 1),
        maxLevel: _int(j['maxLevel'], 4),
        prerequisiteIds: (j['prerequisiteIds'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        status: _str(j['status'], 'active'),
        resources:
            _listMap(j['resources']).map(SkillResource.fromJson).toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'testId': testId,
        'domain': domain,
        'level': level,
        'maxLevel': maxLevel,
        'prerequisiteIds': prerequisiteIds,
        'status': status,
        'resources': resources.map((r) => r.toJson()).toList(),
      };
}

/// Documento de `answers` o `users/{uid}/answers` (respuesta inmutable del alumno).
class FirestoreAnswer {
  const FirestoreAnswer({
    required this.id,
    this.userId,
    required this.questionId,
    required this.selected,
    required this.correct,
    required this.elapsedMs,
    this.cohortPercentile,
    required this.answeredAt,
  });
  final String id;
  final String? userId;
  final String questionId;
  final String selected; // letra A–E
  final bool correct;
  final int elapsedMs;
  final int? cohortPercentile;
  final DateTime answeredAt;

  factory FirestoreAnswer.fromJson(Map<String, dynamic> j) => FirestoreAnswer(
        id: _str(j['id']),
        userId: _as<String>(j['userId']),
        questionId: _str(j['questionId']),
        selected: _str(j['selected']),
        correct: _bool(j['correct']),
        elapsedMs: _int(j['elapsedMs']),
        cohortPercentile: _as<int>(j['cohortPercentile']),
        answeredAt: DateTime.tryParse(_str(j['answeredAt'])) ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        if (userId != null) 'userId': userId,
        'questionId': questionId,
        'selected': selected,
        'correct': correct,
        'elapsedMs': elapsedMs,
        if (cohortPercentile != null) 'cohortPercentile': cohortPercentile,
        'answeredAt': answeredAt.toIso8601String(),
      };
}

/// Documento de `users/{uid}/medalLedger` (movimiento de medallas).
/// Solo el backend escribe en esta subcolección.
class MedalLedgerEntry {
  const MedalLedgerEntry({
    required this.id,
    required this.type,
    required this.tier,
    required this.amount,
    this.referenceId,
    required this.createdAt,
  });
  final String id;

  /// Tipo de movimiento: `answer_correct` | `correction_confirmed` | `exchange` | `gift`.
  final String type;

  /// Tier afectado: `bronze` | `silver` | `gold` | `diamond` | `platinum`.
  final String tier;

  /// Positivo = ganó medallas, negativo = gastó (intercambio/regalo).
  final int amount;

  /// Referencia opcional (questionId, correctionId, etc.).
  final String? referenceId;
  final DateTime createdAt;

  factory MedalLedgerEntry.fromJson(Map<String, dynamic> j) =>
      MedalLedgerEntry(
        id: _str(j['id']),
        type: _str(j['type']),
        tier: _str(j['tier'], 'bronze'),
        amount: _int(j['amount']),
        referenceId: _as<String>(j['referenceId']),
        createdAt:
            DateTime.tryParse(_str(j['createdAt'])) ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'tier': tier,
        'amount': amount,
        if (referenceId != null) 'referenceId': referenceId,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// Estado de cuota del usuario con bonificaciones extensibles.
///
/// Similar a [QuotaState] pero con `bonuses` como mapa abierto para que el
/// backend pueda agregar nuevas bonificaciones sin tocar el cliente.
class UserQuotaState {
  const UserQuotaState({
    required this.used,
    required this.max,
    this.base = 10,
    this.bonuses = const {},
    this.unlimited = false,
    this.resetsAt,
  });
  final int used;
  final int max;
  final int base;

  /// Mapa extensible de bonificaciones activas: `{'school': true, 'address': false}`.
  final Map<String, bool> bonuses;
  final bool unlimited;
  final DateTime? resetsAt;

  factory UserQuotaState.fromJson(Map<String, dynamic> j) {
    final b = _as<Map>(j['bonuses'])?.cast<String, dynamic>() ?? const {};
    return UserQuotaState(
      used: _int(j['used']),
      max: _int(j['max'], 10),
      base: _int(j['base'], 10),
      bonuses: b.map((k, v) => MapEntry(k, _bool(v))),
      unlimited: _bool(j['unlimited']),
      resetsAt: DateTime.tryParse(_str(j['resetsAt'])),
    );
  }

  Map<String, dynamic> toJson() => {
        'used': used,
        'max': max,
        'base': base,
        'bonuses': bonuses,
        'unlimited': unlimited,
        if (resetsAt != null) 'resetsAt': resetsAt!.toIso8601String(),
      };
}
