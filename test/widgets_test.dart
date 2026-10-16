import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalori_matik/features/home/models/meal_log.dart';
import 'package:kalori_matik/features/home/widgets/meal_editor_sheet.dart';
import 'package:kalori_matik/features/home/widgets/meal_list_item.dart';

void main() {
  testWidgets('MealListItem öğün bilgilerini gösterir ve silinebilir',
      (tester) async {
    var deleted = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MealListItem(
          meal: MealLog(
            id: '1',
            name: 'Izgara Tavuk',
            calories: 420,
            createdAt: DateTime(2026, 10, 16, 12, 30),
            protein: 45,
          ),
          onDelete: () => deleted = true,
        ),
      ),
    ));

    expect(find.text('Izgara Tavuk'), findsOneWidget);
    expect(find.text('420'), findsOneWidget);
    expect(find.text('12:30'), findsOneWidget);
    expect(find.text('P: 45g'), findsOneWidget);
    expect(find.text('🍗'), findsOneWidget);

    await tester.drag(find.byType(Dismissible), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
  });

  testWidgets('Öğün düzenleyici doğrular, porsiyonu ölçekler ve sonuç döner',
      (tester) async {
    MealDraft? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showMealEditorSheet(
                  context,
                  title: 'Test',
                  confirmLabel: 'Kaydet',
                  showPortion: true,
                  initial: const MealDraft(
                      name: 'Pilav', calories: 300, carbs: 60),
                );
              },
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();

    // 2x porsiyon → kalori ve karbonhidrat ikiye katlanır
    await tester.tap(find.text('2x'));
    await tester.pump();
    expect(find.widgetWithText(TextFormField, '600'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '120'), findsOneWidget);

    // Boş isim kaydedilemez
    await tester.enterText(find.widgetWithText(TextFormField, 'Pilav'), '');
    await tester.tap(find.text('Kaydet'));
    await tester.pump();
    expect(find.text('Yemek adı girin'), findsOneWidget);
    expect(result, isNull);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Yemek adı'), 'Bulgur Pilavı');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.name, 'Bulgur Pilavı');
    expect(result!.calories, 600);
    expect(result!.carbs, 120);
  });
}
