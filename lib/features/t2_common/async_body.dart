import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 't2_api.dart';
import 't2_ui.dart';

/// Tampilkan AsyncValue dengan pemuatan, galat + coba lagi, dan tarik-untuk-segarkan.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.builder, required this.onRefresh});
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      data: (d) => RefreshIndicator(color: T2Colors.orange, onRefresh: onRefresh, child: builder(d)),
      loading: () => const Center(child: CircularProgressIndicator(color: T2Colors.orange)),
      error: (e, _) => ListView(children: [
        EmptyNote(t2Error(e), icon: Icons.wifi_off_rounded),
        Center(child: TextButton(onPressed: onRefresh, child: const Text('Coba lagi'))),
      ]),
    );
  }
}
