// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';

/// شيت تعديل deal. بيرجّع الحقول اللي اتغيرت بس (أو null لو مفيش تغيير/إلغاء)
Future<Map<String, dynamic>?> showEditDealSheet(
  BuildContext context,
  Map deal,
) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _EditDealSheet(deal: deal),
  );
}

class _EditDealSheet extends StatefulWidget {
  final Map deal;
  const _EditDealSheet({required this.deal});
  @override
  State<_EditDealSheet> createState() => _EditDealSheetState();
}

class _EditDealSheetState extends State<_EditDealSheet> {
  // key في الـ API -> (label, هل رقم؟)
  static const _fields = <String, (String, bool)>{
    'unitNumber': ('Unit number', false),
    'unitType': ('Unit type', false),
    'unitPrice': ('Unit price', true),
    'amountPaid': ('Amount paid', true),
    'companyCommissionRatio': ('Commission %', true),
    'cashbackRatio': ('Cashback %', true),
    'contactName': ('Contact name', false),
    'contactPhone': ('Contact phone', false),
  };

  // كل حقل له controller متملي بالقيمة الحالية
  late final Map<String, TextEditingController> _c = {
    for (final k in _fields.keys)
      k: TextEditingController(text: '${widget.deal[k] ?? ''}'),
  };

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final body = <String, dynamic>{};
    _fields.forEach((k, meta) {
      final txt = _c[k]!.text.trim();
      final old = '${widget.deal[k] ?? ''}';
      if (txt == old) return; // مفيش تغيير = منبعتوش
      if (meta.$2) {
        final n = num.tryParse(txt);
        if (n != null) body[k] = n; // الأرقام الغلط بتتتجاهل
      } else {
        body[k] = txt;
      }
    });
    Navigator.pop(context, body.isEmpty ? null : body);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // عشان الكيبورد ما يغطيش الحقول
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Edit deal',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            for (final e in _fields.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: _c[e.key],
                  keyboardType: e.value.$2
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.text,
                  decoration: InputDecoration(
                    labelText: e.value.$1,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: AppColors.goldLight,
                ),
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
