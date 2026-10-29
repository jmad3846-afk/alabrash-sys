import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:abaad/core/database/erp_provider.dart';
import 'package:abaad/core/models/models.dart';
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final module in ['factory', 'workshop']) {
    for (final kind in ['sales_allowance', 'purchase_allowance']) {
      for (final target in ['', 'standalone', 'none', 'missing-invoice']) {
        test('$module $kind rejects unlinked or nonexistent parent $target without mutations', () async {
          final erp = ERPProvider();
          await erp.loadFuture;
          final before = jsonEncode(erp.exportFullBackupData()..remove('metadata'));
          final doc = AdjustmentInvoiceModel(id: 'rejected', invoiceNo: 'A1', module: module, kind: kind, targetInvoiceId: target, targetInvoiceNo: '', partyName: 'party', description: 'allowance', amount: 100, quantity: 0, paymentAction: 'تخفيض دين', currency: AppCurrency.usd);
          expect(erp.addAdjustmentInvoice(doc), isFalse);
          expect(jsonEncode(erp.exportFullBackupData()..remove('metadata')), before);
          erp.dispose();
        });
      }
    }
  }
}