import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/models.dart';
import '../../providers/data_providers.dart';
import '../../providers/tutors_providers.dart';
import 'tutor_widgets.dart';

/// Marketplace de tutores (pantalla `tutors` del wireframe).
class TutorsScreen extends ConsumerStatefulWidget {
  const TutorsScreen({super.key});

  @override
  ConsumerState<TutorsScreen> createState() => _TutorsScreenState();
}

class _TutorsScreenState extends ConsumerState<TutorsScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(tutorFiltersProvider).query ?? '';
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final filters = ref.watch(tutorFiltersProvider);
    // Sin filtros se muestran los destacados; con filtros, el resultado de la
    // busqueda. Son dos endpoints distintos del backend.
    final hasFilters = filters.subject != null ||
        filters.mode != null ||
        filters.verifiedOnly ||
        (filters.query ?? '').trim().isNotEmpty;
    final tutors = hasFilters ? ref.watch(tutorsProvider) : ref.watch(featuredTutorsProvider);
    final tests = ref.watch(testsProvider).valueOrNull ?? const <TestInfo>[];
    final unread = ref.watch(unreadMessagesProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              Text(context.s('tut_tab'),
                  style: const TextStyle(
                      fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: 17)),
              const Spacer(),
              IconButton(
                tooltip: context.s('tut_chats'),
                onPressed: () => context.push('/tutors/chats'),
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(Icons.forum_rounded),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) => ref.read(tutorFiltersProvider.notifier).setQuery(value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                hintText: context.s('tut_search'),
                suffixIcon: (filters.query ?? '').isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _search.clear();
                          ref.read(tutorFiltersProvider.notifier).setQuery('');
                        },
                      ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(children: [
              for (final test in tests)
                SelectChip(
                  label: test.label,
                  selected: filters.subject == test.id,
                  color: colorFromHex(test.color),
                  onTap: () => ref.read(tutorFiltersProvider.notifier).toggleSubject(test.id),
                ),
              SelectChip(
                label: context.s('tut_online'),
                selected: filters.mode == 'online',
                onTap: () => ref.read(tutorFiltersProvider.notifier).toggleMode('online'),
              ),
              SelectChip(
                label: context.s('tut_in_person'),
                selected: filters.mode == 'in_person',
                onTap: () => ref.read(tutorFiltersProvider.notifier).toggleMode('in_person'),
              ),
              SelectChip(
                label: context.s('tut_verified'),
                selected: filters.verifiedOnly,
                onTap: () => ref
                    .read(tutorFiltersProvider.notifier)
                    .setVerifiedOnly(!filters.verifiedOnly),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Row(children: [
              Text(context.s('tut_sort'), style: TextStyle(fontSize: 12, color: t.muted)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: filters.sort,
                underline: const SizedBox.shrink(),
                style: TextStyle(fontSize: 12, color: t.ink, fontWeight: FontWeight.w600),
                items: [
                  DropdownMenuItem(value: 'rating', child: Text(context.s('tut_sort_rating'))),
                  DropdownMenuItem(value: 'price_asc', child: Text(context.s('tut_sort_price'))),
                  DropdownMenuItem(
                      value: 'experience', child: Text(context.s('tut_sort_experience'))),
                ],
                onChanged: (value) {
                  if (value != null) ref.read(tutorFiltersProvider.notifier).setSort(value);
                },
              ),
            ]),
          ),
          Expanded(
            child: AsyncValueView<List<Tutor>>(
              value: tutors,
              onRetry: () {
                ref.invalidate(tutorsProvider);
                ref.invalidate(featuredTutorsProvider);
              },
              data: (list) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(tutorsProvider);
                  ref.invalidate(featuredTutorsProvider);
                  ref.invalidate(conversationsProvider);
                  await ref.read(
                      hasFilters ? tutorsProvider.future : featuredTutorsProvider.future);
                },
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  const _GapAnalysisCard(),
                  const SizedBox(height: 14),
                  Text(context.s(hasFilters ? 'tut_results' : 'tut_featured'),
                      style: const TextStyle(
                          fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 8),
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(context.s('tut_empty'),
                          textAlign: TextAlign.center, style: TextStyle(color: t.muted)),
                    ),
                  for (final tutor in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TutorCard(tutor: tutor),
                    ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _GapAnalysisCard extends StatelessWidget {
  const _GapAnalysisCard();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SoftCard(
      onTap: () => context.push('/tutors/analysis'),
      borderColor: AppColors.oro,
      background: AppColors.oro.withOpacity(.09),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🎯', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.s('tut_gap_h'),
                  style: const TextStyle(
                      fontFamily: 'Montserrat', fontWeight: FontWeight.w700, fontSize: 13)),
              Text(context.s('tut_gap_p'), style: TextStyle(fontSize: 11, color: t.muted)),
            ]),
          ),
        ]),
        const SizedBox(height: 9),
        PrimaryButton(
          label: context.s('tut_gap_cta'),
          onPressed: () => context.push('/tutors/analysis'),
        ),
      ]),
    );
  }
}

/// Tarjeta de tutor reutilizada en el listado y en los recomendados.
class TutorCard extends StatelessWidget {
  const TutorCard({super.key, required this.tutor});
  final Tutor tutor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final localeCode = Localizations.localeOf(context).languageCode;
    return SoftCard(
      onTap: () => context.push('/tutors/${tutor.id}'),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InitialsAvatar(
            initials: tutor.initials,
            background: tutor.avatarColor,
            foreground: tutor.textColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(tutor.name,
                      style: const TextStyle(
                          fontFamily: 'Montserrat', fontWeight: FontWeight.w700, fontSize: 14)),
                ),
                if (tutor.verified) Tag('✔ ${context.s('tut_verified')}', variant: 'g'),
              ]),
              const SizedBox(height: 2),
              Text('${tutor.subjectsLabel} · ${tutor.modesLabel}',
                  style: TextStyle(fontSize: 11, color: t.muted)),
              const SizedBox(height: 5),
              Row(children: [
                StarRating(tutor.rating, size: 12),
                const SizedBox(width: 6),
                Text(tutor.rating.toStringAsFixed(1),
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Montserrat')),
                const SizedBox(width: 4),
                Text('(${tutor.reviewCount})', style: TextStyle(fontSize: 11, color: t.muted)),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Text(tutorPrice(tutor, localeCode),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Montserrat',
                  color: t.brand)),
          Text(' / ${context.s('tut_hour')}', style: TextStyle(fontSize: 11, color: t.muted)),
          const Spacer(),
          Text('${context.s('tut_view_profile')} ›',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Montserrat',
                  color: t.brand)),
        ]),
      ]),
    );
  }
}
