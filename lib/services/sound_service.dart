
import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final AudioPlayer _player = AudioPlayer();

  static void playWhistle() {
    _play('sounds/whistle.wav');
  }

  static void playBell() {
    _play('sounds/bell.wav');
  }

  static Future<void> _play(String path) async {
    try {
      await _player.stop();
      await _player.setVolume(1.0);
      await _player.play(AssetSource(path));
    } catch (e) {
      // Gestisce silenziosamente eventuali eccezioni di riproduzione
    }
  }
}