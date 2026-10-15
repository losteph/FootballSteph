import 'dart:js_interop';

@JS('window.playCustomSound')
external void _jsPlaySound(JSString type);

void playCustomSound(String type) {
  try {
    _jsPlaySound(type.toJS);
  } catch (_) {}
}