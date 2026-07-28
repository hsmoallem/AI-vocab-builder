import 'dart:convert';
import 'package:http/http.dart' as http;

const _umamiUrl = 'https://stats.houssammoallem.com/api/send';
const _websiteId = 'b7e25363-f784-45fe-b28a-dfbf61916a4b';

void platformTrackEvent(String eventName, Map<String, dynamic> properties) {
  _sendPayload({
    'website': _websiteId,
    'url': '/android/$eventName',
    'title': eventName,
    'hostname': 'ai-vocab-builder.android.app',
    'name': eventName,
    'data': properties,
  });
}

void platformTrackView(String url, String title) {
  _sendPayload({
    'website': _websiteId,
    'url': '/android$url',
    'title': title,
    'hostname': 'ai-vocab-builder.android.app',
  });
}

void _sendPayload(Map<String, dynamic> payload) async {
  try {
    await http.post(
      Uri.parse(_umamiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'payload': payload, 'type': 'event'}),
    );
  } catch (_) {
    // Ignore network errors offline
  }
}
