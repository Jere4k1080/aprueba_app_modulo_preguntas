import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/models.dart';
import '../../providers/app_providers.dart';
import '../../providers/data_providers.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});
  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _post = TextEditingController();

  Future<void> _publish() async {
    if (_post.text.trim().isEmpty) return;
    await ref.read(communityRepositoryProvider).createPost(text: _post.text.trim());
    _post.clear();
    ref.invalidate(feedProvider);
  }

  Future<void> _like(String id) async {
    await ref.read(communityRepositoryProvider).toggleLike(id);
    ref.invalidate(feedProvider);
  }

  Widget _blurOpt(String letter) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey)),
      child: Text('$letter  ████'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedProvider);
    final t = context.tokens;
    return Scaffold(
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(children: [
              const BrandLogo(size: 22),
              const SizedBox(width: 8),
              Text(context.s('feed_h'), style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, color: t.brand)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SoftCard(
              child: Row(children: [
                Expanded(child: TextField(controller: _post, decoration: InputDecoration(hintText: context.s('post_ph'), border: InputBorder.none, filled: false))),
                IconButton(onPressed: _publish, icon: Icon(Icons.send, color: t.brand)),
              ]),
            ),
          ),
          Expanded(
            child: AsyncValueView<List<Post>>(
              value: feed,
              onRetry: () => ref.invalidate(feedProvider),
              data: (posts) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(feedProvider),
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  for (final p in posts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SoftCard(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            CircleAvatar(radius: 14, backgroundColor: AppColors.azul, child: Text(p.authorName.isNotEmpty ? p.authorName[0] : '?', style: const TextStyle(color: Colors.white, fontSize: 11))),
                            const SizedBox(width: 8),
                            Text(p.authorName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          ]),
                          const SizedBox(height: 6),
                          Text(p.text, style: const TextStyle(fontSize: 13)),
                          if (p.questionId != null) ...[
                            const SizedBox(height: 8),
                            ImageFiltered(
                              imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                              child: Row(children: [_blurOpt('A'), const SizedBox(width: 8), _blurOpt('B')]),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(children: [
                            InkWell(
                              onTap: () => _like(p.id),
                              child: Row(children: [
                                Icon(p.liked ? Icons.favorite : Icons.favorite_border, size: 16, color: p.liked ? AppColors.error : t.muted),
                                const SizedBox(width: 4),
                                Text('${p.likes}', style: TextStyle(fontSize: 12, color: t.muted)),
                              ]),
                            ),
                            const SizedBox(width: 16),
                            Icon(Icons.mode_comment_outlined, size: 15, color: t.muted),
                            const SizedBox(width: 4),
                            Text('${p.comments}', style: TextStyle(fontSize: 12, color: t.muted)),
                          ]),
                        ]),
                      ),
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
