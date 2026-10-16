
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

/// Öğün düzenleyiciden dönen değerler.
class MealDraft {
  final String name;
  final int calories;
  final double? protein;
  final double? carbs;
  final double? fat;
  final String? insight;

  const MealDraft({
    required this.name,
    required this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.insight,
  });
}

/// Yapay zeka sonucunu onaylama, elle öğün ekleme ve mevcut öğünü düzenleme
/// için ortak alt sayfa. Kaydedilirse [MealDraft], iptalde null döner.
Future<MealDraft?> showMealEditorSheet(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  MealDraft? initial,
  Uint8List? imageBytes,
  bool showPortion = false,
}) {
  return showModalBottomSheet<MealDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _MealEditorSheet(
      title: title,
      confirmLabel: confirmLabel,
      initial: initial,
      imageBytes: imageBytes,
      showPortion: showPortion,
    ),
  );
}

class _MealEditorSheet extends StatefulWidget {
  final String title;
  final String confirmLabel;
  final MealDraft? initial;
  final Uint8List? imageBytes;
  final bool showPortion;

  const _MealEditorSheet({
    required this.title,
    required this.confirmLabel,
    required this.initial,
    required this.imageBytes,
    required this.showPortion,
  });

  @override
  State<_MealEditorSheet> createState() => _MealEditorSheetState();
}

class _MealEditorSheetState extends State<_MealEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _calories;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;

  static const _portions = [0.5, 0.75, 1.0, 1.5, 2.0];
  double _portion = 1.0;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _name = TextEditingController(text: i?.name ?? '');
    _calories = TextEditingController(text: i != null ? '${i.calories}' : '');
    _protein = TextEditingController(text: _fmt(i?.protein));
    _carbs = TextEditingController(text: _fmt(i?.carbs));
    _fat = TextEditingController(text: _fmt(i?.fat));
  }

  @override
  void dispose() {
    _name.dispose();
    _calories.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    super.dispose();
  }

  static String _fmt(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  }

  static double? _parse(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.'));

  void _applyPortion(double portion) {
    final base = widget.initial;
    if (base == null) return;
    setState(() => _portion = portion);
    _calories.text = '${(base.calories * portion).round()}';
    if (base.protein != null) _protein.text = _fmt(base.protein! * portion);
    if (base.carbs != null) _carbs.text = _fmt(base.carbs! * portion);
    if (base.fat != null) _fat.text = _fmt(base.fat! * portion);
  }

  /// Makrolardan kalori önerisi (4/4/9 kuralı).
  int? get _caloriesFromMacros {
    final p = _parse(_protein.text), c = _parse(_carbs.text), f = _parse(_fat.text);
    if (p == null && c == null && f == null) return null;
    return ((p ?? 0) * 4 + (c ?? 0) * 4 + (f ?? 0) * 9).round();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      MealDraft(
        name: _name.text.trim(),
        calories: int.parse(_calories.text.trim()),
        protein: _parse(_protein.text),
        carbs: _parse(_carbs.text),
        fat: _parse(_fat.text),
        insight: widget.initial?.insight,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final insight = widget.initial?.insight;
    final suggested = _caloriesFromMacros;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (widget.imageBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(widget.imageBytes!,
                          width: 56, height: 56, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Text(widget.title,
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                ],
              ),
              if (insight != null && insight.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withAlpha(40)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.tips_and_updates_outlined,
                          color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(insight,
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontStyle: FontStyle.italic)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Yemek adı',
                  prefixIcon: Icon(Icons.restaurant),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Yemek adı girin' : null,
              ),
              if (widget.showPortion && widget.initial != null) ...[
                const SizedBox(height: 16),
                Text('Porsiyon',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final p in _portions)
                      ChoiceChip(
                        label: Text('${_fmt(p)}x'),
                        selected: _portion == p,
                        onSelected: (_) => _applyPortion(p),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: _portion == p
                              ? AppColors.background
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        backgroundColor: AppColors.cardSurface,
                        side: BorderSide.none,
                        showCheckmark: false,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _calories,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Kalori (kcal)',
                  prefixIcon: const Icon(Icons.local_fire_department_outlined),
                  helperText: suggested != null
                      ? 'Makrolara göre ≈ $suggested kcal'
                      : null,
                ),
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  if (n == null) return 'Kalori girin';
                  if (n <= 0 || n > 10000) return '1–10000 arası bir değer girin';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                      child: _MacroField(
                          controller: _protein,
                          label: 'Protein',
                          color: AppColors.protein,
                          onChanged: () => setState(() {}))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _MacroField(
                          controller: _carbs,
                          label: 'Karb',
                          color: AppColors.carbs,
                          onChanged: () => setState(() {}))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _MacroField(
                          controller: _fat,
                          label: 'Yağ',
                          color: AppColors.fat,
                          onChanged: () => setState(() {}))),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submit,
                child: Text(widget.confirmLabel),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('İptal',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MacroField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final Color color;
  final VoidCallback onChanged;

  const _MacroField({
    required this.controller,
    required this.label,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      onChanged: (_) => onChanged(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'g',
        labelStyle: TextStyle(color: color),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return null;
        final n = double.tryParse(v.trim().replaceAll(',', '.'));
        if (n == null || n < 0 || n > 1000) return 'Geçersiz';
        return null;
      },
    );
  }
}
