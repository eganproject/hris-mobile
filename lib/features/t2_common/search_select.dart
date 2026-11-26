import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import 't2_ui.dart';

class SelectOption<T> {
  const SelectOption(this.value, this.label, {this.subtitle, this.person});
  final T value;
  final String label;
  final String? subtitle;

  /// Bila diisi, baris pilihan memakai avatar orang (foto/inisial).
  final Map<String, dynamic>? person;
}

/// Kolom pilihan yang bisa dicari. Diketuk membuka lembar bawah berisi kotak
/// cari dan daftar pilihan — pengganti dropdown yang tidak bisa diketik.
class SearchSelectField<T> extends StatelessWidget {
  const SearchSelectField({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.hint = 'Pilih',
    this.sheetTitle,
    this.searchHint = 'Cari…',
    this.errorText,
  });

  final String label;
  final List<SelectOption<T>> options;
  final T? value;
  final ValueChanged<T> onChanged;
  final String hint;
  final String? sheetTitle;
  final String searchHint;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final selected = options.where((o) => o.value == value).firstOrNull;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await showSearchSelect<T>(
          context,
          title: sheetTitle ?? 'Pilih ${label.toLowerCase()}',
          options: options,
          selected: value,
          searchHint: searchHint,
        );
        if (picked != null) onChanged(picked.value);
      },
      child: InputDecorator(
        isEmpty: selected == null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: errorText,
          suffixIcon: const Icon(Icons.expand_more_rounded),
        ),
        child: selected == null
            ? null
            : Text(
                selected.subtitle == null ? selected.label : '${selected.label} · ${selected.subtitle}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, color: AppColors.ink),
              ),
      ),
    );
  }
}

Future<SelectOption<T>?> showSearchSelect<T>(
  BuildContext context, {
  required String title,
  required List<SelectOption<T>> options,
  T? selected,
  String searchHint = 'Cari…',
}) {
  return showModalBottomSheet<SelectOption<T>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => _SearchSheet<T>(title: title, options: options, selected: selected, searchHint: searchHint),
  );
}

class _SearchSheet<T> extends StatefulWidget {
  const _SearchSheet({required this.title, required this.options, required this.selected, required this.searchHint});
  final String title;
  final List<SelectOption<T>> options;
  final T? selected;
  final String searchHint;

  @override
  State<_SearchSheet<T>> createState() => _SearchSheetState<T>();
}

class _SearchSheetState<T> extends State<_SearchSheet<T>> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final shown = q.isEmpty
        ? widget.options
        : widget.options.where((o) => '${o.label} ${o.subtitle ?? ''}'.toLowerCase().contains(q)).toList();
    final media = MediaQuery.of(context);
    // Kotak cari hanya ditampilkan bila pilihannya cukup banyak untuk dicari.
    final searchable = widget.options.length > 5;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: (media.size.height - media.viewInsets.bottom) * .85),
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            if (searchable)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: TextField(
                  autofocus: widget.options.length > 12,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(hintText: widget.searchHint, prefixIcon: const Icon(Icons.search_rounded)),
                  onChanged: (v) => setState(() => _q = v),
                ),
              ),
            Flexible(
              child: shown.isEmpty
                  ? const EmptyNote('Tidak ada yang cocok.', icon: Icons.search_off_rounded)
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                      itemCount: shown.length,
                      itemBuilder: (context, i) {
                        final o = shown[i];
                        final isSel = o.value == widget.selected;
                        return ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          selected: isSel,
                          selectedTileColor: AppColors.navySoft,
                          leading: o.person == null ? null : PersonAvatar(person: o.person, size: 36),
                          title: Text(
                            o.label,
                            style: TextStyle(fontWeight: isSel ? FontWeight.w700 : FontWeight.w600, color: AppColors.ink),
                          ),
                          subtitle: o.subtitle == null
                              ? null
                              : Text(o.subtitle!, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                          trailing: isSel ? const Icon(Icons.check_rounded, color: AppColors.navy) : null,
                          onTap: () => Navigator.pop(context, o),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
