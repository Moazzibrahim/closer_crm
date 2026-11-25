import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/messaging/data/messaging_model.dart';

/// Bottom sheet فيها سيرش على السيلز. بترجّع SalesOption المختار أو null
Future<SalesOption?> pickSales(
  BuildContext context,
  List<SalesOption> options, {
  String title = 'Assign to…',
  bool includeAll = false,
  String allLabel = 'All sales',
}) {
  return showModalBottomSheet<SalesOption>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _SalesPicker(
      options: options,
      title: title,
      includeAll: includeAll,
      allLabel: allLabel,
    ),
  );
}

class _SalesPicker extends StatefulWidget {
  final List<SalesOption> options;
  final String title;
  final bool includeAll;
  final String allLabel;
  const _SalesPicker({
    required this.options,
    required this.title,
    this.includeAll = false,
    this.allLabel = 'All sales',
  });

  @override
  State<_SalesPicker> createState() => _SalesPickerState();
}

class _SalesPickerState extends State<_SalesPicker> {
  final _controller = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// توحيد النص للبحث: lowercase + شيل المسافات الزيادة + توحيد الهمزات والتاء المربوطة
  String _normalize(String s) {
    return s
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp('[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');
  }

  @override
  Widget build(BuildContext context) {
    final q = _normalize(_q);

    // فلترة بالاسم (case-insensitive + بيدعم العربي)
    final list = q.isEmpty
        ? widget.options
        : widget.options.where((s) => _normalize(s.label).contains(q)).toList();

    final showAll =
        widget.includeAll &&
        (q.isEmpty || _normalize(widget.allLabel).contains(q));
    final extra = showAll ? 1 : 0;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: 'Search sales by name',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _q.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _q = '');
                          },
                        ),
                  isDense: true,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: (list.isEmpty && !showAll)
                  ? const Center(child: Text('No results'))
                  : ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: list.length + extra,
                      itemBuilder: (_, i) {
                        if (showAll && i == 0) {
                          return ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.groups_rounded),
                            ),
                            title: Text(widget.allLabel),
                            onTap: () => Navigator.pop(
                              context,
                              // عنصر "الكل": id فاضي
                              SalesOption('', widget.allLabel),
                            ),
                          );
                        }
                        final s = list[i - extra];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              s.label.isEmpty
                                  ? '?'
                                  : s.label.characters.first.toUpperCase(),
                            ),
                          ),
                          title: Text(s.label),
                          onTap: () => Navigator.pop(context, s),
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
