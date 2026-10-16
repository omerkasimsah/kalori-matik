import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import 'client_detail_screen.dart';

// ────────────────────────────────────────────────────────────────────────────
// Profesyonel Panel — Koç & Diyetisyen Ana Ekranı
// ────────────────────────────────────────────────────────────────────────────
class ProfessionalDashboard extends ConsumerStatefulWidget {
  const ProfessionalDashboard({super.key});

  @override
  ConsumerState<ProfessionalDashboard> createState() =>
      _ProfessionalDashboardState();
}

class _ProfessionalDashboardState
    extends ConsumerState<ProfessionalDashboard>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _clients = [];
  final List<_FeedItem> _feedItems = [];
  RealtimeChannel? _feedChannel;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadClients().then((_) => _setupRealtimeFeed());
  }

  @override
  void dispose() {
    _feedChannel?.unsubscribe();
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Canlı Aktivite Feed'i ─────────────────────────────────────────────────
  void _setupRealtimeFeed() {
    final clientIds = _clients
        .map((c) => c['profiles']['id'].toString())
        .toList();
    if (clientIds.isEmpty) return;

    _feedChannel = SupabaseService.client
        .channel('professional:meal_logs:${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'meal_logs',
          callback: (payload) {
            final newLog = payload.newRecord;
            final userId = newLog['user_id'].toString();
            if (clientIds.contains(userId) && mounted) {
              final clientProf = _clients.firstWhere(
                  (c) => c['profiles']['id'].toString() == userId,
                  orElse: () => {})['profiles'];
              if (clientProf == null) return;
              setState(() {
                _feedItems.insert(
                  0,
                  _FeedItem(
                    kaloriId: clientProf['kalori_id'] ?? '?',
                    action: '${newLog['name']} • ${newLog['calories']} kcal',
                    type: 'meal',
                    time: DateTime.now(),
                  ),
                );
                if (_feedItems.length > 30) _feedItems.removeLast();
              });
            }
          },
        )
        .subscribe();
  }

  Future<void> _loadClients() async {
    setState(() => _isLoading = true);
    try {
      final clients = await SupabaseService.getMyClients();
      if (mounted) setState(() => _clients = clients);
    } catch (e) {
      if (mounted) {
        _showError('Danışanlar yüklenemedi: $e');
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.danger),
    );
  }

  void _showAddClientDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Danışan Ekle',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Danışanınızın Profil ekranında görünen 6 haneli KaloriID kodunu girin:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  letterSpacing: 4),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'A7B2X9',
                counterText: '',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = ctrl.text.trim().toUpperCase();
              if (val.length != 6) return;
              Navigator.pop(ctx);
              try {
                await SupabaseService.addClientByKaloriId(val);
                await _loadClients();
                _feedChannel?.unsubscribe();
                _setupRealtimeFeed();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Danışan başarıyla eklendi! 🎉'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  _showError(e.toString().replaceAll('Exception: ', ''));
                }
              }
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 0,
            pinned: true,
            backgroundColor: AppColors.background,
            elevation: 0.5,
            automaticallyImplyLeading: false,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profesyonel Panel',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${_clients.length} danışan',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_add,
                      color: AppColors.background, size: 18),
                ),
                tooltip: 'Danışan Ekle',
                onPressed: _showAddClientDialog,
              ),
              const SizedBox(width: 8),
            ],
            bottom: TabBar(
              controller: _tabCtrl,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(text: 'Danışanlarım'),
                Tab(text: 'Canlı Akış'),
              ],
            ),
          ),
        ],
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildClientList(),
                  _buildLiveFeed(),
                ],
              ),
      ),
    );
  }

  // ── Danışan Listesi ───────────────────────────────────────────────────────
  Widget _buildClientList() {
    if (_clients.isEmpty) return _buildEmptyState();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _clients.length,
      itemBuilder: (ctx, i) {
        final conn = _clients[i];
        final profile = conn['profiles'] as Map<String, dynamic>;
        final goal = profile['goal'] ?? 'maintain';
        final goalLabel = goal == 'lose'
            ? 'Kilo Ver'
            : goal == 'gain'
                ? 'Kilo Al'
                : 'Koru';
        final goalColor = goal == 'lose'
            ? AppColors.danger
            : goal == 'gain'
                ? AppColors.secondary
                : AppColors.primary;

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ClientDetailScreen(clientProfile: profile),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      (profile['kalori_id'] ?? '?').toString().substring(0, 1),
                      style: const TextStyle(
                          color: AppColors.background,
                          fontWeight: FontWeight.w900,
                          fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'KaloriID: ${profile['kalori_id'] ?? '-'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: goalColor.withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              goalLabel,
                              style: TextStyle(
                                  color: goalColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${profile['age'] ?? '-'} yaş • ${profile['weight'] ?? '-'} kg • ${(profile['daily_tdee'] ?? 0)} kcal/gün',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textHint),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Canlı Feed ────────────────────────────────────────────────────────────
  Widget _buildLiveFeed() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.textPrimary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Danışanlarınızın Canlı Aktivitesi',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ],
          ),
        ),
        Expanded(
          child: _feedItems.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bolt,
                          size: 64, color: AppColors.textHint),
                      SizedBox(height: 12),
                      Text(
                        'Henüz canlı aktivite yok',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Danışanlarınız öğün girdiğinde burada görünür',
                        style: TextStyle(
                            color: AppColors.textHint, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _feedItems.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final item = _feedItems[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(20),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.restaurant,
                                color: AppColors.primary, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.kaloriId,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppColors.primary),
                                ),
                                Text(
                                  item.action,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${item.time.hour.toString().padLeft(2, '0')}:${item.time.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                                color: AppColors.textHint, fontSize: 11),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_outline,
                  size: 52, color: AppColors.background),
            ),
            const SizedBox(height: 24),
            const Text(
              'Henüz danışanınız yok',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Danışanınızın profilindeki 6 haneli\nKaloriID kodunu girerek ekleyebilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _showAddClientDialog,
              icon: const Icon(Icons.add),
              label: const Text('Danışan Ekle'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Feed Item Modeli ─────────────────────────────────────────────────────────
class _FeedItem {
  final String kaloriId;
  final String action;
  final String type;
  final DateTime time;

  const _FeedItem({
    required this.kaloriId,
    required this.action,
    required this.type,
    required this.time,
  });
}
