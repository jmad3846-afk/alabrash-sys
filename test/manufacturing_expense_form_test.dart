import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:abaad/core/database/erp_provider.dart';
import 'package:abaad/core/models/models.dart';
import 'package:abaad/screens/accounting_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'expense form requires classification and capitalizes linked tonnage',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final erp = ERPProvider();
      await erp.loadFuture;
      erp.expenseTypes.clear();
      erp.expenseRecords.clear();
      erp.factoryBlocks.clear();
      erp.expenseTypes.add(
        ExpenseTypeModel(id: 'manual', name: 'أجور ومصاريف'),
      );
      final block = FactoryBlockModel(
        id: 'linked',
        blockCode: 'LINKED-001',
        typeName: 'test',
        grade: 'A',
        supplierId: '',
        supplierName: '',
        weightTons: 10,
        tonCost: 100,
      );
      erp.factoryBlocks.add(block);
      final cash = erp.mainCashBox;
      final pnl = erp.netOperatingProfit;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: erp,
          child: const MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: ExpensesManagementScreen(),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('إضافة مصروف'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إضافة المصروف وخصم قيمته'));
      await tester.pump();
      expect(
        find.text('حدد نوع المصروف وتحقق من المبلغ والكمية والمستفيد وحصته.'),
        findsOneWidget,
      );
      expect(erp.mainCashBox, cash);
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('مصروف قص وتصنيع مباشر').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'مبلغ المصروف'),
        '100',
      );
      final batch = find.widgetWithText(
        DropdownButtonFormField<String>,
        'البلوك / دفعة المخزون *',
      );
      await tester.ensureVisible(batch);
      await tester.tap(batch);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('LINKED-001').last);
      await tester.pumpAndSettle();
      final tons = find.widgetWithText(TextField, 'عدد الطونات *');
      await tester.ensureVisible(tons);
      await tester.enterText(tons, '10');
      await tester.tap(find.text('إضافة المصروف وخصم قيمته'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(erp.mainCashBox, cash - 100);
      expect(block.tonCost, 110);
      expect(erp.netOperatingProfit, pnl);
      expect(
        erp.expenseRecords.single.expenseType,
        ExpenseRecordModel.manufacturing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
