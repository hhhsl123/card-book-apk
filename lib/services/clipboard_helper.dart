import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'clipboard_web.dart' if (dart.library.io) 'clipboard_native.dart' as platform;

void showCopyDialog(BuildContext context, String label, String text) {
  if (kIsWeb) {
    platform.doCopy(text);
  } else {
    Clipboard.setData(ClipboardData(text: text));
  }

  showDialog(
    context: context,
    builder: (ctx) {
      bool copied = true;
      return StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(children: [
            Icon(copied ? Icons.check_circle : Icons.copy, size: 20, color: copied ? Colors.green : null),
            const SizedBox(width: 8),
            Text(copied ? '已复制' : label, style: const TextStyle(fontSize: 16)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('如未复制成功，点击下方文字重试', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  if (kIsWeb) {
                    platform.doCopy(text);
                  } else {
                    Clipboard.setData(ClipboardData(text: text));
                  }
                  setDialogState(() => copied = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: copied ? Colors.green.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: copied ? Colors.green.shade200 : Colors.grey.shade300),
                  ),
                  child: Text(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 14)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
          ],
        ),
      );
    },
  );
}
