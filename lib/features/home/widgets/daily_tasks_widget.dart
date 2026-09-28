import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

// Basit bir model (Gerçekte Supabase'den JSON olarak gelecek veya provider'dan beslenecektir)
class DietTask {
  final String time;
  final String food;
  bool isCompleted;

  DietTask({required this.time, required this.food, this.isCompleted = false});
}

class DailyTasksWidget extends StatefulWidget {
  const DailyTasksWidget({super.key});

  @override
  State<DailyTasksWidget> createState() => _DailyTasksWidgetState();
}

class _DailyTasksWidgetState extends State<DailyTasksWidget> {
  // Örnek atanmış koç görevleri (Hardcoded mock for UI implementation)
  final List<DietTask> tasks = [
    DietTask(time: 'Kahvaltı', food: '2 Haşlanmış Yumurta, 1 Dilim Peynir'),
    DietTask(time: 'Öğle', food: 'Izgara Tavuk Salata (Zeytinyağlı)'),
    DietTask(time: 'Ara Öğün', food: '1 Avuç Kavrulmamış Badem'),
  ];

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    final completedCount = tasks.where((t) => t.isCompleted).length;
    final allCompleted = completedCount == tasks.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'BUGÜNKÜ DİYET GÖREVLERİ',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: AppColors.textSecondary,
                    ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: allCompleted ? AppColors.success.withAlpha(30) : AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$completedCount / ${tasks.length}',
                  style: TextStyle(
                    color: allCompleted ? AppColors.success : AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tasks.length,
              separatorBuilder: (context, index) => Divider(
                color: Colors.grey.shade100,
                height: 1,
              ),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return CheckboxListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppColors.success, // Zümrüt Yeşili onay durumu
                  title: Text(
                    task.food,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: task.isCompleted ? FontWeight.normal : FontWeight.w600,
                      color: task.isCompleted ? AppColors.textHint : AppColors.textPrimary,
                      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: Text(
                    task.time,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  value: task.isCompleted,
                  onChanged: (bool? val) {
                    if (val != null) {
                      setState(() {
                        task.isCompleted = val;
                      });
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
