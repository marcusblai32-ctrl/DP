import 'dart:io';

import 'package:audioplayers/audioplayers.dart';

/// Sonnerie d'alarme jouée par DP lui-même (en boucle) quand un rappel arrive à échéance.
/// Android : flux « alarme » (volume des alarmes). Windows : haut-parleurs du système.
class AlarmSoundService {
  const AlarmSoundService._();

  static final AudioPlayer _player = AudioPlayer();
  static bool _playing = false;

  static bool get playing => _playing;

  static Future<void> start() async {
    if (_playing) return;
    _playing = true;
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      if (Platform.isAndroid) {
        await _player.setAudioContext(AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ));
      }
      await _player.setVolume(1.0);
      await _player.play(AssetSource('alarm.wav'));
    } catch (_) {
      _playing = false;
    }
  }

  static Future<void> stop() async {
    if (!_playing) return;
    _playing = false;
    try {
      await _player.stop();
    } catch (_) {}
  }
}
