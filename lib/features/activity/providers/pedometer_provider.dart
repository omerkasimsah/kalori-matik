import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

// Günlük adım sayısını tutan global Riverpod sağlayıcısı
final pedometerProvider = StateNotifierProvider<PedometerNotifier, PedometerState>((ref) {
  return PedometerNotifier();
});

// Adım sayar durumunu tutan veri modeli
class PedometerState {
  final int steps;          // Bugünkü adım sayısı
  final bool isAvailable;   // Sensör mevcut mu?
  final bool isLoading;     // İzin bekleniyor mu?

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
  PedometerNotifier() : super(const PedometerState()) {
    _initPedometer();
  }

  Future<void> _initPedometer() async {
    // Android 10+ için runtime aktivite tanıma izni istenir
    final status = await Permission.activityRecognition.request();

    if (!status.isGranted) {
      if (mounted) {
        state = state.copyWith(isAvailable: false, isLoading: false);
      }
      return;
    }

    // Sensörden canlı veri akışını dinle
    try {
      Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: _onStepCountError,
        cancelOnError: false,
      );
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isAvailable: false, isLoading: false);
      }
    }
  }

  void _onStepCount(StepCount event) async {
    // Pedometer paketi cihazın AÇILDIĞINDAN beri toplam adımı verir.
    // Sadece bugünkü adımı bulmak için günlük başlangıç adımını hafızadan çıkarırız.
    final prefs = await SharedPreferences.getInstance();
    final today = '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
    final savedDate = prefs.getString('pedometer_date');

    if (savedDate != today) {
      // Yeni gün — bugünün başlangıç adımını kaydet
      await prefs.setInt('pedometer_initial_steps', event.steps);
      await prefs.setString('pedometer_date', today);
    }

    final initialSteps = prefs.getInt('pedometer_initial_steps') ?? event.steps;
    final todaySteps = (event.steps - initialSteps).clamp(0, 999999);

    if (mounted) {
      state = state.copyWith(steps: todaySteps, isLoading: false, isAvailable: true);
    }
  }

  void _onStepCountError(error) {
    // Donanımsal sensör yok veya erişim hatası
    if (mounted) {
      state = state.copyWith(isAvailable: false, isLoading: false);
    }
  }
}
