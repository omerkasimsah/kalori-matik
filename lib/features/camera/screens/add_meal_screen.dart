import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/gemini_service.dart';
import '../../../core/services/haptics.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../home/models/meal_log.dart';
import '../../home/providers/calorie_provider.dart';
import '../../home/widgets/meal_editor_sheet.dart';

/// Son 14 günde en çok eklenen öğünler (hızlı ekleme için).
final recentMealsProvider = FutureProvider.autoDispose<List<MealLog>>((ref) async {
  ref.watch(currentUserIdProvider);
  final meals = await SupabaseService.getAllMeals(days: 14);
  final counts = <String, int>{};
  final latest = <String, MealLog>{};
  for (final m in meals) {
    final key = m.name.trim().toLowerCase();
    counts[key] = (counts[key] ?? 0) + 1;
    latest.putIfAbsent(key, () => m);
  }
  final keys = counts.keys.toList()
    ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  return keys.take(8).map((k) => latest[k]!).toList();
});

class AddMealScreen extends ConsumerStatefulWidget {
  const AddMealScreen({super.key});

  @override
  ConsumerState<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends ConsumerState<AddMealScreen> {
  // Cihaz kamerasından veya galeriden fotoğraf seçmeyi sağlayan paket nesnesi
  final ImagePicker _picker = ImagePicker();

  // Seçilen fotoğrafın bellek referansları
  XFile? _imageFile;
  Uint8List? _imageBytes;

  // Gemini yapay zeka API isteği süresince UI yükleme durumu
  bool _isAnalyzing = false;
  bool _isSaving = false;

  // API veya Fotoğraf seçme sırasındaki olası hataları tutan state
  String? _error;

  // Fotoğraf çekme veya Galeriden seçme (Source) işlemini başlatan fonksiyon
  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (pickedFile == null) return;
      final bytes = await pickedFile.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageFile = pickedFile;
        _imageBytes = bytes;
        _error = null;
      });
      await _analyzeImage();
    } catch (e) {
      if (mounted) {
        setState(() => _error =
            'Görsel seçilemedi. Kamera/galeri iznini kontrol edin.');
      }
    }
  }

  String _mimeTypeOf(XFile file) {
    final mime = file.mimeType;
    if (mime != null && mime.startsWith('image/')) return mime;
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  // Seçilen fotoğrafı Gemini Vision API'sine gönderen asıl analiz fonksiyonu
  Future<void> _analyzeImage() async {
    final file = _imageFile;
    final bytes = _imageBytes;
    if (file == null || bytes == null) return;

    setState(() {
      _isAnalyzing = true;
      _error = null;
    });

    try {
      final result = await GeminiService.analyzeFoodImage(
        base64Encode(bytes),
        mimeType: _mimeTypeOf(file),
      );
      if (!mounted) return;
      setState(() => _isAnalyzing = false);

      if (result.calories == 0 && result.name == 'Yiyecek bulunamadı') {
        setState(() => _error =
            'Fotoğrafta yiyecek tanınamadı. Farklı bir açıdan deneyin veya elle ekleyin.');
        return;
      }

      await _openEditor(
        title: 'Yapay zeka sonucu',
        initial: MealDraft(
          name: result.name,
          calories: result.calories,
          protein: result.protein,
          carbs: result.carbs,
          fat: result.fat,
          insight: result.insight,
        ),
        showPortion: true,
        withImage: true,
      );
    } on GeminiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Analiz başarısız oldu. Lütfen tekrar deneyin.');
      }
    } finally {
      if (mounted && _isAnalyzing) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _openEditor({
    required String title,
    MealDraft? initial,
    bool showPortion = false,
    bool withImage = false,
  }) async {
    final draft = await showMealEditorSheet(
      context,
      title: title,
      confirmLabel: 'Öğünü Kaydet',
      initial: initial,
      imageBytes: withImage ? _imageBytes : null,
      showPortion: showPortion,
    );
    if (draft != null) await _save(draft);
  }

  Future<void> _save(MealDraft draft) async {
    setState(() => _isSaving = true);
    try {
      await ref.read(mealLogsProvider.notifier).addMeal(
            name: draft.name,
            calories: draft.calories,
            insight: draft.insight,
            protein: draft.protein,
            carbs: draft.carbs,
            fat: draft.fat,
          );
      Haptics.success();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${draft.name} eklendi (${draft.calories} kcal)')),
      );
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Öğün kaydedilemedi. Bağlantınızı kontrol edin.',
              style: TextStyle(color: AppColors.danger)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final recent = ref.watch(recentMealsProvider);
    final busy = _isAnalyzing || _isSaving;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Yemek Ekle'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _imageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.memory(
                          _imageBytes!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      )
                    : _buildPlaceholder(),
              ),
              const SizedBox(height: 20),
              if (busy) ...[
                _AnalyzingWidget(
                  label: _isSaving
                      ? 'Kaydediliyor...'
                      : 'Yapay Zeka Tabağını İnceliyor...',
                ),
              ] else ...[
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.danger.withAlpha(60)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _error!,
                          style: TextStyle(
                              color: AppColors.danger, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        if (_imageBytes != null)
                          TextButton.icon(
                            onPressed: _analyzeImage,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Tekrar dene'),
                          ),
                      ],
                    ),
                  ),
                recent.maybeWhen(
                  data: (meals) => meals.isEmpty
                      ? const SizedBox.shrink()
                      : _RecentMeals(
                          meals: meals,
                          onTap: (m) => _openEditor(
                            title: 'Tekrar ekle',
                            initial: MealDraft(
                              name: m.name,
                              calories: m.calories,
                              protein: m.protein,
                              carbs: m.carbs,
                              fat: m.fat,
                            ),
                            showPortion: true,
                          ),
                        ),
                  orElse: () => const SizedBox.shrink(),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _PickButton(
                        icon: Icons.photo_library_outlined,
                        label: 'Galeriden',
                        color: AppColors.secondary,
                        onTap: () => _pickImage(ImageSource.gallery),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PickButton(
                        icon: Icons.camera_alt_outlined,
                        label: 'Fotoğraf Çek',
                        color: AppColors.primary,
                        onTap: () => _pickImage(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PickButton(
                        icon: Icons.edit_note_rounded,
                        label: 'Elle Ekle',
                        color: AppColors.carbs,
                        onTap: () => _openEditor(title: 'Elle öğün ekle'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withAlpha(20),
            AppColors.secondary.withAlpha(25),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withAlpha(60)),
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.restaurant_menu,
                    size: 64, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              Text(
                'Tabağının fotoğrafını çek',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Yapay zeka kalorisini hesaplasın!',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Son Öğünler (Hızlı Ekleme) ───────────────────────────────────────────────

class _RecentMeals extends StatelessWidget {
  final List<MealLog> meals;
  final ValueChanged<MealLog> onTap;

  const _RecentMeals({required this.meals, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SIK YEDİKLERİN',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1)),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: meals.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final m = meals[i];
                return ActionChip(
                  onPressed: () => onTap(m),
                  backgroundColor: AppColors.cardSurface,
                  side: BorderSide.none,
                  label: Text('${m.name} · ${m.calories}',
                      style: TextStyle(
                          color: AppColors.textPrimary, fontSize: 12)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Analyzing Widget ─────────────────────────────────────────────────────────

class _AnalyzingWidget extends StatefulWidget {
  final String label;
  const _AnalyzingWidget({required this.label});

  @override
  State<_AnalyzingWidget> createState() => _AnalyzingWidgetState();
}

class _AnalyzingWidgetState extends State<_AnalyzingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Column(
        children: [
          CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 3),
          const SizedBox(height: 12),
          Text(
            widget.label,
            style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ── Pick Button ───────────────────────────────────────────────────────────────

class _PickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PickButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withAlpha(15),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withAlpha(80)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
