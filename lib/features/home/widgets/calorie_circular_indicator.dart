import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/calorie_provider.dart';

class CalorieCircularIndicator extends ConsumerWidget {
  const CalorieCircularIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Riverpod üzerinden dinamik güncellenen global durum (state) bildirimlerini dinliyoruz
    final remaining = ref.watch(remainingBudgetProvider); // Kullanılabilir (kalan) bakiye
    final total = ref.watch(dailyBudgetProvider);       // Günlük kalori harcama hedefi
    final consumed = ref.watch(caloriesConsumedProvider); // Alınan toplam enerji


    // Görsel 'Doluluk' Oranının Hesaplanması
    // Dairesel ilerleme çubuğu animasyonu için 0.0 (Boş) ile 1.0 (Tam Dolu) aralığında değer
    double progress = total > 0 ? (total - remaining) / total : 0.0;
    progress = progress.clamp(0.0, 1.0);

    // Kalan bakiye eşiğine göre 'Uyarı/Uygunluk' Rengi Tanımlamaları ve Smart Microcopy
    Color progressColor;
    String statusLabel;
    
    if (progress >= 1.0) {
      // Bakiye tamamen aşıldı (Kriz anı - Sıcak Turuncu/Kırmızı)
      progressColor = AppColors.warning; // Warm Orange (PM talebi: limit aşımları için sıcak turuncu)
      statusLabel = 'Bankayı hortumladın! Hemen bir 30 dakika yürüyüş patlatıp bakiyeyi toparlayalım.';
    } else if (progress > 0.85) {
      // Limitin %85'inden fazlası harcandı
      progressColor = AppColors.warning;
      statusLabel = 'Kırmızı çizgiye yaklaştın, cüzdan elden gidiyor!';
    } else {
      // Güvende (Normal ilerleyiş - Zümrüt Yeşili)
      progressColor = AppColors.primary;
      statusLabel = 'Bakiye tıkırında, harika bir yatırım günü! 💎';
    }

    return Column(
      children: [
        // Dairesel halka
        SizedBox(
          width: 230,
          height: 230,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1 - progress),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 22,
                    color: AppColors.cardSurface, // Koyu halka zemini
                  ),
                  CircularProgressIndicator(
                    value: value,
                    strokeWidth: 22,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    strokeCap: StrokeCap.round,
                  ),
                  // Merkez içerik
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${remaining > 0 ? remaining : 0}',
                          style: TextStyle(
                            fontSize: 46,
                            fontWeight: FontWeight.w900,
                            color: progressColor,
                            height: 1.0,
                          ),
                        ),
                        const Text(
                          'KCAL kalan',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // Durum etiketi (Akıllı Microcopy)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: progressColor.withAlpha(20),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: progressColor.withAlpha(50)),
          ),
          child: Text(
            statusLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: progressColor,
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Alt özet satırı
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SummaryTile(
                label: 'Günlük Limit',
                value: '$total',
                unit: 'kcal',
                color: AppColors.textSecondary,
              ),
              Container(
                  width: 1, height: 36, color: Colors.white24),
              _SummaryTile(
                label: 'Harcanan',
                value: '$consumed',
                unit: 'kcal',
                color: AppColors.danger,
              ),
              Container(
                  width: 1, height: 36, color: Colors.white24),
              _SummaryTile(
                label: 'Kalan',
                value: '${remaining > 0 ? remaining : 0}',
                unit: 'kcal',
                color: progressColor,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
              letterSpacing: 0.3),
        ),
        const SizedBox(height: 2),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color),
              ),
              TextSpan(
                text: ' $unit',
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
