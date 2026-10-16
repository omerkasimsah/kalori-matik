import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Günlük adım sayısını tutan global Riverpod sağlayıcısı
final pedometerProvider =
    StateNotifierProvider<PedometerNotifier, PedometerState>((ref) {
  return PedometerNotifier();
});

/// Günlük adım hedefi.
const int dailyStepGoal = 10000;

// Adım sayar durumunu tutan veri modeli
class PedometerState {
  final int steps;          // Bugünkü adım sayısı
  final bool isAvailable;   // Sensör mevcut ve izin verilmiş mi?
  final bool isLoading;     // İzin / ilk veri bekleniyor mu?

  const PedometerState({
    this.steps = 0,
    this.isAvailable = true,
    this.isLoading = true,
  });

  PedometerState copyWith({int? steps, bool? isAvailable, bool? isLoading}) {
    return PedometerState(
      steps: steps ?? this.steps,
      isAvailable: isAvailable ?? this.isAvailable,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class PedometerNotifier extends StateNotifier<PedometerState> {
  StreamSubscription<StepCount>? _sub;

  PedometerNotifier() : super(const PedometerState()) {
    _initPedometer();
  }

  static bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _initPedometer() async {
    if (!_isSupportedPlatform) {
      _markUnavailable();
      return;
    }

    try {
      // Android 10+ için runtime aktivite tanıma izni istenir
      final status = await Permission.activityRecognition.request();
      if (!status.isGranted) {
        _markUnavailable();
        return;
      }

      _sub = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: (_) => _markUnavailable(),
        cancelOnError: false,
      );
    } catch (_) {
      _markUnavailable();
    }
  }

  /// İzin reddedildiyse kullanıcı ayarlardan açtıktan sonra tekrar dener.
  Future<void> retry() async {
    await _sub?.cancel();
    _sub = null;
    if (mounted) state = const PedometerState();
    await _initPedometer();
  }

  void _markUnavailable() {
    if (mounted) state = state.copyWith(isAvailable: false, isLoading: false);
  }

  Future<void> _onStepCount(StepCount event) async {
    // Pedometer paketi cihaz AÇILDIĞINDAN beri toplam adımı verir.
    // Bugünkü adımı bulmak için günün başlangıç değerini hafızadan çıkarırız.
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';
    final savedDate = prefs.getString('pedometer_date');
    var initialSteps = prefs.getInt('pedometer_initial_steps');

    // Yeni gün ya da cihaz yeniden başlatıldı (sayaç sıfırlandı)
    if (savedDate != today ||
        initialSteps == null ||
        event.steps < initialSteps) {
      initialSteps = event.steps;
      await prefs.setInt('pedometer_initial_steps', initialSteps);
      await prefs.setString('pedometer_date', today);
    }

    final todaySteps = (event.steps - initialSteps).clamp(0, 999999);
    if (mounted) {
      state = state.copyWith(
          steps: todaySteps, isLoading: false, isAvailable: true);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
