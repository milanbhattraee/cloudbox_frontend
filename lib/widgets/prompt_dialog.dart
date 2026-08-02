import 'package:flutter/material.dart';

/// Shows a simple single-field text dialog and returns the trimmed value,
/// or null if the user cancelled. [validator] follows the standard
/// FormField contract (return an error string, or null if valid).
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  String confirmLabel = 'Save',
  String? initialValue,
  String? hintText,
  String? Function(String?)? validator,
}) async {
  final controller = TextEditingController(text: initialValue);
  final formKey = GlobalKey<FormState>();

  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hintText),
          validator: validator,
          onFieldSubmitted: (_) {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.of(ctx).pop(controller.text.trim());
            }
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.of(ctx).pop(controller.text.trim());
            }
          },
          child: Text(confirmLabel),
        ),
      ],
    ),
  );

  controller.dispose();
  return result;
}
