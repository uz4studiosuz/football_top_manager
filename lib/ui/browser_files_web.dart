import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Opens the browser's file dialog for an image (phones offer the camera
/// too) and returns its bytes, or null when cancelled.
Future<Uint8List?> pickImageBytes() => pickFileBytes('image/*');

/// Opens the browser's file dialog filtered by [accept] and returns the bytes.
Future<Uint8List?> pickFileBytes(String accept) {
  final done = Completer<Uint8List?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept;
  input.addEventListener('change', ((web.Event _) {
    final file = input.files?.item(0);
    if (file == null) {
      if (!done.isCompleted) done.complete(null);
      return;
    }
    file.arrayBuffer().toDart.then((buffer) {
      if (!done.isCompleted) done.complete(buffer.toDart.asUint8List());
    });
  }).toJS);
  input.oncancel = ((web.Event _) {
    if (!done.isCompleted) done.complete(null);
  }).toJS;
  input.click();
  return done.future;
}

/// Saves bytes as a download in the browser.
Future<void> downloadBytes(String name, Uint8List bytes, String mime) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body?.append(link);
  link.click();
  link.remove();
  web.URL.revokeObjectURL(url);
}
