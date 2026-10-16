import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../home/providers/calorie_provider.dart';

/// Danışana koçu/diyetisyeni tarafından atanan içerikler.
class CoachContent {
  final List<Map<String, dynamic>> nutritionPlan;
  final List<Map<String, dynamic>> notes;

  const CoachContent({required this.nutritionPlan, required this.notes});

  bool get isEmpty => nutritionPlan.isEmpty && notes.isEmpty;
}

final coachContentProvider = FutureProvider<CoachContent>((ref) async {
  ref.watch(currentUserIdProvider);
  // Koç modülü tabloları kurulmamışsa sessizce boş döner.
  Future<List<Map<String, dynamic>>> safe(
      Future<List<Map<String, dynamic>>> Function() f) async {
    try {
      return await f();
    } catch (_) {
      return [];
    }
  }

  final results = await Future.wait([
    safe(SupabaseService.getMyNutritionPlan),
    safe(SupabaseService.getMyCoachNotes),
  ]);
  return CoachContent(nutritionPlan: results[0], notes: results[1]);
});

/// Ana sayfada koçtan gelen içerik varsa gösterilen özet kartı.
class CoachSummaryCard extends ConsumerWidget {
  const CoachSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(coachContentProvider).valueOrNull;
    if (content == null || content.isEmpty) return const SizedBox.shrink();

    final latestNote =
        content.notes.isNotEmpty ? content.notes.first['note'] as String? : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Material(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/coach'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.support_agent_rounded,
                      color: AppColors.secondary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Koçundan',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        latestNote ??
                            '${content.nutritionPlan.length} öğünlük beslenme planın hazır',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Koçun atadığı beslenme planı ve notların tam listesi.
class TrackingScreen extends ConsumerWidget {
  const TrackingScreen({super.key});

  static const _mealOrder = ['Kahvaltı', 'Ara Öğün', 'Öğle', 'Akşam'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(coachContentProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Koçum')),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.refresh(coachContentProvider.future),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ListView(
            children: const [
              SizedBox(height: 120),
              Center(
                child: Text('İçerik yüklenemedi',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            ],
          ),
          data: (content) {
            if (content.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(32),
                children: const [
                  SizedBox(height: 60),
                  Icon(Icons.support_agent_rounded,
                      size: 64, color: AppColors.textHint),
                  SizedBox(height: 16),
                  Text(
                    'Henüz koçundan bir plan yok',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'KaloriID\'ni Profil sekmesinden koçunla paylaş; '
                    'atadığı plan ve notlar burada görünecek.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              );
            }

            final plan = [...content.nutritionPlan]..sort((a, b) {
                int idx(Map m) {
                  final i = _mealOrder.indexOf(m['meal_time'] as String? ?? '');
                  return i < 0 ? 99 : i;
                }

                return idx(a).compareTo(idx(b));
              });

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                if (plan.isNotEmpty) ...[
                  const _SectionTitle('BESLENME PLANI'),
                  ...plan.map((item) => _PlanItem(item: item)),
                  const SizedBox(height: 20),
                ],
                if (content.notes.isNotEmpty) ...[
                  const _SectionTitle('KOÇ NOTLARI'),
                  ...content.notes.map((n) => _NoteItem(note: n)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(text,
          style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1)),
    );
  }
}

class _PlanItem extends StatelessWidget {
  final Map<String, dynamic> item;
  const _PlanItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final kcal = item['target_calories'];
    final notes = item['notes'] as String?;
    String macro(String key, String label) {
      final v = item[key];
      return v == null ? '' : '$label ${(v as num).toStringAsFixed(0)}g  ';
    }

    final macros =
        '${macro('target_protein', 'P')}${macro('target_carbs', 'K')}${macro('target_fat', 'Y')}'
            .trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(item['meal_time'] ?? '',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              if (kcal != null)
                Text('$kcal kcal',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          Text(item['meal_name'] ?? '',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          if (macros.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(macros,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ],
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(notes,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}

class _NoteItem extends StatelessWidget {
  final Map<String, dynamic> note;
  const _NoteItem({required this.note});

  @override
  Widget build(BuildContext context) {
    final created = DateTime.tryParse(note['created_at']?.toString() ?? '')
        ?.toLocal();
    final date = created == null
        ? ''
        : '${created.day.toString().padLeft(2, '0')}.${created.month.toString().padLeft(2, '0')}.${created.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.format_quote_rounded,
              color: AppColors.secondary, size: 20),
          const SizedBox(height: 4),
          Text(note['note'] ?? '',
              style: const TextStyle(color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text(
            '${(note['category'] as String? ?? 'genel').toUpperCase()} · $date',
            style: const TextStyle(color: AppColors.textHint, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
