import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../home/providers/calorie_provider.dart';

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
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageFile = pickedFile;
          _imageBytes = bytes;
          _error = null;
        });
        await _analyzeImage();
      }
    } catch (e) {
      setState(() => _error = 'Görsel seçilemedi: $e');
    }
  }

  // Seçilen fotoğrafı Google Gemini Yapay Zeka Vision API'sine gönderen asıl analiz fonksiyonu
  Future<void> _analyzeImage() async {
    if (_imageFile == null) return;
    
    // Analiz animasyonunu (Yapay zeka tabağınızı inceliyor...) başlat
    setState(() => _isAnalyzing = true);

    try {
      // Resmi Uint8 formatında okuyup, API veri payload'ı için Base64 formatına çeviriyoruz
      final bytes = _imageBytes ?? await _imageFile!.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      // Çekirdek (Core) Gemini servisinde tanımlı HTTP POST isteğini yapıyoruz
      final mealData = await GeminiService.analyzeFoodImage(base64Image);

      // İstek başarılıysa, kullanıcının değerleri onaylayacağı Bottom Sheet (Alt Çekmece) arayüzünü aç
      if (mounted) {
        await _showResultSheet(mealData);
      }
    } catch (e) {
      setState(() =>
          _error = 'Analiz başarısız. API anahtarını kontrol edin.\nDetay: $e');
    } finally {
      // İşlem bitince (başarılı ya da hata olsa da) animasyonu durdur
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  // AI'dan dönen verileri (Kalori, Protein, Karb vb.) son onaya sunan arayüz
  Future<void> _showResultSheet(Map<String, dynamic> mealData) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MealResultSheet(
        mealData: mealData,
        imageFile: _imageFile,
        onConfirm: () async {
          // Kullanıcı onay verdiğinde: Riverpod mealLogsProvider üzerinden global state güncellenir
          ref.read(mealLogsProvider.notifier).addMeal(
                name: mealData['name'] ?? 'Bilinmeyen Yemek',
                calories: mealData['calories'] ?? 0,
                insight: mealData['insight'],
                protein: (mealData['protein'] as num?)?.toDouble(),
                carbs: (mealData['carbs'] as num?)?.toDouble(),
                fat: (mealData['fat'] as num?)?.toDouble(),
              );
          // Ekranı kapatıp tekrar ana ekrana dönüyoruz
          Navigator.pop(ctx);
          if (mounted) context.pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Yemek Ekle'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
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
            const SizedBox(height: 24),
            if (_isAnalyzing) ...[
              const _AnalyzingWidget(),
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
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: _PickButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Galeriden',
                      color: AppColors.textSecondary,
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
                ],
              ),
            ],
          ],
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
            AppColors.primaryLight.withAlpha(40),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withAlpha(60),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.restaurant_menu,
                size: 64, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          const Text(
            'Tabağının fotoğrafını çek',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Yapay zeka kalorisini hesaplasın!',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Analyzing Widget ─────────────────────────────────────────────────────────

class _AnalyzingWidget extends StatefulWidget {
  const _AnalyzingWidget();

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
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
          const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
          const SizedBox(height: 12),
          Text(
            'Yapay Zeka Tabağını İnceliyor...',
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ── Meal Result Bottom Sheet ──────────────────────────────────────────────────

class _MealResultSheet extends StatelessWidget {
  final Map<String, dynamic> mealData;
  final XFile? imageFile;
  final VoidCallback onConfirm;

  const _MealResultSheet({
    required this.mealData,
    required this.imageFile,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final name = mealData['name'] ?? 'Bilinmeyen Yemek';
    final calories = mealData['calories'] ?? 0;
    final protein = (mealData['protein'] as num?)?.toStringAsFixed(1) ?? '0';
    final carbs = (mealData['carbs'] as num?)?.toStringAsFixed(1) ?? '0';
    final fat = (mealData['fat'] as num?)?.toStringAsFixed(1) ?? '0';
    final insight = mealData['insight'] ?? '';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Yemek adı + kalori
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.restaurant, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(
                      '$calories kcal',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.danger),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Makro değerleri
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MacroChip(label: 'Protein', value: '${protein}g', color: const Color(0xFF3498DB)),
                _MacroChip(label: 'Karb', value: '${carbs}g', color: const Color(0xFFF39C12)),
                _MacroChip(label: 'Yağ', value: '${fat}g', color: const Color(0xFFE74C3C)),
              ],
            ),
          ),

          if (insight.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withAlpha(40)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tips_and_updates_outlined,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      insight,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Ekle butonu
          ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: const Text('Bankadan Düş! 🏦',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary)),
      ],
    );
  }
}
