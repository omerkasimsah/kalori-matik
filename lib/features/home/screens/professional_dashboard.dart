import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../models/meal_log.dart';
import 'client_detail_screen.dart';

/// Bir danışanın koç panelinde görünen özet durumu.
class ClientStatus {
  final Map<String, dynamic> connection;
  final Map<String, dynamic> profile;
  final List<MealLog> meals; // son 7 gün
  final DateTime now;

  ClientStatus(this.connection, this.profile, this.meals, this.now);

  String get id => profile['id'].toString();

  String get name {
    final n = (profile['full_name'] as String?)?.trim();
    return (n != null && n.isNotEmpty) ? n : 'KaloriID ${profile['kalori_id'] ?? '-'}';
  }

  int get target => (profile['daily_tdee'] as num?)?.toInt() ?? 2000;

  DateTime get today => DateTime(now.year, now.month, now.day);

  int get todayCalories =>
      meals.where((m) => m.day == today).fold(0, (s, m) => s + m.calories);

  DateTime? get lastLog => meals.isEmpty ? null : meals.first.createdAt;

  /// Bugün dahil geriye doğru kayıt girilmeyen gün sayısı (bugün boşsa 1).
  int get daysSinceLog {
    final last = lastLog;
    if (last == null) return 99;
    return today.difference(DateTime(last.year, last.month, last.day)).inDays;
  }

  int get weekAverage {
    final days = meals.map((m) => m.day).toSet().length;
    if (days == 0) return 0;
    return meals.fold<int>(0, (s, m) => s + m.calories) ~/ days;
  }

  /// attention: ilgi gerekir, good: yolunda, idle: henüz veri yok/bugün erken
  ClientHealth get health {
    if (daysSinceLog >= 2) return ClientHealth.attention;
    if (weekAverage > target * 1.15 || todayCalories > target * 1.1) {
      return ClientHealth.attention;
    }
    return ClientHealth.good;
  }

  String get reason {
    if (lastLog == null) return 'Henüz hiç kayıt girmedi';
    if (daysSinceLog >= 2) return '$daysSinceLog gündür kayıt yok';
    if (todayCalories > target * 1.1) return 'Bugün hedefi aştı';
    if (weekAverage > target * 1.15) return 'Haftalık ortalama hedefin üstünde';
    if (todayCalories == 0) return 'Bugün henüz kayıt yok';
    return 'Yolunda';
  }
}

enum ClientHealth { attention, good }

final clientStatusesProvider =
    FutureProvider.autoDispose<List<ClientStatus>>((ref) async {
  final connections = await SupabaseService.getMyClients();
  final ids = [for (final c in connections) c['profiles']['id'].toString()];
  final meals = await SupabaseService.getClientsMeals(ids, days: 7);
  final now = DateTime.now();
  final list = [
    for (final c in connections)
      ClientStatus(c, Map<String, dynamic>.from(c['profiles'] as Map),
          meals[c['profiles']['id'].toString()] ?? [], now)
  ];
  // İlgi gerekenler üstte, sonra en uzun süredir sessiz olanlar
  list.sort((a, b) {
    final h = a.health.index.compareTo(b.health.index);
    return h != 0 ? h : b.daysSinceLog.compareTo(a.daysSinceLog);
  });
  return list;
});

// ────────────────────────────────────────────────────────────────────────────
// Profesyonel Panel — Koç & Diyetisyen Ana Ekranı
// ────────────────────────────────────────────────────────────────────────────
class ProfessionalDashboard extends ConsumerStatefulWidget {
  const ProfessionalDashboard({super.key});

  @override
  ConsumerState<ProfessionalDashboard> createState() =>
      _ProfessionalDashboardState();
}

class _ProfessionalDashboardState extends ConsumerState<ProfessionalDashboard> {
  RealtimeChannel? _channel;
  List<String> _subscribedIds = [];

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  // Danışanlardan biri öğün eklediğinde listeyi yenile (demo modunda kapalı).
  void _subscribe(List<String> ids) {
    if (AppConfig.isDemo || ids.isEmpty || ids.join() == _subscribedIds.join()) {
      return;
    }
    _subscribedIds = ids;
    _channel?.unsubscribe();
    _channel = SupabaseService.client
        .channel('pro:meal_logs:${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'meal_logs',
          callback: (payload) {
            if (ids.contains(payload.newRecord['user_id'].toString()) &&
                mounted) {
              ref.invalidate(clientStatusesProvider);
            }
          },
        )
        .subscribe();
  }

  void _showAddClientDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Danışan Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Danışanının Profil ekranında görünen 6 haneli KaloriID kodunu gir:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              maxLength: 6,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 5),
              textAlign: TextAlign.center,
              decoration:
                  const InputDecoration(hintText: 'A7B2X9', counterText: ''),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final val = ctrl.text.trim().toUpperCase();
              if (val.length != 6) return;
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await SupabaseService.addClientByKaloriId(val);
                ref.invalidate(clientStatusesProvider);
                messenger.showSnackBar(const SnackBar(
                    content: Text('Danışan eklendi 🎉')));
              } catch (e) {
                messenger.showSnackBar(SnackBar(
                  content: Text(e.toString().replaceAll('Exception: ', ''),
                      style: TextStyle(color: AppColors.danger)),
                ));
              }
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çıkış yapılsın mı?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Çıkış Yap',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    await SupabaseService.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(clientStatusesProvider);
    final email = SupabaseService.getCurrentUser()?.email ?? '';

    ref.listen(clientStatusesProvider, (_, next) {
      final v = next.valueOrNull;
      if (v != null) _subscribe([for (final c in v) c.id]);
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddClientDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.background,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Danışan Ekle',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.refresh(clientStatusesProvider.future),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: AppColors.background,
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: false,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Danışanlarım',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary)),
                  Text(email,
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Çıkış',
                  icon: Icon(Icons.logout, color: AppColors.textSecondary),
                  onPressed: _logout,
                ),
              ],
            ),
            ...async.when(
              loading: () => [
                const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()))
              ],
              error: (_, __) => [
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off,
                            size: 48, color: AppColors.textSecondary),
                        const SizedBox(height: 12),
                        Text('Danışanlar yüklenemedi',
                            style: TextStyle(color: AppColors.textSecondary)),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(clientStatusesProvider),
                          child: const Text('Tekrar dene'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              data: (clients) => clients.isEmpty
                  ? [const SliverFillRemaining(child: _EmptyClients())]
                  : _buildList(clients),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildList(List<ClientStatus> clients) {
    final attention =
        clients.where((c) => c.health == ClientHealth.attention).length;
    final active = clients.where((c) => c.todayCalories > 0).length;

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              Expanded(
                  child: _Summary(
                      value: '${clients.length}',
                      label: 'Danışan',
                      color: AppColors.secondary)),
              const SizedBox(width: 10),
              Expanded(
                  child: _Summary(
                      value: '$active',
                      label: 'Bugün aktif',
                      color: AppColors.primary)),
              const SizedBox(width: 10),
              Expanded(
                  child: _Summary(
                      value: '$attention',
                      label: 'İlgi bekliyor',
                      color: attention > 0
                          ? AppColors.warning
                          : AppColors.textSecondary)),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        sliver: SliverList.separated(
          itemCount: clients.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _ClientCard(
            status: clients[i],
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    ClientDetailScreen(clientProfile: clients[i].profile),
              ));
              ref.invalidate(clientStatusesProvider);
            },
          ),
        ),
      ),
    ];
  }
}

class _Summary extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _Summary({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  final ClientStatus status;
  final VoidCallback onTap;
  const _ClientCard({required this.status, required this.onTap});

  static String _ago(DateTime? d) {
    if (d == null) return '—';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    return '${diff.inDays} gün önce';
  }

  @override
  Widget build(BuildContext context) {
    final s = status;
    final attention = s.health == ClientHealth.attention;
    final color = attention ? AppColors.warning : AppColors.primary;
    final progress = (s.todayCalories / s.target).clamp(0.0, 1.0);
    final goal = switch (s.profile['goal']) {
      'lose' => 'Kilo veriyor',
      'gain' => 'Kilo alıyor',
      _ => 'Kilosunu koruyor',
    };

    return Material(
      color: AppColors.cardSurface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: attention ? AppColors.warning.withAlpha(90) : Colors.transparent),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: color.withAlpha(30),
                    child: Text(
                      s.name.replaceFirst('KaloriID ', '').characters.first.toUpperCase(),
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary)),
                        Text(goal,
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withAlpha(25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(attention ? Icons.priority_high : Icons.check_circle,
                          size: 14, color: color),
                      const SizedBox(width: 4),
                      Text(attention ? 'İlgi' : 'Yolunda',
                          style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Bugün ${s.todayCalories} / ${s.target} kcal',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                  Text('Ort. ${s.weekAverage} kcal',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.surface,
                  valueColor: AlwaysStoppedAnimation(
                      s.todayCalories > s.target * 1.1
                          ? AppColors.danger
                          : AppColors.primary),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(attention ? Icons.warning_amber_rounded : Icons.schedule,
                      size: 15,
                      color: attention ? AppColors.warning : AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${s.reason} • Son kayıt: ${_ago(s.lastLog)}',
                      style: TextStyle(
                          fontSize: 12,
                          color: attention
                              ? AppColors.warning
                              : AppColors.textSecondary),
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      size: 20, color: AppColors.textSecondary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyClients extends StatelessWidget {
  const _EmptyClients();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
                gradient: AppColors.primaryGradient, shape: BoxShape.circle),
            child: Icon(Icons.people_outline,
                size: 48, color: AppColors.background),
          ),
          const SizedBox(height: 24),
          Text('Henüz danışanın yok',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(
            'Danışanından Profil ekranındaki 6 haneli KaloriID kodunu iste ve '
            '"Danışan Ekle" ile bağlan. Öğünlerini, kilosunu ve ilerlemesini '
            'buradan takip edebilirsin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}
