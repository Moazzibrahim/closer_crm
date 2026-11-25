// quick_send_sheet.dart — POST /messaging/messages/send  (Admin / Sales Manager بس)
// SMS نص عادي، أو WhatsApp بـ template (الاسم + اللغة + قيمة المتغير).

import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/messaging/provider/messaging_provider.dart';
import 'package:provider/provider.dart';

Future<void> showQuickSendSheet(BuildContext context) {
  final p = context.read<MessagingProvider>();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _QuickSend(p),
  );
}

class _QuickSend extends StatefulWidget {
  final MessagingProvider p;
  const _QuickSend(this.p);
  @override
  State<_QuickSend> createState() => _QuickSendState();
}

class _QuickSendState extends State<_QuickSend> {
  String _channel = 'sms';
  final _numbers = TextEditingController();
  final _message = TextEditingController();
  final _template = TextEditingController();
  final _lang = TextEditingController(text: 'ar');
  bool _busy = false;

  @override
  void dispose() {
    _numbers.dispose();
    _message.dispose();
    _template.dispose();
    _lang.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {String? hint, IconData? icon}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        filled: true,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      );

  Future<void> _send() async {
    final nums = _numbers.text
        .split(RegExp(r'[,\s;]+'))
        .map((e) => e.replaceAll(RegExp(r'[^0-9]'), ''))
        .where((e) => e.isNotEmpty)
        .toList();
    if (nums.isEmpty) return;
    setState(() => _busy = true);
    String msg;
    try {
      final r = await widget.p.service.quickSend(
        numbers: nums,
        channel: _channel,
        message: _message.text.trim(),
        templateName: _channel == 'whatsapp' ? _template.text.trim() : null,
        language: _channel == 'whatsapp' ? _lang.text.trim() : null,
      );
      msg =
          'Sent ${r.sent} · failed ${r.failed.length} · invalid ${r.invalid.length}';
      if (r.failed.isEmpty && r.invalid.isEmpty && mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      msg = e.toString();
    }
    if (mounted) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWa = _channel == 'whatsapp';

    return Padding(
      // الكيبورد
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Quick send',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: 'sms',
                    icon: Icon(Icons.sms_outlined),
                    label: Text('SMS'),
                  ),
                  ButtonSegment(
                    value: 'whatsapp',
                    icon: Icon(Icons.chat_outlined),
                    label: Text('WhatsApp'),
                  ),
                ],
                selected: {_channel},
                onSelectionChanged: (s) => setState(() => _channel = s.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _numbers,
                minLines: 2,
                maxLines: 4,
                keyboardType: TextInputType.phone,
                decoration:
                    _dec(
                      'Numbers',
                      hint: '971501234567, 971509876543',
                      icon: Icons.phone_outlined,
                    ).copyWith(
                      helperText: 'Comma / space separated, with country code',
                    ),
              ),
              if (isWa) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _template,
                        decoration: _dec('Template name'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _lang,
                        decoration: _dec('Lang'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _message,
                minLines: 3,
                maxLines: 5,
                decoration: _dec(isWa ? 'Template variable value' : 'Message'),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _send,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(_busy ? 'Sending…' : 'Send'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
