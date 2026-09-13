import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/models.dart';
import '../../providers/app_providers.dart';
import '../../providers/tutors_providers.dart';
import 'tutor_widgets.dart';

/// Dejar reseña: 1–5 estrellas en los tres criterios (pantalla `tutor-review`).
class TutorReviewScreen extends ConsumerStatefulWidget {
  const TutorReviewScreen({super.key, required this.tutorId});
  final String tutorId;

  @override
  ConsumerState<TutorReviewScreen> createState() => _TutorReviewScreenState();
}

class _TutorReviewScreenState extends ConsumerState<TutorReviewScreen> {
  final _comment = TextEditingController();
  int _teaching = 0;
  int _punctuality = 0;
  int _mastery = 0;
  bool _busy = false;

  bool get _complete => _teaching > 0 && _punctuality > 0 && _mastery > 0;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (!_complete) return;
    setState(() => _busy = true);
    try {
      await ref.read(tutorsRepositoryProvider).publishReview(
            tutorId: widget.tutorId,
            teaching: _teaching,
            punctuality: _punctuality,
            mastery: _mastery,
            comment: _comment.text,
          );
      if (!mounted) return;
      ref.invalidate(tutorDetailProvider(widget.tutorId));
      ref.invalidate(tutorReviewsProvider(widget.tutorId));
      ref.invalidate(tutorsProvider);
      ref.invalidate(featuredTutorsProvider);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.s('tut_review_published'))));
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tutor = ref.watch(tutorDetailProvider(widget.tutorId));
    final t = context.tokens;
    // Las etiquetas de los criterios las define el backend (es/en).
    final labels = tutor.valueOrNull?.ratingByCriterion ?? const <CriterionValue>[];
    String labelFor(String key, String fallback) =>
        labels.firstWhere((c) => c.key == key, orElse: () => CriterionValue(key: key, label: fallback)).label;

    return Scaffold(
      appBar: AppBar(title: Text(context.s('tut_rate_h'))),
      body: SafeArea(
        child: AsyncValueView<Tutor>(
          value: tutor,
          onRetry: () => ref.invalidate(tutorDetailProvider(widget.tutorId)),
          data: (data) => Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Row(children: [
                  InitialsAvatar(
                    initials: data.initials,
                    background: data.avatarColor,
                    foreground: data.textColor,
                    size: 40,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(data.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      Text(data.subjectsLabel, style: TextStyle(fontSize: 11, color: t.muted)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(context.s('tut_rate_p'), style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 12),
                _CriterionCard(
                  label: labelFor('teaching', context.s('tut_crit_teaching')),
                  value: _teaching,
                  onChanged: (v) => setState(() => _teaching = v),
                ),
                _CriterionCard(
                  label: labelFor('punctuality', context.s('tut_crit_punctuality')),
                  value: _punctuality,
                  onChanged: (v) => setState(() => _punctuality = v),
                ),
                _CriterionCard(
                  label: labelFor('mastery', context.s('tut_crit_mastery')),
                  value: _mastery,
                  onChanged: (v) => setState(() => _mastery = v),
                ),
                const SizedBox(height: 8),
                Text(context.s('tut_comment_optional'),
                    style: const TextStyle(
                        fontFamily: 'Montserrat', fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: _comment,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 1000,
                  decoration: InputDecoration(hintText: context.s('tut_comment_hint')),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: PrimaryButton(
                label: context.s('tut_publish_review'),
                onPressed: (_busy || !_complete) ? null : _publish,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _CriterionCard extends StatelessWidget {
  const _CriterionCard({required this.label, required this.value, required this.onChanged});
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Montserrat', fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 4),
          Row(children: [
            StarPicker(value: value, onChanged: onChanged),
            const Spacer(),
            if (value > 0)
              Text('$value/5',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.oro)),
          ]),
        ]),
      ),
    );
  }
}
