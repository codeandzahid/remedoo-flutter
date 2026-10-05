import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Triggers a real file download on web.
void downloadTextFile(String filename, String content) {
  final blob = web.Blob(
      [content.toJS].toJS, web.BlobPropertyBag(type: 'text/plain'));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
