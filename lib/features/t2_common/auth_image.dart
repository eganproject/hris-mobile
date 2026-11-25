import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 't2_api.dart';
import 't2_ui.dart';

final _imageProvider = FutureProvider.autoDispose.family<Uint8List, String>((ref, path) {
  ref.keepAlive();
  return ref.read(t2ApiProvider).bytes(path);
});

/// Gambar dari endpoint API yang butuh token (foto postingan, lampiran).
class AuthImage extends ConsumerWidget {
  const AuthImage(this.path, {super.key, this.height = 200});
  final String path;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final img = ref.watch(_imageProvider(path));
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: img.when(
          data: (b) => Image.memory(b, fit: BoxFit.cover),
          loading: () => Container(color: T2Colors.bg),
          error: (_, _) => Container(color: T2Colors.bg, child: const Icon(Icons.broken_image_outlined, color: T2Colors.faint)),
        ),
      ),
    );
  }
}
