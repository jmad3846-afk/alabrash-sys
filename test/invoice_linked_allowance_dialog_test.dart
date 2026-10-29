import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:abaad/core/database/erp_provider.dart';
import 'package:abaad/widgets/return_allowance_dialog.dart';
void main() {
  for (final module in ['factory', 'workshop']) {
    for (final kind in ['sales_allowance', 'purchase_allowance']) {
      testWidgets('$module $kind requires parent even with no invoices', (tester) async {
        SharedPreferences.setMockInitialValues({});
        GoogleFonts.config.allowRuntimeFetching = false;
        final erp = ERPProvider(); await erp.loadFuture;
        erp.factoryInvoices.clear(); erp.workshopInvoices.clear();
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: ReturnAllowanceDialog(erp: erp, module: module, kind: kind, title: 'Allowance'))));
        await tester.pumpAndSettle();
        expect(find.byType(SegmentedButton<bool>), findsNothing);
        expect(find.textContaining('خارج الفاتورة'), findsNothing);
        await tester.tap(find.text('حفظ فاتورة السمح'));
        await tester.pumpAndSettle();
        expect(find.text('اختر الفاتورة الأصلية أولاً.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        erp.dispose();
      });
    }
  }
}