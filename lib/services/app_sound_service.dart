import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class AppSoundService {
  AppSoundService._();

  static final AppSoundService instance = AppSoundService._();
  final AudioPlayer _player = AudioPlayer();
  // Dedicated player: verification alerts do not interrupt captain offers,
  // chats or market-order sound playback.
  final AudioPlayer _verificationPlayer = AudioPlayer();

  Future<void> _play(String asset) async {
    try {
      await _player.stop();
      await _player.play(AssetSource(asset), volume: 1.0);
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  /// Sound played when a new captain offer is received.
  Future<void> playOffer() => _play('sounds/veto_offer_v2.wav');

  /// Fifteen-second alert used only for a new VETO Market order.
  Future<void> playMarketOrder() => _play('sounds/veto_market_order.wav');

  /// Sound played when a new chat message is received.
  Future<void> playChat() => _play('sounds/veto_chat_v2.wav');

  /// Generic notification sound.
  Future<void> playNotification() => _play('sounds/veto_notification_v2.wav');

  /// Five-second verification-request chime, only for an authorized admin.
  /// Browser autoplay restrictions may require the admin to interact with the page.
  Future<void> playVerificationAlert() async {
    try {
      await _verificationPlayer.stop();
      await _verificationPlayer.play(
        AssetSource('sounds/veto_verification_5s.wav'),
        volume: 1.0,
      );
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  /// Success/confirmation sound. There is no separate success asset in the
  /// current project, so use the notification sound as a safe fallback.
  Future<void> playSuccess() => _play('sounds/veto_success_new.wav');

  /// Haptic feedback for important UI events.
  Future<void> playHaptic() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _player.dispose();
      await _verificationPlayer.dispose();
    } catch (_) {}
  }
}
