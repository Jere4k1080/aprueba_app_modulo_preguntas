import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../l10n/app_strings.dart';

/// Renderiza un AsyncValue con estados de carga/error/datos consistentes.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({super.key, required this.value, required this.data, this.onRetry});
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () => const Center(
          child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
      error: (e, _) {
        final msg = e is ApiException ? e.message : context.s('error_generic');
        // La nube tachada es solo para la falta de red: un 404 o un 401 no lo son.
        final offline = e is ApiException && e.isNetwork;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(offline ? Icons.cloud_off : Icons.error_outline, size: 40),
              const SizedBox(height: 10),
              Text(msg, textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(onPressed: onRetry, child: Text(context.s('retry'))),
              ],
            ]),
          ),
        );
      },
    );
  }
}
