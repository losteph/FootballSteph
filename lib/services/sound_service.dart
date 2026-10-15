// Se compila per il Web carica sound_service_web.dart, altrimenti carica sound_service_mobile.dart!
import 'sound_service_mobile.dart' if (dart.library.js_interop) 'sound_service_web.dart';

class SoundService {
  static void playWhistle() {
    playCustomSound('whistle');
  }

  static void playBell() {
    playCustomSound('bell');
  }
}