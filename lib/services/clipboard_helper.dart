import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<bool> copyText(String text) async {
  // Method 1: legacy execCommand with temporary textarea (most reliable on mobile)
  try {
    final ta = web.document.createElement('textarea') as web.HTMLTextAreaElement;
    ta.value = text;
    ta.style.position = 'fixed';
    ta.style.left = '-9999px';
    ta.style.top = '-9999px';
    ta.style.opacity = '0';
    web.document.body!.appendChild(ta);
    ta.focus();
    ta.select();
    final ok = web.document.execCommand('copy');
    ta.remove();
    if (ok) return true;
  } catch (_) {}

  // Method 2: modern clipboard API
  try {
    await web.window.navigator.clipboard.writeText(text).toDart;
    return true;
  } catch (_) {}

  return false;
}
