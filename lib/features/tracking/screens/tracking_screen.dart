import 'package:flutter/material.dart';
import '../../home/widgets/daily_tasks_widget.dart';
import '../../../core/theme/app_colors.dart';

class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Koç & Takip'),
      ),
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: Text(
                'Profesyonel İletişim & Görevler',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // Diyetisyen/Koç görevleri widget'ı
          const SliverToBoxAdapter(
            child: DailyTasksWidget(),
          ),
        ],
      ),
    );
  }
}
