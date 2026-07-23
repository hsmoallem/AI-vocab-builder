// Web implementation using package:web (or dart:html)
import 'package:web/web.dart' as web;

void speakWeb(String text, String language) {
  final synth = web.window.speechSynthesis;
  final utterance = web.SpeechSynthesisUtterance(text);
  utterance.lang = language;
  synth.speak(utterance);
}

void stopWeb() {
  web.window.speechSynthesis.cancel();
}
