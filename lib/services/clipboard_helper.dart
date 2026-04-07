import 'dart:js_interop';
import 'package:flutter/material.dart';

@JS('eval')
external JSAny? _jsEval(JSString code);

void _jsCopy(String text) {
  final escaped = text
      .replaceAll('\\', '\\\\')
      .replaceAll("'", "\\'")
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '');
  _jsEval("""
(function(){
  var t=document.createElement('textarea');
  t.value='$escaped';
  t.setAttribute('readonly','');
  t.style.cssText='position:fixed;left:0;top:0;width:1px;height:1px;padding:0;border:none;outline:none;box-shadow:none;opacity:0.01';
  document.body.appendChild(t);
  t.focus();
  t.select();
  try{t.setSelectionRange(0,99999)}catch(e){}
  document.execCommand('copy');
  t.remove();
})()
""".toJS);
}

void showCopyDialog(BuildContext context, String label, String text) {
  _jsCopy(text);

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
                  _jsCopy(text);
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
                  child: Text(
                    text,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    },
  );
}
