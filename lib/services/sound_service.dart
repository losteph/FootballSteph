// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js_interop';

@JS('window.playCustomSound')
external void _jsPlaySound(JSString type);

class SoundService {
  static void playWhistle() {
    try {
      _jsPlaySound('whistle'.toJS);
    } catch (_) {}
  }

  static void playBell() {
    try {
      _jsPlaySound('bell'.toJS);
    } catch (_) {}
  }
}