import 'package:flutter/material.dart';

class PasswordDialog extends StatefulWidget {
  final String name;
  const PasswordDialog({required this.name});

  @override
  State<PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  final _ctrl = TextEditingController();
  bool _hide = true;
  String? _err;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_ctrl.text.length < 6) {
      setState(() => _err = 'Min 6 characters');
      return;
    }
    Navigator.pop(context, _ctrl.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'New password for ${widget.name}',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
      content: TextField(
        controller: _ctrl,
        obscureText: _hide,
        autofocus: true,
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(
          hintText: 'New password (min 6)',
          errorText: _err,
          suffixIcon: IconButton(
            icon: Icon(
              _hide ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            ),
            onPressed: () => setState(() => _hide = !_hide),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}