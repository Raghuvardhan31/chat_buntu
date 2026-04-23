import 'package:chataway_plus/core/snackbar/app_snackbar.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/features/chat/data/services/chat_engine/index.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';
import 'package:flutter/material.dart';

class EditMessageDialog extends StatefulWidget {
  const EditMessageDialog({
    super.key,
    required this.message,
    required this.unifiedChatService,
  });

  final ChatMessageModel message;
  final ChatEngineService unifiedChatService;

  @override
  State<EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<EditMessageDialog> {
  late String _text;
  bool _saving = false;
  ResponsiveSize? _lastResponsive;

  @override
  void initState() {
    super.initState();
    _text = widget.message.message;
  }

  Future<void> _handleSave() async {
    final newText = _text.trim();
    if (newText.isEmpty) {
      final width = context.screenWidth;
      final responsive =
          _lastResponsive ??
          ResponsiveSize(
            context: context,
            constraints: BoxConstraints(maxWidth: width),
            breakpoint: DeviceBreakpoint.fromWidth(width),
          );
      await AppSnackbar.showError(
        context,
        'Message cannot be empty',
        bottomPosition: responsive.size(120),
      );
      return;
    }

    if (newText == widget.message.message.trim()) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      return;
    }

    setState(() => _saving = true);

    final ok = await widget.unifiedChatService.editMessage(
      chatId: widget.message.id,
      newMessage: newText,
    );

    if (!context.mounted) return;

    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );
        _lastResponsive = responsive;

        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(responsive.size(14)),
          ),
          title: const Text('Edit message'),
          content: TextFormField(
            initialValue: _text,
            onChanged: (v) => _text = v,
            autofocus: true,
            maxLines: null,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: responsive.spacing(14),
                vertical: responsive.spacing(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(responsive.size(10)),
                borderSide: BorderSide(
                  color: Colors.blue.shade300,
                  width: responsive.size(1.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(responsive.size(10)),
                borderSide: BorderSide(
                  color: Colors.blue.shade600,
                  width: responsive.size(1.6),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: _saving ? null : _handleSave,
              child: Text(_saving ? 'Saving...' : 'Save'),
            ),
          ],
        );
      },
    );
  }
}

Future<void> showEditMessageDialog({
  required BuildContext context,
  required ChatMessageModel message,
  required ChatEngineService unifiedChatService,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) {
      return EditMessageDialog(
        message: message,
        unifiedChatService: unifiedChatService,
      );
    },
  );
}
