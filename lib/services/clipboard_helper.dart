import 'dart:js_interop';
import 'package:flutter/services.dart';

@JS('navigator.clipboard.writeText')
external JSPromise<JSAny?> _jsWriteText(JSString text);

Future<bool> copyText(String text) async {
  try {
    await _jsWriteText(text.toJS).toDart;
    return true;
  } catch (_) {}
  try {
    await Clipboard.setData(ClipboardData(text: text));
    return true;
  } catch (_) {}
  return false;
}
