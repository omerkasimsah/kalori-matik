import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/haptics.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/notification_settings_provider.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  Future<void> _toggle(BuildContext context, WidgetRef ref,
      NotificationSettings next) async {
    // Bir bildirim türü ilk kez açılırken izin istenir.
    final s = ref.read(notificationSettingsProvider);
    final turningOn = (next.meals && !s.meals) ||
        (next.water && !s.water) ||
        (next.workout && !s.workout);
    if (turningOn) {
      final ok = await NotificationService.requestPermission();
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Bildirim izni verilmedi. Telefon ayarlarından izin verebilirsin.')));
        return;
      }
    }
    Haptics.light();
    await ref.read(notificationSettingsProvider.notifier).update(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(notificationSettingsProvider);
    final time = TimeOfDay(hour: s.workoutHour, minute: s.workoutMinute);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Bildirimler ve Titreşim')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          _Tile(
            icon: Icons.restaurant_outlined,
            title: 'Öğün hatırlatıcıları',
            subtitle: 'Kahvaltı 08:30 • Öğle 13:00 • Akşam 19:30',
            value: s.meals,
            onChanged: (v) => _toggle(context, ref, s.copyWith(meals: v)),
          ),
          _Tile(
            icon: Icons.water_drop_outlined,
            title: 'Su hatırlatıcıları',
            subtitle: '11:00 • 15:00 • 18:00',
            value: s.water,
            onChanged: (v) => _toggle(context, ref, s.copyWith(water: v)),
          ),
          _Tile(
            icon: Icons.fitness_center,
            title: 'Antrenman hatırlatıcısı',
            subtitle:
                'Haftalık programın varsa yalnızca antrenman günlerinde, yoksa her gün',
            value: s.workout,
            onChanged: (v) => _toggle(context, ref, s.copyWith(workout: v)),
          ),
          if (s.workout)
            Padding(
              padding: const EdgeInsets.only(left: 56, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showTimePicker(
                        context: context, initialTime: time);
                    if (picked != null) {
                      await ref.read(notificationSettingsProvider.notifier).update(
                          s.copyWith(
                              workoutHour: picked.hour,
                              workoutMinute: picked.minute));
                    }
                  },
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text('Saat: ${time.format(context)}'),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10)),
                ),
              ),
            ),
          const Divider(height: 32),
          _Tile(
            icon: Icons.vibration,
            title: 'Titreşim geri bildirimi',
            subtitle: 'Öğün kaydı, su, antrenman setleri ve silme işlemlerinde',
            value: s.haptics,
            onChanged: (v) async {
              await ref
                  .read(notificationSettingsProvider.notifier)
                  .update(s.copyWith(haptics: v));
              Haptics.success();
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Hatırlatıcılar cihazında oluşturulur; internet gerektirmez. '
            'Pil tasarrufu nedeniyle birkaç dakika kayabilir.',
            style: TextStyle(
                color: AppColors.textHint, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, color: AppColors.textSecondary),
      title: Text(title,
          style: TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      value: value,
      onChanged: onChanged,
    );
  }
}
