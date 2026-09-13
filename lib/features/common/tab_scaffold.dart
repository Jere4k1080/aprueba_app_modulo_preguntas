import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/data_providers.dart';
import '../../providers/tutors_providers.dart';

/// Índices de las ramas del StatefulShellRoute (ver app_router.dart).
const _branchHome = 0;
const _branchMedals = 1;
const _branchGroups = 2;
const _branchTutors = 3;
const _branchFeed = 4;
const _branchSettings = 5;

/// Contenedor con la barra de pestañas inferior.
///
/// La pestaña de Tutores solo se muestra a planes de pago: la rama existe
/// siempre en el shell, pero se oculta del NavigationBar y el router redirige
/// /tutors al paywall mientras el plan sea free.
class TabScaffold extends ConsumerWidget {
  const TabScaffold({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final isPaid = ref.watch(isPaidPlanProvider);
    final unread = isPaid ? ref.watch(unreadMessagesProvider) : 0;

    final items = <(int, IconData, String, int)>[
      (_branchHome, Icons.home_rounded, context.s('today'), 0),
      (_branchMedals, Icons.military_tech_rounded, context.s('med_tab'), 0),
      (_branchGroups, Icons.groups_rounded, context.s('grp_tab'), 0),
      if (isPaid) (_branchTutors, Icons.school_rounded, context.s('tut_tab'), unread),
      (_branchFeed, Icons.forum_rounded, context.s('feed_tab'), 0),
      (_branchSettings, Icons.settings_rounded, context.s('set_h'), 0),
    ];

    // El índice visible no coincide con el de la rama cuando Tutores está oculta.
    var selected = items.indexWhere((it) => it.$1 == shell.currentIndex);
    if (selected < 0) selected = 0;

    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: t.surface,
          indicatorColor: t.brand.withOpacity(.12),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 10, fontWeight: FontWeight.w700, fontFamily: 'Montserrat', color: t.muted),
          ),
        ),
        child: NavigationBar(
          height: 64,
          selectedIndex: selected,
          onDestinationSelected: (i) {
            final branch = items[i].$1;
            shell.goBranch(branch, initialLocation: branch == shell.currentIndex);
          },
          destinations: [
            for (final it in items)
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: it.$4 > 0,
                  label: Text('${it.$4}'),
                  child: Icon(it.$2, color: t.muted),
                ),
                selectedIcon: Badge(
                  isLabelVisible: it.$4 > 0,
                  label: Text('${it.$4}'),
                  child: Icon(it.$2, color: AppColors.azul),
                ),
                label: it.$3,
              ),
          ],
        ),
      ),
    );
  }
}
