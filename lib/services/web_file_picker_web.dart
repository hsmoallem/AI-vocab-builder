import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

Future<Uint8List?> pickPdfBytes() async {
  final completer = Completer<Uint8List?>();
  final html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
  uploadInput.accept = 'application/pdf';

  uploadInput.onChange.listen((e) {
    final files = uploadInput.files;
    if (files != null && files.isNotEmpty) {
      final file = files[0];
      final reader = html.FileReader();
      
      reader.onLoadEnd.listen((e) {
        completer.complete(reader.result as Uint8List?);
      });
      
      reader.onError.listen((e) {
        completer.complete(null);
      });
      
      reader.readAsArrayBuffer(file);
    } else {
      completer.complete(null);
    }
  });

  uploadInput.click();
  return completer.future;
}
