import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/widgets/common_widgets.dart';
import '../../providers/app_providers.dart';
import '../../providers/data_providers.dart';

class QuotaUnlockScreen extends ConsumerStatefulWidget {
  const QuotaUnlockScreen({super.key});
  @override
  ConsumerState<QuotaUnlockScreen> createState() => _QuotaUnlockScreenState();
}

class _QuotaUnlockScreenState extends ConsumerState<QuotaUnlockScreen> {
  final _school = TextEditingController();
  final _age = TextEditingController();
  String _region = 'Metropolitana';
  bool _busy = false;

  Future<void> _unlock() async {
    setState(() => _busy = true);
    try {
      await ref.read(profileRepositoryProvider).unlockQuota(
            type: 'school',
            school: _school.text.trim(),
            age: int.tryParse(_age.text),
            region: _region,
          );
      ref.invalidate(quotaProvider);
      ref.invalidate(meProvider);
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Center(
            child: Column(children: [
              const Text('🎉', style: TextStyle(fontSize: 38)),
              Text(context.s('lim2_h'), style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: 17)),
            ]),
          ),
          const SizedBox(height: 6),
          Text(context.s('lim2_p'), textAlign: TextAlign.center, style: TextStyle(color: context.tokens.muted)),
          const SizedBox(height: 12),
          TextField(controller: _school, decoration: InputDecoration(hintText: context.s('school'))),
          const SizedBox(height: 9),
          Row(children: [
            Expanded(child: TextField(controller: _age, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: context.s('age')))),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _region,
                items: const ['Metropolitana', 'Valparaíso', 'Biobío', 'Otra']
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() => _region = v ?? _region),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          PrimaryButton(label: context.s('unlock5'), onPressed: _busy ? null : _unlock),
          TextButton(onPressed: () => context.go('/home'), child: Text(context.s('later'))),
        ]),
      ),
    );
  }
}
