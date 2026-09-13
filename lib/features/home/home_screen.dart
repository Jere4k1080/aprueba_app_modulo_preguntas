import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/medal_coin.dart';
import '../../data/models/models.dart';
import '../../providers/data_providers.dart';
import '../../providers/practice_session.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _startPractice(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(practiceSessionProvider.notifier).loadNext();
      router.push('/practice/question');
    } on ApiException catch (e) {
      if (e.isQuotaExhausted) {
        router.push('/paywall');
      } else {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final t = context.tokens;
    return Scaffold(
      body: SafeArea(
        child: AsyncValueView<User>(
          value: me,
          onRetry: () => ref.invalidate(meProvider),
          data: (user) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(meProvider);
              ref.invalidate(quotaProvider);
              ref.invalidate(progressProvider);
            },
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Row(children: [
                const BrandLogo(showName: true, size: 24),
                const Spacer(),
                Tag('🔥 ${user.streak} ${context.s('days')}', variant: 'w'),
              ]),
              const SizedBox(height: 12),
              _MedalsCard(user: user),
              const SizedBox(height: 10),
              _QuotaCard(),
              if (!user.isPaid) ...[
                const SizedBox(height: 10),
                SoftCard(
                  borderColor: t.brand,
                  background: AppColors.azul.withOpacity(.05),
                  onTap: () => context.push('/paywall'),
                  child: Row(children: [
                    const Text('🚀', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(context.s('up_banner_h'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        Text(context.s('up_banner_p'), style: TextStyle(fontSize: 11, color: t.muted)),
                      ]),
                    ),
                    Tag('${context.s('up_cta')} ›', variant: 'g'),
                  ]),
                ),
              ],
              const SizedBox(height: 12),
              PrimaryButton(label: context.s('cont'), onPressed: () => _startPractice(context, ref)),
              const SizedBox(height: 16),
              Text(context.s('progress'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 6),
              _ProgressList(),
            ]),
          ),
        ),
      ),
    );
  }
}

class _MedalsCard extends StatelessWidget {
  const _MedalsCard({required this.user});
  final User user;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bronze = user.medals.bronze;
    return SoftCard(
      child: Column(children: [
        Row(children: [
          Text('TUS MEDALLAS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: t.muted)),
          const Spacer(),
          GestureDetector(
            onTap: () => GoRouter.of(context).go('/medals'),
            child: Text('Ver todo →', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: t.brand)),
          ),
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          for (final tier in Medals.tiers)
            Opacity(
              opacity: user.medals.byTier(tier) > 0 ? 1 : .4,
              child: Column(children: [
                MedalCoin(tier, size: 28),
                const SizedBox(height: 2),
                Text('${user.medals.byTier(tier)}',
                    style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: 12)),
              ]),
            ),
        ]),
        const SizedBox(height: 8),
        ProgressBar(value: (bronze % 5) / 5, color: AppColors.bronze, height: 6),
      ]),
    );
  }
}

class _QuotaCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quota = ref.watch(quotaProvider);
    final t = context.tokens;
    return SoftCard(
      child: quota.when(
        data: (q) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(context.s('quota'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(q.unlimited ? '∞' : '${q.used} / ${q.max}', style: TextStyle(fontSize: 12, color: t.muted)),
          ]),
          const SizedBox(height: 8),
          ProgressBar(value: q.unlimited ? 1 : (q.max == 0 ? 0 : q.used / q.max)),
          const SizedBox(height: 6),
          Text('10 base · +5 colegio · +5 dirección · 20 máx',
              style: TextStyle(fontSize: 11, color: t.muted)),
        ]),
        loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator())),
        error: (_, __) => Text(context.s('quota')),
      ),
    );
  }
}

class _ProgressList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    return progress.when(
      data: (items) => Column(children: [
        for (final p in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SoftCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(p.label),
                  const Spacer(),
                  Text('${p.percent}%', style: TextStyle(fontSize: 12, color: context.tokens.muted)),
                ]),
                const SizedBox(height: 8),
                ProgressBar(value: p.percent / 100, color: AppColors.testColors[p.testId]),
              ]),
            ),
          ),
      ]),
      loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
