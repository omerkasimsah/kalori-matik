import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Çekirdek (Core) ve Uygulama Teması İçe Aktarımları
import 'core/config/app_config.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

// Özellik (Feature) / Modül Ekranlarının İçe Aktarımları
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/camera/screens/add_meal_screen.dart';
import 'features/home/screens/client_detail_screen.dart';
import 'features/history/screens/history_screen.dart';
import 'features/activity/data/exercise_library.dart';
import 'features/activity/screens/exercise_screens.dart';
import 'features/tracking/screens/tracking_screen.dart';

void main() async {
  // Flutter framework'ünün native (platform) kanallarıyla haberleşebilmesi için gerekli köprü kurulumu.
  WidgetsFlutterBinding.ensureInitialized();
  
  // Supabase (Backend-as-a-Service) bağlantısı başlatılıyor.
  // Projenin veritabanı (auth, profiles, meal_logs) işlemlerinin tümü bu bağlantı üzerinden yürütülür.
  // Bağlantı bilgileri lib/core/config/app_config.dart içinden (dart-define) okunur.
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  // Uygulamanın en dış sarmalayıcısı olarak ProviderScope (Riverpod state yönetimi için) kullanılıyor.
  runApp(
    const ProviderScope(
      child: KaloriMatikApp(),
    ),
  );
}

class KaloriMatikApp extends ConsumerWidget {
  const KaloriMatikApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'KaloriMatik',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      // AppColors aktif temayı okur; tema değişince alt ağaç yeniden kurulur.
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        AppColors.apply(brightness);
        return KeyedSubtree(
          key: ValueKey(brightness),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: brightness == Brightness.dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

// Temel Yönlendirme (Routing) Mimarisi 
// go_router kütüphanesi kullanılarak sayfalar (ekranlar) arası geçiş işlemleri yönetilir.
// Oturum gerektirmeyen rotalar
const _publicRoutes = {'/', '/login', '/register'};

final _router = GoRouter(
  initialLocation: '/',
  // Oturumu olmayan kullanıcı korumalı bir sayfaya gidemez.
  redirect: (context, state) {
    final loggedIn = SupabaseService.isLoggedIn;
    if (!loggedIn && !_publicRoutes.contains(state.matchedLocation)) {
      return '/login';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/add-meal',
      builder: (context, state) => const AddMealScreen(),
    ),
    GoRoute(
      path: '/exercises',
      builder: (context, state) => const ExerciseLibraryScreen(),
    ),
    GoRoute(
      path: '/exercise/:id',
      redirect: (context, state) =>
          exercisesById.containsKey(state.pathParameters['id']) ? null : '/exercises',
      builder: (context, state) => ExerciseDetailScreen(
          exercise: exerciseById(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: '/coach',
      builder: (context, state) => const TrackingScreen(),
    ),
    GoRoute(
      path: '/client-detail',
      redirect: (context, state) => state.extra is Map<String, dynamic> ? null : '/home',
      builder: (context, state) {
        final profile = state.extra as Map<String, dynamic>;
        return ClientDetailScreen(clientProfile: profile);
      },
    ),
  ],
);

// Karşılama ve Yükleme Ekranı (Splash Screen)
// Uygulama ilk açıldığında gösterilen, kullanıcının oturum durumunu denetleyen ve uygun sayfaya yönlendiren arayüz.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      if (SupabaseService.isLoggedIn) {
        context.go('/home');
      } else {
        context.go('/login');
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Icon(Icons.restaurant_menu_rounded,
                      size: 48, color: AppColors.onPrimary),
                ),
                const SizedBox(height: 24),
                Text(
                  'KaloriMatik',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Yediğini bil, hedefine ulaş',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: AppColors.textHint,
                    strokeWidth: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
