/// Web implementation: build a Blob and click a temporary anchor to
/// trigger a browser download.
import 'dart:convert';
import 'dart:html' as html;

void downloadTextFile(String content, String filename, String mime) {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
