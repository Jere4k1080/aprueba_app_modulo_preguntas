import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/models.dart';
import '../../data/services/phone_auth_service.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_controller.dart';
import '../../providers/catalog_providers.dart';
import 'education_catalog.dart';
import 'onboarding_state.dart';

bool _isEnglish(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'en';

String _copy(BuildContext context, String es, String en) =>
    _isEnglish(context) ? en : es;

void _toast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

/// Paso 1: número de teléfono. El backend valida el formato y deduce
/// país/idioma; el SMS lo envía Firebase Auth desde el propio dispositivo.
class PhoneNumberScreen extends ConsumerStatefulWidget {
  const PhoneNumberScreen({super.key});

  @override
  ConsumerState<PhoneNumberScreen> createState() => _PhoneNumberScreenState();
}

class _PhoneNumberScreenState extends ConsumerState<PhoneNumberScreen> {
  late final TextEditingController _phone;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _phone = TextEditingController(text: ref.read(onboardingProvider).phone);
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final compact = _phone.text.trim().replaceAll(RegExp(r'[\s()-]'), '');
    if (!compact.startsWith('+') || compact.length < 9) {
      _toast(context,
          _copy(context, 'Ingresa un numero con codigo de pais.', 'Enter a number including the country code.'));
      return;
    }
    setState(() => _busy = true);
    final notifier = ref.read(onboardingProvider.notifier);
    try {
      // 1. El backend valida el numero y devuelve pais/idioma detectados.
      final hint = await ref.read(authControllerProvider.notifier).startPhoneVerification(compact);
      notifier.setPhone(hint.phone.isEmpty ? compact : hint.phone);
      notifier.applyDetectedLocale(country: hint.detectedCountry, language: hint.detectedLanguage);
      if (hint.detectedLanguage != null) {
        await ref.read(localeControllerProvider.notifier).set(hint.detectedLanguage!);
      }
      if (hint.accountExists && mounted) {
        _toast(
            context,
            _copy(context, 'Ya existe una cuenta con este numero. Puedes iniciar sesion.',
                'An account already uses this number. You can log in instead.'));
      }

      // 2. Firebase envia el SMS (se omite en modo desarrollo).
      final request = await ref.read(phoneAuthServiceProvider).sendCode(compact);
      notifier.codeSent(verificationId: request.verificationId, resendToken: request.resendToken);

      // Android puede resolver la verificacion sin pedir el codigo.
      if (request.autoVerified) {
        final verification = await ref
            .read(authControllerProvider.notifier)
            .confirmPhoneVerification(firebaseIdToken: request.autoIdToken!, phone: compact);
        notifier.verifyPhone(verification.phoneToken);
        notifier.applyDetectedLocale(country: verification.country, language: verification.language);
        if (mounted) context.push('/onboarding/locale');
        return;
      }
      if (mounted) context.push('/onboarding/verify-phone');
    } on ApiException catch (e) {
      if (mounted) _toast(context, e.message);
    } on PhoneAuthException catch (e) {
      if (mounted) _toast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final devMode = ref.watch(phoneAuthServiceProvider).isDevMode;
    return Scaffold(
      appBar: AppBar(title: Text(_copy(context, 'Tu numero de telefono', 'Your phone number'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const _StepLabel('1 / 6'),
            const SizedBox(height: 8),
            Text(
              _copy(
                context,
                'Lo usaremos para verificar tu cuenta y configurar tu pais e idioma.',
                'We will use it to verify your account and set your country and language.',
              ),
              style: TextStyle(color: context.tokens.muted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ()-]'))],
              decoration: const InputDecoration(hintText: '+56 9 1234 5678'),
            ),
            const SizedBox(height: 8),
            Text(
              _copy(context, 'Incluye el codigo de pais. Solo enviaremos un SMS de verificacion.',
                  'Include the country code. We will only send a verification SMS.'),
              style: TextStyle(fontSize: 12, color: context.tokens.muted),
            ),
            if (devMode) ...[
              const SizedBox(height: 10),
              SoftCard(
                borderColor: AppColors.oro,
                child: Row(children: [
                  const Icon(Icons.construction_rounded, size: 18, color: AppColors.oro),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _copy(context, 'Modo desarrollo: no se envia SMS real, cualquier codigo sirve.',
                          'Dev mode: no real SMS is sent, any code works.'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ]),
              ),
            ],
            const Spacer(),
            PrimaryButton(
              label: _copy(context, 'Enviar codigo por SMS', 'Send SMS code'),
              onPressed: _busy ? null : _sendCode,
            ),
          ]),
        ),
      ),
    );
  }
}

/// Paso 2: código SMS. Firebase lo canjea por un idToken y el backend cambia ese
/// idToken por el phoneToken que consume el registro.
class VerifyPhoneScreen extends ConsumerStatefulWidget {
  const VerifyPhoneScreen({super.key});

  @override
  ConsumerState<VerifyPhoneScreen> createState() => _VerifyPhoneScreenState();
}

class _VerifyPhoneScreenState extends ConsumerState<VerifyPhoneScreen> {
  final _code = TextEditingController();
  bool _busy = false;

  Future<void> _resend() async {
    final state = ref.read(onboardingProvider);
    setState(() => _busy = true);
    try {
      final request = await ref
          .read(phoneAuthServiceProvider)
          .sendCode(state.phone, resendToken: state.resendToken);
      if (!mounted) return;
      final notifier = ref.read(onboardingProvider.notifier);
      notifier.codeSent(
        verificationId: request.verificationId,
        resendToken: request.resendToken,
      );
      // Android puede auto-verificar al reenviar: se aprovecha ese idToken.
      if (request.autoVerified) {
        final verification = await ref
            .read(authControllerProvider.notifier)
            .confirmPhoneVerification(firebaseIdToken: request.autoIdToken!, phone: state.phone);
        if (!mounted) return;
        notifier.verifyPhone(verification.phoneToken);
        notifier.applyDetectedLocale(country: verification.country, language: verification.language);
        context.push('/onboarding/locale');
        return;
      }
      _toast(context, _copy(context, 'Codigo reenviado.', 'Code resent.'));
    } on ApiException catch (e) {
      if (mounted) _toast(context, e.message);
    } on PhoneAuthException catch (e) {
      if (mounted) _toast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final state = ref.read(onboardingProvider);
    final code = _code.text.trim();
    if (code.length != 6) {
      _toast(context, _copy(context, 'Ingresa los 6 digitos del codigo.', 'Enter the 6-digit code.'));
      return;
    }
    setState(() => _busy = true);
    try {
      final idToken = await ref.read(phoneAuthServiceProvider).confirmCode(
            verificationId: state.verificationId,
            code: code,
            phone: state.phone,
          );
      final verification = await ref
          .read(authControllerProvider.notifier)
          .confirmPhoneVerification(firebaseIdToken: idToken, phone: state.phone);
      if (verification.phoneToken.isEmpty) throw StateError('missing phoneToken');

      final notifier = ref.read(onboardingProvider.notifier);
      notifier.verifyPhone(verification.phoneToken);
      notifier.applyDetectedLocale(country: verification.country, language: verification.language);
      if (verification.language != null) {
        await ref.read(localeControllerProvider.notifier).set(verification.language!);
      }
      // La sesion de Firebase solo probaba el telefono; la sesion real son los
      // tokens del backend.
      await ref.read(phoneAuthServiceProvider).signOut();
      if (mounted) context.push('/onboarding/locale');
    } on ApiException catch (e) {
      if (mounted) _toast(context, e.message);
    } on PhoneAuthException catch (e) {
      if (mounted) _toast(context, e.message);
    } on StateError {
      if (mounted) {
        _toast(
            context,
            _copy(context, 'El servicio no confirmo el telefono. Intentalo de nuevo.',
                'The service did not confirm the phone. Please try again.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = ref.watch(onboardingProvider).phone;
    final devMode = ref.watch(phoneAuthServiceProvider).isDevMode;
    return Scaffold(
      appBar: AppBar(title: Text(_copy(context, 'Verifica tu telefono', 'Verify your phone'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const _StepLabel('2 / 6'),
            const SizedBox(height: 8),
            Text(
              _copy(context, 'Enviamos un codigo de 6 digitos a $phone.',
                  'We sent a 6-digit code to $phone.'),
              style: TextStyle(color: context.tokens.muted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 7),
              decoration: InputDecoration(
                hintText: '123456',
                counterText: '',
                hintStyle: TextStyle(color: context.tokens.muted),
              ),
            ),
            if (devMode)
              Text(
                _copy(context, 'Modo desarrollo: usa 123456.', 'Dev mode: use 123456.'),
                style: TextStyle(fontSize: 12, color: context.tokens.muted),
              ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => context.pop(),
                  child: Text(_copy(context, 'Cambiar numero', 'Change number')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _resend,
                  child: Text(context.s('tut_resend')),
                ),
              ),
            ]),
            const Spacer(),
            PrimaryButton(
              label: _copy(context, 'Verificar numero', 'Verify number'),
              onPressed: _busy ? null : _verify,
            ),
          ]),
        ),
      ),
    );
  }
}

/// Paso 3: país e idioma (GET /countries).
class LocaleConfirmationScreen extends ConsumerWidget {
  const LocaleConfirmationScreen({super.key});

  Future<void> _continue(BuildContext context, WidgetRef ref) async {
    final state = ref.read(onboardingProvider);
    await ref.read(localeControllerProvider.notifier).set(state.locale);
    if (context.mounted) context.push('/onboarding/grade');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final countries = ref.watch(countriesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(_copy(context, 'Confirma tu configuracion', 'Confirm your settings'))),
      body: SafeArea(
        child: AsyncValueView<List<Country>>(
          value: countries,
          onRetry: () => ref.invalidate(countriesProvider),
          data: (list) {
            const fallback = Country(code: 'CL', name: 'Chile', dialCode: '+56');
            final selected = list.firstWhere(
              (c) => c.code == state.countryCode,
              orElse: () => list.isEmpty ? fallback : list.first,
            );
            final languages =
                selected.languages.isEmpty ? const ['es'] : selected.languages;
            final language =
                languages.contains(state.locale) ? state.locale : languages.first;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const _StepLabel('3 / 6'),
                const SizedBox(height: 8),
                Text(
                  _copy(
                    context,
                    'Detectamos esta configuracion a partir de tu numero. Puedes corregirla antes de seguir.',
                    'We detected these settings from your number. You can correct them before continuing.',
                  ),
                  style: TextStyle(color: context.tokens.muted),
                ),
                const SizedBox(height: 16),
                Text(_copy(context, 'Pais', 'Country'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selected.code,
                  items: [
                    for (final c in list)
                      DropdownMenuItem(value: c.code, child: Text('${c.name} (${c.dialCode})')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    ref.read(onboardingProvider.notifier).setCountry(value);
                  },
                ),
                const SizedBox(height: 16),
                Text(_copy(context, 'Idioma de la app', 'App language'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: language,
                  items: [
                    for (final lang in languages)
                      DropdownMenuItem(
                          value: lang, child: Text(lang == 'en' ? 'English' : 'Espanol')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    ref.read(onboardingProvider.notifier).setLocale(value);
                  },
                ),
                const SizedBox(height: 16),
                SoftCard(
                  child: Row(children: [
                    Text(selected.flag.isEmpty ? '🌐' : selected.flag,
                        style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(selected.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        '${_copy(context, 'Idioma', 'Language')}: ${language == 'en' ? 'English' : 'Espanol'}',
                        style: TextStyle(fontSize: 12, color: context.tokens.muted),
                      ),
                    ]),
                  ]),
                ),
                const Spacer(),
                PrimaryButton(
                  label: _copy(context, 'Confirmar y elegir grado', 'Confirm and choose school stage'),
                  onPressed: () => _continue(context, ref),
                ),
              ]),
            );
          },
        ),
      ),
    );
  }
}

/// Paso 4: grado o prueba (GET /countries/:code/grades).
class EducationStageScreen extends ConsumerWidget {
  const EducationStageScreen({super.key});

  Future<void> _continue(BuildContext context, WidgetRef ref) async {
    final state = ref.read(onboardingProvider);
    if (state.gradeId == null || state.gradeLabel == null) return;
    await ref.read(localPrefsProvider.notifier).setEducation(
          countryCode: state.countryCode,
          gradeId: state.gradeId!,
          gradeLabel: state.gradeLabel!,
        );
    if (context.mounted) context.push('/onboarding/tests');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final country = EducationCatalog.normalizeCountry(state.countryCode);
    final grades = ref.watch(gradesProvider(country));
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(
          title: Text(_copy(context, 'Elige tu grado o prueba', 'Choose your school stage or exam'))),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: AsyncValueView<List<GradeGroup>>(
              value: grades,
              onRetry: () => ref.invalidate(gradesProvider(country)),
              data: (groups) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  const _StepLabel('4 / 6'),
                  const SizedBox(height: 8),
                  Text(
                    _copy(
                      context,
                      'Mostraremos contenidos desde educacion basica hasta las pruebas nacionales.',
                      'We will show content from primary school to national qualifications.',
                    ),
                    style: TextStyle(color: t.muted),
                  ),
                  for (final group in groups) ...[
                    const SizedBox(height: 18),
                    Text(group.label,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: t.muted)),
                    const SizedBox(height: 6),
                    for (final level in group.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SoftCard(
                          onTap: () => ref
                              .read(onboardingProvider.notifier)
                              .setGrade(id: level.id, label: level.label),
                          borderColor: state.gradeId == level.id ? t.brand : null,
                          background: state.gradeId == level.id ? t.brand.withOpacity(.07) : null,
                          child: Row(children: [
                            Icon(
                              state.gradeId == level.id
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              size: 20,
                              color: state.gradeId == level.id ? t.brand : t.muted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(level.label,
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                            ),
                            if (level.kind == 'exam')
                              Tag(_copy(context, 'Prueba', 'Exam'), variant: 'w'),
                          ]),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: PrimaryButton(
              label: _copy(context, 'Continuar a asignaturas', 'Continue to subjects'),
              onPressed: state.gradeId == null ? null : () => _continue(context, ref),
            ),
          ),
        ]),
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel(this.value);
  final String value;

  @override
  Widget build(BuildContext context) => Text(value,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: context.tokens.muted,
      ));
}
