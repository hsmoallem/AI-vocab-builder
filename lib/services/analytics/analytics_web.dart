import 'dart:convert';
import 'dart:js_interop';

@JS('umamiTrackEvent')
external void _jsUmamiTrackEvent(String eventName, String eventData);

@JS('umamiTrackView')
external void _jsUmamiTrackView(String url, String title);

void platformTrackEvent(String eventName, Map<String, dynamic> properties) {
  try {
    _jsUmamiTrackEvent(eventName, jsonEncode(properties));
  } catch (_) {
    // ignore errors
  }
}

void platformTrackView(String url, String title) {
  try {
    _jsUmamiTrackView(url, title);
  } catch (_) {
    // ignore errors
  }
}
