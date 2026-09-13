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

/// Perfil del profesor (pantalla `tutor-profile`).
class TutorProfileScreen extends ConsumerWidget {
  const TutorProfileScreen({super.key, required this.tutorId});
  final String tutorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tutor = ref.watch(tutorDetailProvider(tutorId));
    final isPaid = ref.watch(isPaidPlanProvider);
    final t = context.tokens;
    final localeCode = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(context.s('tut_profile_h'))),
      body: SafeArea(
        child: AsyncValueView<Tutor>(
          value: tutor,
          onRetry: () => ref.invalidate(tutorDetailProvider(tutorId)),
          data: (data) => Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  InitialsAvatar(
                    initials: data.initials,
                    background: data.avatarColor,
                    foreground: data.textColor,
                    size: 60,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(
                          child: Text(data.name,
                              style: const TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16)),
                        ),
                        if (data.verified) Tag('✔ ${context.s('tut_verified')}', variant: 'g'),
                      ]),
                      Text('${data.subjectsLabel} · ${data.modesLabel}',
                          style: TextStyle(fontSize: 11, color: t.muted)),
                      const SizedBox(height: 4),
                      Row(children: [
                        StarRating(data.rating),
                        const SizedBox(width: 6),
                        Text(data.rating.toStringAsFixed(1),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'Montserrat')),
                        const SizedBox(width: 4),
                        Text('(${data.reviewCount} ${context.s('tut_reviews')})',
                            style: TextStyle(fontSize: 11, color: t.muted)),
                      ]),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Text(tutorPrice(data, localeCode),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Montserrat',
                          color: t.brand)),
                  Text(' / ${context.s('tut_hour')}',
                      style: TextStyle(fontSize: 11, color: t.muted)),
                  const Spacer(),
                  Tag('🎓 ${data.yearsExperience} ${context.s('tut_years')}'),
                ]),
                if ((data.bio ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(data.bio!, style: const TextStyle(fontSize: 13, height: 1.4)),
                ],
                const SizedBox(height: 18),
                Text(context.s('tut_by_criterion'),
                    style: const TextStyle(
                        fontFamily: 'Montserrat', fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 6),
                for (final criterion in data.ratingByCriterion)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(children: [
                      Expanded(
                          child: Text(criterion.label,
                              style: TextStyle(fontSize: 12, color: t.muted))),
                      StarRating(criterion.value ?? 0, size: 12),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 26,
                        child: Text((criterion.value ?? 0).toStringAsFixed(1),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Montserrat')),
                      ),
                    ]),
                  ),
                const SizedBox(height: 14),
                Row(children: [
                  Text(context.s('tut_reviews'),
                      style: const TextStyle(
                          fontFamily: 'Montserrat', fontWeight: FontWeight.w700, fontSize: 14)),
                  const Spacer(),
                  InkWell(
                    onTap: () => context.push('/tutors/$tutorId/reviews'),
                    child: Text('${context.s('tut_see_all')} (${data.reviewCount}) →',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Montserrat',
                            color: t.brand)),
                  ),
                ]),
                const SizedBox(height: 8),
                if (data.highlightedReview != null)
                  _ReviewTile(review: data.highlightedReview!)
                else
                  Text(context.s('tut_no_reviews'), style: TextStyle(fontSize: 12, color: t.muted)),
                if (data.canReview) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/tutors/$tutorId/review'),
                    icon: const Icon(Icons.star_rounded, size: 18, color: AppColors.oro),
                    label: Text('${context.s('tut_rate')} ${data.name}'),
                  ),
                ],
                if (data.myReview != null) ...[
                  const SizedBox(height: 12),
                  Text(context.s('tut_my_review'),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  _ReviewTile(review: data.myReview!),
                ],
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                if (!isPaid)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PremiumNotice(
                      message: context.s('tut_premium_contact'),
                      cta: context.s('up_cta'),
                      onUpgrade: () => context.push('/paywall'),
                    ),
                  ),
                if (data.contacted && data.conversationId != null)
                  PrimaryButton(
                    label: context.s('tut_open_chat'),
                    icon: Icons.forum_rounded,
                    onPressed: () => context.push('/tutors/chats/${data.conversationId}'),
                  )
                else
                  PrimaryButton(
                    label: context.s('tut_contact'),
                    onPressed: () => isPaid
                        ? context.push('/tutors/$tutorId/contact')
                        : context.push('/paywall'),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});
  final TutorReview review;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final localeCode = Localizations.localeOf(context).languageCode;
    return SoftCard(
      padding: const EdgeInsets.all(11),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          InitialsAvatar(
            initials: review.authorInitials.isEmpty
                ? initialsFrom(review.authorName, fallback: '?')
                : review.authorInitials,
            background: review.avatarColor,
            size: 28,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(review.authorName,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              Text(relativeDate(review.createdAt, localeCode),
                  style: TextStyle(fontSize: 10, color: t.muted)),
            ]),
          ),
          StarRating(review.overall, size: 11),
        ]),
        if (review.criteria.isNotEmpty) ...[
          const SizedBox(height: 7),
          Wrap(spacing: 10, runSpacing: 4, children: [
            for (final c in review.criteria)
              Text('${c.label.split(' ').first}: ${(c.value ?? 0).toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 10, color: t.muted)),
          ]),
        ],
        if (review.comment.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('"${review.comment}"', style: const TextStyle(fontSize: 12, height: 1.35)),
        ],
      ]),
    );
  }
}

/// Todas las reseñas (pantalla `tutor-reviews`).
class TutorReviewsScreen extends ConsumerWidget {
  const TutorReviewsScreen({super.key, required this.tutorId});
  final String tutorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(tutorReviewsProvider(tutorId));
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: Text(context.s('tut_reviews'))),
      body: SafeArea(
        child: AsyncValueView<TutorReviewPage>(
          value: page,
          onRetry: () => ref.invalidate(tutorReviewsProvider(tutorId)),
          data: (data) => ListView(padding: const EdgeInsets.all(16), children: [
            SoftCard(
              borderColor: t.brand,
              background: t.brand.withOpacity(.05),
              child: Column(children: [
                Text(data.overall.toStringAsFixed(1),
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Montserrat',
                        color: t.brand)),
                StarRating(data.overall, size: 16),
                const SizedBox(height: 4),
                Text('${data.reviewCount} ${context.s('tut_verified_reviews')}',
                    style: TextStyle(fontSize: 11, color: t.muted)),
              ]),
            ),
            const SizedBox(height: 14),
            Text(context.s('tut_avg_criterion'),
                style: const TextStyle(
                    fontFamily: 'Montserrat', fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 6),
            for (final c in data.byCriterion)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Expanded(child: Text(c.label, style: TextStyle(fontSize: 12, color: t.muted))),
                  StarRating(c.value ?? 0, size: 11),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 26,
                    child: Text((c.value ?? 0).toStringAsFixed(1),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Montserrat')),
                  ),
                ]),
              ),
            const SizedBox(height: 14),
            Text(context.s('tut_opinions'),
                style: const TextStyle(
                    fontFamily: 'Montserrat', fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            if (data.reviews.isEmpty)
              Text(context.s('tut_no_reviews'), style: TextStyle(fontSize: 12, color: t.muted)),
            for (final review in data.reviews)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ReviewTile(review: review),
              ),
          ]),
        ),
      ),
    );
  }
}
