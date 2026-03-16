// lib/astro_queue/services/wallet_session_timer.dart
//
// ╔══════════════════════════════════════════════════════════╗
// ║  WALLET SESSION TIMER                                    ║
// ║  • Fires every 60 seconds                               ║
// ║  • Calls POST /wallet/deduct-minute                     ║
// ║  • Returns hasBalance=false → caller ends session       ║
// ║  • Tracks elapsed for 75%/90%/95% threshold alerts      ║
// ╚══════════════════════════════════════════════════════════╝

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_learning/astro_queue/services/wallet_service.dart';

class WalletSessionTimer {
  final int customerId;
  final int sessionId;
  final double ratePerMinute;
  final int totalDurationMinutes;

  // Callbacks
  final void Function(double newBalance, int elapsedMinutes) onMinuteDeducted;
  final void Function() onBalanceEmpty; // hasBalance=false → end session
  final void Function(int elapsedMinutes) onThresholdAlert; // 75/90/95

  Timer? _timer;
  int _elapsedMinutes = 0;
  double _currentBalance = 0;
  bool _isRunning = false;

  // Track which thresholds already fired so we don't repeat
  bool _fired75 = false;
  bool _fired90 = false;
  bool _fired95 = false;

  WalletSessionTimer({
    required this.customerId,
    required this.sessionId,
    required this.ratePerMinute,
    required this.totalDurationMinutes,
    required this.onMinuteDeducted,
    required this.onBalanceEmpty,
    required this.onThresholdAlert,
  });

  void start(double initialBalance) {
    if (_isRunning) return;
    _isRunning = true;
    _currentBalance = initialBalance;

    _timer = Timer.periodic(const Duration(seconds: 60), (_) async {
      await _tick();
    });

    debugPrint('⏱ WalletSessionTimer started: sessionId=$sessionId rate=₹$ratePerMinute/min total=${totalDurationMinutes}min');
  }

  Future<void> _tick() async {
    if (!_isRunning) return;

    final result = await WalletService.deductMinute(
      customerId: customerId,
      sessionId: sessionId,
      ratePerMinute: ratePerMinute,
    );

    if (result == null) {
      // Network error — don't end session, just log
      debugPrint('⚠️ WalletSessionTimer: deductMinute returned null (network error)');
      return;
    }

    _elapsedMinutes++;
    _currentBalance = (result['newBalance'] ?? _currentBalance).toDouble();
    final hasBalance = result['hasBalance'] ?? true;

    debugPrint('⏱ Minute $_elapsedMinutes deducted. Balance: ₹$_currentBalance. HasBalance: $hasBalance');

    onMinuteDeducted(_currentBalance, _elapsedMinutes);

    // Check thresholds
    _checkThresholds();

    if (!hasBalance) {
      debugPrint('🛑 WalletSessionTimer: balance empty → ending session');
      stop();
      onBalanceEmpty();
    }
  }

  void _checkThresholds() {
    if (totalDurationMinutes == 0) return;
    final pct = _elapsedMinutes / totalDurationMinutes;

    if (!_fired75 && pct >= 0.75) {
      _fired75 = true;
      onThresholdAlert(_elapsedMinutes);
    } else if (!_fired90 && pct >= 0.90) {
      _fired90 = true;
      onThresholdAlert(_elapsedMinutes);
    } else if (!_fired95 && pct >= 0.95) {
      _fired95 = true;
      onThresholdAlert(_elapsedMinutes);
    }
  }

  /// Call after a mid-session top-up so balance is refreshed
  void updateBalance(double newBalance) {
    _currentBalance = newBalance;
    // Reset threshold flags so user can get alerts again if they add more minutes
    _fired75 = false;
    _fired90 = false;
    _fired95 = false;
  }

  int get elapsedMinutes => _elapsedMinutes;
  double get currentBalance => _currentBalance;
  bool get isRunning => _isRunning;

  void stop() {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
    debugPrint('⏱ WalletSessionTimer stopped after $_elapsedMinutes minutes');
  }

  void dispose() {
    stop();
  }
}