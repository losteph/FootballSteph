import 'package:flutter/services.dart';

void playCustomSound(String type) {
  // Riproduce feedback sonoro/tattile nativo di sistema su Android e iOS
  if (type == 'whistle') {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.heavyImpact();
  } else {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.mediumImpact();
  }
}