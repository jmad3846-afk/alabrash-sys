import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';
import '../core/theme/app_theme.dart';
import '../widgets/currency_selector.dart';

const _fixedAssetCategories = [
  'أراضي',
  'مباني وعقارات',
  'آلات ومعدات',
  'آليات ونقل',
  'أثاث',
];

class OpeningStockItemsPanel extends StatelessWidget {
  final List<OpeningStockItemModel> items;
  final String category;

  const OpeningStockItemsPanel({
    super.key,
    required this.items,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    // Hidden per specification: opening stocks integrate natively into operational inventory interfaces
    return const SizedBox.shrink();
  }
}

class ChartOfAccountsScreen extends StatelessWidget {
  const ChartOfAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final erp = context.watch<ERPProvider>();
    final allAssets = erp.openingEntry.fixedAssets;
    final assets = allAssets.where((a) => !a.isSold).toList();
    final currentStockValue =
        erp.factoryBlocks.fold<double>(0, (sum, item) => sum + item.totalCost) +
        erp.factoryWarehouse.fold<double>(
          0,
          (sum, item) => sum + item.totalInventoryValue,
        ) +
        erp.workshopStock.fold<double>(
          0,
          (sum, item) => sum + item.availableQty * item.netCostPerUnit,
        );
    final historical = erp.openingEntry.legacyFinancials;
    final suppliers = historical
        .where((r) => r.category == 'suppliers')
        .toList();
    final employees = historical
        .where((r) => r.category == 'employees')
        .toList();
    final customers = historical.where((r) => r.category == 'clients').toList();
    final supplierAmount =
        '${suppliers.where((r) => r.currency == AppCurrency.usd).fold<double>(0, (sum, r) => sum + r.amount).fmt} \$ • ${suppliers.where((r) => r.currency == AppCurrency.syp).fold<double>(0, (sum, r) => sum + r.amount).fmt} ل.س';
    final employeeAmount =
        '${employees.where((r) => r.currency == AppCurrency.usd).fold<double>(0, (sum, r) => sum + r.amount).fmt} \$ • ${employees.where((r) => r.currency == AppCurrency.syp).fold<double>(0, (sum, r) => sum + r.amount).fmt} ل.س';
    final clientAmount =
        '${customers.where((r) => r.currency == AppCurrency.usd).fold<double>(0, (sum, r) => sum + r.amount).fmt} \$ • ${customers.where((r) => r.currency == AppCurrency.syp).fold<double>(0, (sum, r) => sum + r.amount).fmt} ل.س';
    final assetUsd = assets
        .where((a) => a.currency == AppCurrency.usd)
        .fold<double>(0, (sum, a) => sum + a.amount);
    final assetSyp = assets
        .where((a) => a.currency == AppCurrency.syp)
        .fold<double>(0, (sum, a) => sum + a.amount);
    final openingFixedUsd = assets.isEmpty
        ? erp.openingEntry.totalFixedAssets
        : assetUsd;
    final openingStockUsd = erp.openingEntry.openingStock
        .where((item) => item.currency == AppCurrency.usd)
        .fold<double>(0, (sum, item) => sum + item.totalPrice);
    final openingStockSyp = erp.openingEntry.openingStock
        .where((item) => item.currency == AppCurrency.syp)
        .fold<double>(0, (sum, item) => sum + item.totalPrice);
    final stockUsd =
        currentStockValue +
        openingStockUsd +
        (erp.openingEntry.openingStock.isEmpty
            ? erp.openingEntry.inventoryValue
            : 0);
    final historicalClientsUsd = customers
        .where((record) => record.currency == AppCurrency.usd)
        .fold<double>(0, (sum, record) => sum + record.amount);
    final historicalClientsSyp = customers
        .where((record) => record.currency == AppCurrency.syp)
        .fold<double>(0, (sum, record) => sum + record.amount);
    final clientsUsd = customers.isEmpty
        ? (erp.clientsTotalDebts > erp.openingEntry.customerDebtsValue
              ? erp.clientsTotalDebts
              : erp.openingEntry.customerDebtsValue)
        : historicalClientsUsd + erp.clientsTotalDebts;
    final clientsSyp =
        historicalClientsSyp +
        (customers.isEmpty
            ? erp.clientsTotalDebtsSyp
            : erp.clientsTotalDebtsSyp);
    final historicalSuppliersUsd = suppliers
        .where((record) => record.currency == AppCurrency.usd)
        .fold<double>(0, (sum, record) => sum + record.amount);
    final historicalSuppliersSyp = suppliers
        .where((record) => record.currency == AppCurrency.syp)
        .fold<double>(0, (sum, record) => sum + record.amount);
    final suppliersUsd = suppliers.isEmpty
        ? (erp.suppliersTotalDebts > erp.openingEntry.supplierPayablesValue
              ? erp.suppliersTotalDebts
              : erp.openingEntry.supplierPayablesValue)
        : historicalSuppliersUsd + erp.suppliersTotalDebts;
    final suppliersSyp = historicalSuppliersSyp + erp.suppliersTotalDebtsSyp;
    final historicalEmployeesUsd = employees
        .where((record) => record.currency == AppCurrency.usd)
        .fold<double>(0, (sum, record) => sum + record.amount);
    final historicalEmployeesSyp = employees
        .where((record) => record.currency == AppCurrency.syp)
        .fold<double>(0, (sum, record) => sum + record.amount);
    final employeesUsd = employees.isEmpty
        ? (erp.workersTotalDebts > erp.openingEntry.workerSalariesValue
              ? erp.workersTotalDebts
              : erp.openingEntry.workerSalariesValue)
        : historicalEmployeesUsd + erp.workersTotalDebts;
    final employeesSyp = historicalEmployeesSyp + erp.workersTotalDebtsSyp;
    final assetsUsdNow =
        openingFixedUsd +
        erp.mainCashBox +
        erp.scrapCashBox +
        erp.orderCashBox +
        stockUsd +
        clientsUsd;
    final assetsSypNow =
        assetSyp +
        erp.mainCashBoxSyp +
        erp.scrapCashBoxSyp +
        erp.orderCashBoxSyp +
        openingStockSyp +
        clientsSyp;
    final liabilitiesUsdNow = suppliersUsd + employeesUsd;
    final liabilitiesSypNow = suppliersSyp + employeesSyp;
    final expenseUsd = erp.expenseRecords
        .where((e) => e.currency == AppCurrency.usd)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final expenseSyp = erp.expenseRecords
        .where((e) => e.currency == AppCurrency.syp)
        .fold<double>(0, (sum, e) => sum + e.amount);
    double adjustmentAmount(String kind, String currency) => erp
        .adjustmentInvoices
        .where(
          (invoice) => invoice.kind == kind && invoice.currency == currency,
        )
        .fold<double>(0, (sum, invoice) => sum + invoice.amount);
    double salesDiscount(String currency) =>
        erp.factoryInvoices
            .where(
              (invoice) =>
                  invoice.invoiceType == 'بيع_معتمد' &&
                  invoice.currency == currency,
            )
            .fold<double>(0, (sum, invoice) => sum + invoice.discountAmount) +
        erp.workshopInvoices
            .where((invoice) => invoice.currency == currency)
            .fold<double>(0, (sum, invoice) => sum + invoice.salesDiscount);
    double purchaseDiscount(String currency) => erp.factoryInvoices
        .where(
          (invoice) =>
              invoice.invoiceType == 'شراء_مورد' &&
              invoice.currency == currency,
        )
        .fold<double>(0, (sum, invoice) => sum + invoice.discountAmount);
    double serviceRevenue(String currency) =>
        erp.factoryInvoices
            .where((invoice) => invoice.currency == currency)
            .fold<double>(
              0,
              (sum, invoice) =>
                  sum + invoice.servicesTotal + invoice.itemsServicesTotal,
            ) +
        erp.workshopInvoices
            .where((invoice) => invoice.currency == currency)
            .fold<double>(0, (sum, invoice) => sum + invoice.servicesTotal);
    double factoryPurchaseAmount(String currency) => erp.factoryInvoices
        .where(
          (invoice) =>
              invoice.invoiceType == 'شراء_مورد' &&
              invoice.currency == currency,
        )
        .fold<double>(0, (sum, invoice) => sum + invoice.grandTotal);
    String fixedAssetDetails(String category) {
      final categoryAssets = assets
          .where((asset) => asset.category == category)
          .toList();
      if (categoryAssets.isNotEmpty) {
        return categoryAssets
            .map(
              (asset) =>
                  '${asset.name} • ${asset.amount.fmt} ${AppCurrency.symbol(asset.currency)}',
            )
            .join('\n');
      }
      final legacyAmount = switch (category) {
        'أراضي' => erp.openingEntry.landValue,
        'مباني وعقارات' => erp.openingEntry.buildingsValue,
        'آلات ومعدات' => erp.openingEntry.machineryValue,
        'آليات ونقل' => erp.openingEntry.vehiclesValue,
        'أثاث' => erp.openingEntry.furnitureValue,
        _ => 0.0,
      };
      return legacyAmount > 0 ? '${legacyAmount.fmt} \$ • رصيد مجمع' : '';
    }

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('دليل الحسابات', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text(
            'ملخص موحد للحسابات الافتتاحية والحركات المسجلة في المصنع والمعمل والمالية.',
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الميزانية العمومية الحالية • مباشرة',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 20,
                    runSpacing: 8,
                    children: [
                      _accountLine(
                        'إجمالي الأصول • USD',
                        '${assetsUsdNow.fmt} \$',
                      ),
                      _accountLine(
                        'إجمالي الالتزامات • USD',
                        '${liabilitiesUsdNow.fmt} \$',
                      ),
                      _accountLine(
                        'حقوق الملكية • USD',
                        '${(assetsUsdNow - liabilitiesUsdNow).fmt} \$',
                      ),
                      _accountLine(
                        'إجمالي الأصول • SYP',
                        '${assetsSypNow.fmt} ل.س',
                      ),
                      _accountLine(
                        'إجمالي الالتزامات • SYP',
                        '${liabilitiesSypNow.fmt} ل.س',
                      ),
                      _accountLine(
                        'حقوق الملكية • SYP',
                        '${(assetsSypNow - liabilitiesSypNow).fmt} ل.س',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _accountGroup('الأصول', Icons.account_balance_wallet_outlined, [
            _accountGroup(
              'الأصول الثابتة • الإجمالي ${openingFixedUsd.fmt} \$ • ${assetSyp.fmt} ل.س',
              Icons.apartment,
              [
                for (final category in _fixedAssetCategories)
                  _accountLine(category, fixedAssetDetails(category)),
              ],
            ),
            _accountGroup('الأصول المتداولة', Icons.payments_outlined, [
              _accountLine(
                'الصناديق • USD',
                'رئيسي: ${erp.mainCashBox.fmt} \$ • خردة: ${erp.scrapCashBox.fmt} \$ • طلبيات: ${erp.orderCashBox.fmt} \$',
              ),
              _accountLine(
                'الصناديق • SYP',
                'رئيسي: ${erp.mainCashBoxSyp.fmt} ل.س • خردة: ${erp.scrapCashBoxSyp.fmt} ل.س • طلبيات: ${erp.orderCashBoxSyp.fmt} ل.س',
              ),
              _accountLine(
                'البضائع والمخزون',
                '${(currentStockValue + openingStockUsd + (erp.openingEntry.openingStock.isEmpty ? erp.openingEntry.inventoryValue : 0)).fmt} \$ • ${openingStockSyp.fmt} ل.س',
              ),
              _accountLine(
                'ذمم العملاء الافتتاحية',
                '$clientAmount • ${customers.length} حساب',
              ),
              _accountLine(
                'أرصدة المخزون الافتتاحي',
                erp.openingEntry.openingStock
                    .map((item) {
                      return '${item.typeName}: ${item.quantity.fmt} × ${item.unitPrice.fmt} = ${item.totalPrice.fmt} ${AppCurrency.symbol(item.currency)}';
                    })
                    .join('\n'),
              ),
            ]),
          ]),
          _accountGroup('الالتزامات', Icons.receipt_long_outlined, [
            _accountGroup('الالتزامات المتداولة', Icons.pending_actions, [
              _clickableLegacyLine(
                context,
                erp,
                'ذمم الموردين',
                supplierAmount,
                suppliers,
                'suppliers',
              ),
              _clickableLegacyLine(
                context,
                erp,
                'الرواتب والأجور المستحقة',
                employeeAmount,
                employees,
                'employees',
              ),
              _clickableCurrentDebts(
                context,
                'ديون الموردين التشغيلية',
                '${erp.suppliersTotalDebts.fmt} \$ • ${erp.suppliersTotalDebtsSyp.fmt} ل.س',
                [
                  for (final supplier in erp.suppliers)
                    if (supplier.debtBalance > 0 || supplier.debtBalanceSyp > 0)
                      ListTile(
                        title: Text(supplier.name),
                        subtitle: Text(
                          '${supplier.phone} • ${supplier.dualDebt}',
                        ),
                      ),
                ],
              ),
              _clickableCurrentDebts(
                context,
                'مستحقات العاملين التشغيلية',
                '${erp.workersTotalDebts.fmt} \$ • ${erp.workersTotalDebtsSyp.fmt} ل.س',
                [
                  for (final staff in erp.staffList)
                    if (staff.netRemainingBalance > 0 ||
                        staff.netRemainingBalanceSyp > 0)
                      ListTile(
                        title: Text(staff.name),
                        subtitle: Text(
                          '${staff.category} • ${staff.phone} • ${staff.dualNet}',
                        ),
                      ),
                ],
              ),
            ]),
          ]),
          _accountGroup('حقوق الملكية', Icons.groups_2_outlined, [
            _accountLine(
              'رأس المال الحالي',
              '${erp.partners.fold<double>(0, (sum, partner) => sum + partner.injectedCapital).fmt} \$ • ${erp.partners.fold<double>(0, (sum, partner) => sum + partner.injectedCapitalSyp).fmt} ل.س',
            ),
            for (final partner in erp.partners)
              _accountLine(
                partner.name,
                'الحصة ${(partner.ratio * 100).fmt}٪ • رأس المال ${AppCurrency.dual(partner.injectedCapital, partner.injectedCapitalSyp)} • مسحوبات ${AppCurrency.dual(partner.totalWithdrawn, partner.totalWithdrawnSyp)}',
              ),
            if (erp.capitalInjections.isNotEmpty)
              for (final inj in erp.capitalInjections)
                _accountLine(
                  inj.logEntryTitleAr,
                  '${inj.amount.fmt} ${AppCurrency.symbol(inj.currency)}',
                ),
            _accountLine(
              'الأرباح والخسائر الحالية',
              '${erp.netOperatingProfit.fmt} \$ • ${erp.netOperatingProfitSyp.fmt} ل.س',
            ),
          ]),
          _accountGroup('الإيرادات', Icons.trending_up, [
            _accountLine(
              'مبيعات البضائع',
              '${(erp.totalFactoryRevenue - erp.factoryServiceRevenueOf(AppCurrency.usd) + erp.factorySalesDiscountOf(AppCurrency.usd)).fmt} \$ • ${(erp.totalFactoryRevenueSyp - erp.factoryServiceRevenueOf(AppCurrency.syp) + erp.factorySalesDiscountOf(AppCurrency.syp)).fmt} ل.س',
            ),
            _accountLine(
              'الخدمات',
              '${serviceRevenue(AppCurrency.usd).fmt} \$ • ${serviceRevenue(AppCurrency.syp).fmt} ل.س',
            ),
            _accountLine(
              'مبيعات المعمل والقطع الزائدة',
              '${(erp.totalWorkshopRevenue - erp.workshopServiceRevenueOf(AppCurrency.usd) + erp.workshopSalesDiscountOf(AppCurrency.usd) + erp.totalScrapRevenue).fmt} \$ • ${(erp.totalWorkshopRevenueSyp - erp.workshopServiceRevenueOf(AppCurrency.syp) + erp.workshopSalesDiscountOf(AppCurrency.syp) + erp.totalScrapRevenueSyp).fmt} ل.س',
            ),
            _accountLine(
              'مرتجعات ومسموحات المشتريات',
              '${(adjustmentAmount('purchase_return', AppCurrency.usd) + adjustmentAmount('purchase_allowance', AppCurrency.usd)).fmt} \$ • ${(adjustmentAmount('purchase_return', AppCurrency.syp) + adjustmentAmount('purchase_allowance', AppCurrency.syp)).fmt} ل.س',
            ),
            _accountLine(
              'أرباح بيع الأصول الثابتة',
              '${erp.assetSaleGains.fmt} \$ • ${erp.assetSaleGainsSyp.fmt} ل.س',
            ),
            _accountLine(
              'الخصومات المكتسبة',
              '${(purchaseDiscount(AppCurrency.usd) + adjustmentAmount('purchase_discount', AppCurrency.usd)).fmt} \$ • ${(purchaseDiscount(AppCurrency.syp) + adjustmentAmount('purchase_discount', AppCurrency.syp)).fmt} ل.س',
            ),
            _accountLine(
              'إيرادات تحصيل واسترداد سُلف العمالة',
              '${erp.totalAdvanceRepaymentsRevenueOf(AppCurrency.usd).fmt} \$ • ${erp.totalAdvanceRepaymentsRevenueOf(AppCurrency.syp).fmt} ل.س',
            ),
          ]),
          _accountGroup('المصروفات', Icons.trending_down, [
            _accountLine(
              'المشتريات',
              '${factoryPurchaseAmount(AppCurrency.usd).fmt} \$ • ${factoryPurchaseAmount(AppCurrency.syp).fmt} ل.س',
            ),
            _accountLine(
              'تكلفة البضائع المباعة',
              '${erp.totalCOGS.fmt} \$ • ${erp.totalCOGSSyp.fmt} ل.س',
            ),
            _accountLine(
              'مرتجعات ومسموحات المبيعات',
              '${(adjustmentAmount('sales_return', AppCurrency.usd) + adjustmentAmount('sales_allowance', AppCurrency.usd)).fmt} \$ • ${(adjustmentAmount('sales_return', AppCurrency.syp) + adjustmentAmount('sales_allowance', AppCurrency.syp)).fmt} ل.س',
            ),
            _accountLine(
              'خصومات المبيعات',
              '${salesDiscount(AppCurrency.usd).fmt} \$ • ${salesDiscount(AppCurrency.syp).fmt} ل.س',
            ),
            _accountLine(
              'الرواتب والأجور',
              '${erp.totalOperationalExpenses.fmt} \$ • ${erp.totalOperationalExpensesSyp.fmt} ل.س',
            ),
            _accountLine(
              'المصروفات المباشرة',
              '${expenseUsd.fmt} \$ • ${expenseSyp.fmt} ل.س',
            ),
            _accountLine(
              'خسائر بيع الأصول الثابتة',
              '${erp.assetSaleLosses.fmt} \$ • ${erp.assetSaleLossesSyp.fmt} ل.س',
            ),
            for (final type in erp.expenseTypes)
              _accountLine(
                type.name,
                erp.expenseRecords
                    .where((e) => e.typeId == type.id)
                    .map(
                      (e) =>
                          '${e.amount.fmt} ${AppCurrency.symbol(e.currency)}',
                    )
                    .join(' • '),
              ),
          ]),
        ],
      ),
    );
  }

  Widget _accountGroup(String title, IconData icon, List<Widget> children) =>
      Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ExpansionTile(
          initiallyExpanded: true,
          leading: Icon(icon, color: AppColors.accentPrimary),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          children: children,
        ),
      );

  Widget _accountLine(String title, String value) => ListTile(
    dense: true,
    title: Text(title),
    subtitle: Text(value.isEmpty ? 'لا توجد أرصدة مسجلة' : value),
  );

  Widget _clickableLegacyLine(
    BuildContext context,
    ERPProvider erp,
    String title,
    String amount,
    List<LegacyFinancialRecordModel> records,
    String category,
  ) => ListTile(
    dense: true,
    title: Text(title),
    subtitle: Text('$amount • اضغط لعرض التفاصيل والتسوية'),
    trailing: const Icon(Icons.open_in_new),
    onTap: () => _showLegacyDetails(context, erp, title, records, category),
  );

  Widget _clickableCurrentDebts(
    BuildContext context,
    String title,
    String amount,
    List<Widget> details,
  ) => ListTile(
    dense: true,
    title: Text(title),
    subtitle: Text('$amount • اضغط لعرض التفاصيل'),
    trailing: const Icon(Icons.open_in_new),
    onTap: () => showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 520,
          child: details.isEmpty
              ? const Text('لا توجد أرصدة تشغيلية حالية.')
              : ListView(shrinkWrap: true, children: details),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    ),
  );

  Future<void> _showLegacyDetails(
    BuildContext context,
    ERPProvider erp,
    String title,
    List<LegacyFinancialRecordModel> records,
    String category,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 560,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final record in records)
                ListTile(
                  title: Text(record.name),
                  subtitle: Text(
                    '${record.phone} • ${record.description}\nالمتبقي: ${record.amount.fmt} ${AppCurrency.symbol(record.currency)}',
                  ),
                  trailing: record.amount <= 0
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : IconButton(
                          tooltip: category == 'clients' ? 'تحصيل' : 'تسديد',
                          icon: const Icon(Icons.payments_outlined),
                          onPressed: () async {
                            final amount = await _askAmount(
                              dialogContext,
                              record.amount,
                            );
                            if (amount == null) return;
                            final paid = erp.settleLegacyFinancialRecord(
                              record.id,
                              amount,
                              'main',
                            );
                            if (!paid && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'تعذر التسديد: تحقق من الرصيد المتاح في الصندوق.',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Future<double?> _askAmount(BuildContext context, double max) async {
    final controller = TextEditingController(text: max.fmt);
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('مبلغ التسوية'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'المبلغ'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0 && amount <= max) {
                Navigator.pop(dialogContext, amount);
              }
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}

class BalanceSheetScreen extends StatelessWidget {
  const BalanceSheetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final erp = context.watch<ERPProvider>();
    final entry = erp.openingEntry;
    final fixedUsd = entry.totalFixedAssetsOf(AppCurrency.usd);
    final fixedSyp = entry.totalFixedAssetsOf(AppCurrency.syp);
    double openingTailoredInventoryValue(
      List<WorkshopTailoringModel> products,
      String category,
    ) => products.fold<double>(0, (sum, product) {
      final openingRows = entry.openingStock
          .where(
            (item) => item.category == category && item.typeId == product.id,
          )
          .toList();
      if (openingRows.isEmpty) return sum;
      final openingQuantity = openingRows.fold<double>(
        0,
        (rowSum, item) => rowSum + item.quantity,
      );
      if (openingQuantity <= 0) return sum;
      final averageUnitCost = openingRows.fold<double>(
            0,
            (rowSum, item) => rowSum + item.totalPrice,
          ) /
          openingQuantity;
      return sum + (product.quantity * averageUnitCost);
    });
    final inventoryUsd =
        erp.factoryBlocks.fold<double>(0, (sum, item) => sum + item.totalCost) +
        erp.factoryWarehouse.fold<double>(
          0,
          (sum, item) => sum + item.totalInventoryValue,
        ) +
        erp.workshopStock.fold<double>(
          0,
          (sum, item) => sum + item.availableQty * item.netCostPerUnit,
        ) +
        erp.scrapItems
            .where((item) => !item.isSold && item.currency == AppCurrency.usd)
            .fold<double>(0, (sum, item) => sum + item.baseCost) +
        openingTailoredInventoryValue(erp.simpleTailorings, 'تفصيل بسيط') +
        openingTailoredInventoryValue(erp.complexTailorings, 'تفصيل معقد') +
        (entry.openingStockApplied
            ? 0
            : entry.openingStock.isEmpty
            ? entry.inventoryValue
            : entry.totalOpeningStockOf(AppCurrency.usd));
    final inventorySyp = entry.totalOpeningStockOf(AppCurrency.syp);
    final historicalClientsUsd = entry.legacyFinancials
            .where(
              (record) =>
                  record.category == 'clients' &&
                  record.currency == AppCurrency.usd,
            )
            .fold<double>(0, (sum, record) => sum + record.amount);
    final historicalClientsSyp = entry.legacyFinancials
            .where(
              (record) =>
                  record.category == 'clients' &&
                  record.currency == AppCurrency.syp,
            )
            .fold<double>(0, (sum, record) => sum + record.amount);
    final hasHistoricalClients = entry.legacyFinancials.any(
      (record) => record.category == 'clients',
    );
    final clientsUsd = hasHistoricalClients
        ? historicalClientsUsd + erp.clientsTotalDebts
        : (entry.customerDebtsValue > erp.clientsTotalDebts
              ? entry.customerDebtsValue
              : erp.clientsTotalDebts);
    final clientsSyp = historicalClientsSyp + erp.clientsTotalDebtsSyp;
    final assetsUsd =
        fixedUsd +
        erp.mainCashBox +
        erp.scrapCashBox +
        erp.orderCashBox +
        inventoryUsd +
        clientsUsd;
    final assetsSyp =
        fixedSyp +
        erp.mainCashBoxSyp +
        erp.scrapCashBoxSyp +
        erp.orderCashBoxSyp +
        inventorySyp +
        clientsSyp;
    final historicalSuppliersUsd = entry.legacyFinancials
            .where(
              (record) =>
                  record.category == 'suppliers' &&
                  record.currency == AppCurrency.usd,
            )
            .fold<double>(0, (sum, record) => sum + record.amount);
    final historicalSuppliersSyp = entry.legacyFinancials
            .where(
              (record) =>
                  record.category == 'suppliers' &&
                  record.currency == AppCurrency.syp,
            )
            .fold<double>(0, (sum, record) => sum + record.amount);
    final hasHistoricalSuppliers = entry.legacyFinancials.any(
      (record) => record.category == 'suppliers',
    );
    final suppliersUsd = hasHistoricalSuppliers
        ? historicalSuppliersUsd + erp.suppliersTotalDebts
        : (entry.supplierPayablesValue > erp.suppliersTotalDebts
              ? entry.supplierPayablesValue
              : erp.suppliersTotalDebts);
    final suppliersSyp = historicalSuppliersSyp + erp.suppliersTotalDebtsSyp;
    final historicalWagesUsd = entry.legacyFinancials
            .where(
              (record) =>
                  record.category == 'employees' &&
                  record.currency == AppCurrency.usd,
            )
            .fold<double>(0, (sum, record) => sum + record.amount);
    final historicalWagesSyp = entry.legacyFinancials
            .where(
              (record) =>
                  record.category == 'employees' &&
                  record.currency == AppCurrency.syp,
            )
            .fold<double>(0, (sum, record) => sum + record.amount);
    final hasHistoricalWages = entry.legacyFinancials.any(
      (record) => record.category == 'employees',
    );
    final wagesUsd = hasHistoricalWages
        ? historicalWagesUsd + erp.workersTotalDebts
        : (entry.workerSalariesValue > erp.workersTotalDebts
              ? entry.workerSalariesValue
              : erp.workersTotalDebts);
    final wagesSyp = historicalWagesSyp + erp.workersTotalDebtsSyp;
    final liabilitiesUsd = suppliersUsd + wagesUsd;
    final liabilitiesSyp = suppliersSyp + wagesSyp;
    final capitalUsd = erp.partners.fold<double>(
      0,
      (sum, partner) => sum + partner.injectedCapital,
    );
    final capitalSyp = erp.partners.fold<double>(
      0,
      (sum, partner) => sum + partner.injectedCapitalSyp,
    );
    final retainedEarningsUsd = assetsUsd - liabilitiesUsd - capitalUsd;
    final retainedEarningsSyp = assetsSyp - liabilitiesSyp - capitalSyp;
    final debitRows = <(String, double, double)>[
      ('الأصول الثابتة', fixedUsd, fixedSyp),
      ('الصندوق الرئيسي', erp.mainCashBox, erp.mainCashBoxSyp),
      ('صندوق الخردة', erp.scrapCashBox, erp.scrapCashBoxSyp),
      ('صندوق الطلبيات', erp.orderCashBox, erp.orderCashBoxSyp),
      ('المخزون', inventoryUsd, inventorySyp),
      ('ذمم العملاء', clientsUsd, clientsSyp),
    ];
    final creditRows = <(String, double, double)>[
      ('ذمم الموردين', suppliersUsd, suppliersSyp),
      ('الأجور المستحقة', wagesUsd, wagesSyp),
      ('رأس المال', capitalUsd, capitalSyp),
      ('الأرباح والخسائر المتراكمة', retainedEarningsUsd, retainedEarningsSyp),
    ];
    final rowCount = debitRows.length > creditRows.length
        ? debitRows.length
        : creditRows.length;
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'الميزانية العمومية',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'عرض للقراءة فقط يتحدث وفق أرصدة الصناديق والمخزون والذمم وحقوق الملكية.',
          ),
          if (!entry.isLocked) ...[
            const SizedBox(height: 10),
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('القيد الافتتاحي لم يعتمد بعد.'),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('مدين • الحساب')),
                  DataColumn(label: Text('مدين • USD')),
                  DataColumn(label: Text('مدين • SYP')),
                  DataColumn(label: Text('دائن • الحساب')),
                  DataColumn(label: Text('دائن • USD')),
                  DataColumn(label: Text('دائن • SYP')),
                ],
                rows: [
                  for (var index = 0; index < rowCount; index++)
                    DataRow(
                      cells: [
                        DataCell(Text(
                          index < debitRows.length ? debitRows[index].$1 : '',
                        )),
                        DataCell(Text(
                          index < debitRows.length
                              ? debitRows[index].$2.fmt
                              : '',
                        )),
                        DataCell(Text(
                          index < debitRows.length
                              ? debitRows[index].$3.fmt
                              : '',
                        )),
                        DataCell(Text(
                          index < creditRows.length ? creditRows[index].$1 : '',
                        )),
                        DataCell(Text(
                          index < creditRows.length
                              ? creditRows[index].$2.fmt
                              : '',
                        )),
                        DataCell(Text(
                          index < creditRows.length
                              ? creditRows[index].$3.fmt
                              : '',
                        )),
                      ],
                    ),
                ],
              ),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text(
                'إجمالي المدين = إجمالي الدائن',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'USD: ${assetsUsd.fmt} • SYP: ${assetsSyp.fmt}',
              ),
              trailing: const Icon(
                Icons.check_circle_outline,
                color: AppColors.successGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FixedAssetsManagementScreen extends StatefulWidget {
  const FixedAssetsManagementScreen({super.key});

  @override
  State<FixedAssetsManagementScreen> createState() =>
      _FixedAssetsManagementScreenState();
}

class _FixedAssetsManagementScreenState
    extends State<FixedAssetsManagementScreen> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _category = _fixedAssetCategories.first;
  String _currency = AppCurrency.usd;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final erp = context.watch<ERPProvider>();
    final assets = erp.openingEntry.fixedAssets;
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'إدارة الأصول الثابتة',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'إضافة أصل تخصم كلفته من الصندوق الرئيسي. عند بيع أصل يدخل كامل المبلغ إلى الصندوق الرئيسي ويتم حذف الأصل نهائياً، وتنتقل الأرباح (سعر البيع - القيمة المسجلة) أو الخسائر (القيمة المسجلة - سعر البيع) إلى قائمة ملخص الدخل دون التأثير على رأس المال.',
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'نوع الأصل'),
                      items: [
                        for (final category in _fixedAssetCategories)
                          DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _category = value ?? _category),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'اسم الأصل'),
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'الكلفة'),
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration: const InputDecoration(labelText: 'العملة'),
                      items: const [
                        DropdownMenuItem(value: 'USD', child: Text('USD')),
                        DropdownMenuItem(value: 'SYP', child: Text('SYP')),
                      ],
                      onChanged: (value) =>
                          setState(() => _currency = value ?? 'USD'),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'الوصف'),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      final amount = double.tryParse(_amountController.text);
                      if (_nameController.text.trim().isEmpty ||
                          _descriptionController.text.trim().isEmpty ||
                          amount == null ||
                          amount <= 0) {
                        _message('أدخل اسم الأصل ووصفه ومبلغاً صحيحاً.');
                        return;
                      }
                      final added = erp.purchaseFixedAsset(
                        category: _category,
                        name: _nameController.text,
                        amount: amount,
                        currency: _currency,
                        description: _descriptionController.text,
                      );
                      if (!added) {
                        _message('رصيد الصندوق الرئيسي لا يكفي لشراء الأصل.');
                        return;
                      }
                      _nameController.clear();
                      _amountController.clear();
                      _descriptionController.clear();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة وشراء'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final category in _fixedAssetCategories)
            Card(
              child: ExpansionTile(
                initiallyExpanded: true,
                title: Text(
                  category,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'الإجمالي: ${assets.where((a) => a.category == category && !a.isSold && a.currency == AppCurrency.usd).fold<double>(0, (sum, a) => sum + a.amount).fmt} \$ • ${assets.where((a) => a.category == category && !a.isSold && a.currency == AppCurrency.syp).fold<double>(0, (sum, a) => sum + a.amount).fmt} ل.س',
                ),
                children: [
                  for (final asset in assets.where(
                    (a) => a.category == category,
                  ))
                    ListTile(
                      title: Text(asset.name),
                      subtitle: Text(
                        '${asset.description} • القيمة الدفترية: ${asset.amount.fmt} ${AppCurrency.symbol(asset.currency)}${asset.isSold ? ' • مباع بـ ${asset.saleAmount.fmt}' : ''}',
                      ),
                      trailing: asset.isSold
                          ? const Icon(Icons.check_circle_outline)
                          : TextButton.icon(
                              onPressed: () => _sellAsset(erp, asset),
                              icon: const Icon(Icons.sell_outlined),
                              label: const Text('بيع'),
                            ),
                    ),
                ],
              ),
            ),
          if (erp.assetSaleRecords.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: ExpansionTile(
                initiallyExpanded: false,
                leading: const Icon(
                  Icons.history_rounded,
                  color: AppColors.accentPrimary,
                ),
                title: Text(
                  'سجل الأصول المستبعدة والمباعة (${erp.assetSaleRecords.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'بيان بالأصول المحذوفة ومبالغ البيع المحصلة في الصندوق الرئيسي وأرباح/خسائر ملخص الدخل',
                ),
                children: [
                  for (final record in erp.assetSaleRecords.reversed)
                    ListTile(
                      leading: Icon(
                        record.isGain
                            ? Icons.trending_up_rounded
                            : (record.isLoss
                                ? Icons.trending_down_rounded
                                : Icons.check_circle_outline),
                        color: record.isGain
                            ? AppColors.successGreen
                            : (record.isLoss
                                ? AppColors.dangerWaste
                                : Colors.blueGrey),
                      ),
                      title: Text('${record.assetName} • ${record.category}'),
                      subtitle: Text(
                        'القيمة المسجلة: ${record.registeredPrice.fmt} ${AppCurrency.symbol(record.currency)} • سعر البيع: ${record.salePrice.fmt} ${AppCurrency.symbol(record.currency)} • أودع في: الصندوق الرئيسي',
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: record.isGain
                              ? AppColors.chipBgGreen
                              : (record.isLoss
                                  ? AppColors.chipBgRed
                                  : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: record.isGain
                                ? AppColors.successGreen
                                : (record.isLoss
                                    ? AppColors.dangerWaste
                                    : Colors.grey),
                          ),
                        ),
                        child: Text(
                          record.isGain
                              ? '+${record.gain.fmt} ${AppCurrency.symbol(record.currency)} (أرباح)'
                              : (record.isLoss
                                  ? '-${record.loss.fmt} ${AppCurrency.symbol(record.currency)} (خسائر)'
                                  : '0.00 (تعادل)'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: record.isGain
                                ? AppColors.successGreen
                                : (record.isLoss
                                    ? AppColors.dangerWaste
                                    : Colors.black87),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _sellAsset(ERPProvider erp, FixedAssetModel asset) async {
    final priceController = TextEditingController();
    final sym = AppCurrency.symbol(asset.currency);
    final salePrice = await showDialog<double>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final entered = double.tryParse(priceController.text) ?? 0.0;
          final isHigher = entered > asset.amount;
          final isLower = entered > 0 && entered < asset.amount;

          return AlertDialog(
            title: Text('بيع واستبعاد الأصل • ${asset.name}'),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'التصنيف: ${asset.category}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'القيمة المسجلة في النظام: ${asset.amount.fmt} $sym',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.accentPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: priceController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'سعر البيع ($sym)',
                      hintText: 'أدخل سعر البيع...',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 14),
                  if (entered > 0)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isHigher
                            ? AppColors.chipBgGreen
                            : (isLower
                                ? AppColors.chipBgRed
                                : AppColors.chipBgAmber),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isHigher
                              ? AppColors.successGreen
                              : (isLower
                                  ? AppColors.dangerWaste
                                  : Colors.amber.shade700),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isHigher
                                    ? Icons.trending_up_rounded
                                    : (isLower
                                        ? Icons.trending_down_rounded
                                        : Icons.check_circle_outline),
                                size: 18,
                                color: isHigher
                                    ? AppColors.successGreen
                                    : (isLower
                                        ? AppColors.dangerWaste
                                        : Colors.amber.shade900),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isHigher
                                    ? 'البيع بسعر أعلى من القيمة المسجلة (+أرباح):'
                                    : (isLower
                                        ? 'البيع بسعر أقل من القيمة المسجلة (-خسائر):'
                                        : 'البيع بنفس القيمة المسجلة تماماً:'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isHigher
                                      ? AppColors.successGreen
                                      : (isLower
                                          ? AppColors.dangerWaste
                                          : Colors.amber.shade900),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '• يدخل كامل المبلغ (${entered.fmt} $sym) إلى الصندوق الرئيسي.',
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (isHigher)
                            Text(
                              '• عملية الطرح: (${entered.fmt} - ${asset.amount.fmt}) = ${(entered - asset.amount).fmt} $sym تذهب إلى الأرباح في ملخص الدخل.',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.successGreen,
                              ),
                            )
                          else if (isLower)
                            Text(
                              '• عملية الطرح: (${asset.amount.fmt} - ${entered.fmt}) = ${(asset.amount - entered).fmt} $sym تذهب إلى الخسائر في ملخص الدخل.',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.dangerWaste,
                              ),
                            )
                          else
                            Text(
                              '• سعر البيع مساوٍ للقيمة المسجلة (لا توجد أرباح أو خسائر إضافية).',
                              style: const TextStyle(fontSize: 12),
                            ),
                          const Text(
                            '• يتم حذف الأصل الثابت تماماً من المواد.',
                            style: TextStyle(fontSize: 12),
                          ),
                          const Text(
                            '• رصيد رأس المال يبقى كما هو مدخل أساساً في النظام ولا يتأثر.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () {
                  final amount = double.tryParse(priceController.text);
                  if (amount != null && amount > 0) {
                    Navigator.pop(dialogContext, amount);
                  }
                },
                child: const Text('تأكيد البيع والحذف'),
              ),
            ],
          );
        },
      ),
    );
    priceController.dispose();
    if (salePrice == null) return;
    final sold = erp.sellFixedAsset(
      assetId: asset.id,
      saleAmount: salePrice,
      currency: asset.currency,
    );
    if (!sold) {
      _message('تعذر تسجيل البيع. تحقق من حالة الأصل والسعر.');
      return;
    }
    if (salePrice > asset.amount) {
      final gain = salePrice - asset.amount;
      _message(
        'تم بيع الأصل: دخل كامل المبلغ (${salePrice.fmt} $sym) إلى الصندوق الرئيسي • حُذف الأصل • رُحلت أرباح (${gain.fmt} $sym) إلى ملخص الدخل • رأس المال لم يتأثر.',
      );
    } else if (salePrice < asset.amount) {
      final loss = asset.amount - salePrice;
      _message(
        'تم بيع الأصل: دخل كامل المبلغ (${salePrice.fmt} $sym) إلى الصندوق الرئيسي • حُذف الأصل • رُحلت خسائر (${loss.fmt} $sym) إلى ملخص الدخل • رأس المال لم يتأثر.',
      );
    } else {
      _message(
        'تم بيع الأصل: تحول كامل المبلغ (${salePrice.fmt} $sym) إلى الصندوق الرئيسي • حُذف الأصل الثابت • رأس المال لم يتأثر.',
      );
    }
  }

  void _message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));
}

class ExpensesManagementScreen extends StatefulWidget {
  const ExpensesManagementScreen({super.key});

  @override
  State<ExpensesManagementScreen> createState() =>
      _ExpensesManagementScreenState();
}

class _ExpensesManagementScreenState extends State<ExpensesManagementScreen> {
  String _searchQuery = '';

  Future<void> _addType(ERPProvider erp) async {
    final name = TextEditingController();
    final description = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إضافة نوع مصروف'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'اسم النوع'),
            ),
            TextField(
              controller: description,
              decoration: const InputDecoration(labelText: 'الوصف'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isNotEmpty) {
                erp.addExpenseType(
                  ExpenseTypeModel(
                    id: 'expense_type_${DateTime.now().microsecondsSinceEpoch}',
                    name: name.text.trim(),
                    description: description.text.trim(),
                  ),
                );
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    name.dispose();
    description.dispose();
    if (result == true) setState(() {});
  }

  Future<void> _addExpense(ERPProvider erp, ExpenseTypeModel type) async {
    final amountController = TextEditingController();
    final shareController = TextEditingController();
    final descriptionController = TextEditingController();
    final personController = TextEditingController();
    var currency = AppCurrency.usd;
    String? staffId;
    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('مصروف جديد • ${type.name}'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'مبلغ المصروف',
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: currency,
                    decoration: const InputDecoration(labelText: 'العملة'),
                    items: const [
                      DropdownMenuItem(value: 'USD', child: Text('USD')),
                      DropdownMenuItem(value: 'SYP', child: Text('SYP')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => currency = value ?? 'USD'),
                  ),
                  DropdownButtonFormField<String?>(
                    initialValue: staffId,
                    decoration: const InputDecoration(
                      labelText: 'موظف داخلي (اختياري)',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('لا يوجد موظف داخلي'),
                      ),
                      for (final staff in erp.staffList)
                        DropdownMenuItem<String?>(
                          value: staff.id,
                          child: Text(staff.name),
                        ),
                    ],
                    onChanged: (value) => setDialogState(() {
                      staffId = value;
                      if (value != null) {
                        personController.text = erp.staffList
                            .firstWhere((s) => s.id == value)
                            .name;
                      }
                    }),
                  ),
                  TextField(
                    controller: personController,
                    enabled: staffId == null,
                    decoration: const InputDecoration(
                      labelText: 'شخص خارجي / مستفيد (اختياري)',
                    ),
                  ),
                  TextField(
                    controller: shareController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'حصة الشخص'),
                  ),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'الوصف'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('إضافة مصروف'),
            ),
          ],
        ),
      ),
    );
    if (shouldAdd == true) {
      final amount = double.tryParse(amountController.text) ?? 0;
      final share = double.tryParse(shareController.text) ?? 0;
      if (amount <= 0 ||
          share < 0 ||
          share > amount ||
          (share > 0 && personController.text.trim().isEmpty)) {
        _message('تحقق من المبلغ واسم المستفيد وحصته.');
      } else {
        final expense = ExpenseRecordModel(
          id: 'expense_${DateTime.now().microsecondsSinceEpoch}',
          typeId: type.id,
          amount: amount,
          currency: currency,
          personName: personController.text.trim(),
          staffId: staffId,
          personShare: share,
          description: descriptionController.text.trim(),
        );
        erp.addExpenseRecord(expense);
        if (staffId != null && share > 0) {
          erp.staffList
              .firstWhere((staff) => staff.id == staffId)
              .addEarning(currency, share);
          erp.refresh();
        }
      }
    }
    amountController.dispose();
    shareController.dispose();
    descriptionController.dispose();
    personController.dispose();
  }

  void _message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) {
    final erp = context.watch<ERPProvider>();
    final query = _searchQuery.toLowerCase();
    final matchingTypes = erp.expenseTypes.where((type) {
      final typeMatches =
          query.isEmpty ||
          '${type.name} ${type.description}'.toLowerCase().contains(query);
      return typeMatches ||
          erp.expenseRecords.any(
            (expense) =>
                expense.typeId == type.id &&
                '${expense.amount} ${expense.currency} ${expense.personName} ${expense.description}'
                    .toLowerCase()
                    .contains(query),
          );
    }).toList();
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'المصروفات',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              FilledButton.icon(
                onPressed: () => _addType(erp),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('إضافة نوع مصروف'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'أنشئ أنواع المصروفات، ثم أضف المصروفات ومبالغها والمستفيدين. حصة الموظف الداخلي تسجل في مالية القوى العاملة.',
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              labelText: 'بحث في أنواع المصروفات والمصروفات...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _searchQuery = value.trim()),
          ),
          const SizedBox(height: 12),
          if (matchingTypes.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('لا توجد نتائج مطابقة.'),
              ),
            ),
          for (final type in matchingTypes)
            Card(
              child: ExpansionTile(
                initiallyExpanded: true,
                title: Text(
                  type.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(type.description),
                trailing: IconButton(
                  tooltip: 'إضافة مصروف',
                  onPressed: () => _addExpense(erp, type),
                  icon: const Icon(Icons.add_circle_outline),
                ),
                children: [
                  for (final expense in erp.expenseRecords.where((expense) {
                    if (expense.typeId != type.id) return false;
                    if (query.isEmpty ||
                        '${type.name} ${type.description}'
                            .toLowerCase()
                            .contains(query)) {
                      return true;
                    }
                    return '${expense.amount} ${expense.currency} ${expense.personName} ${expense.description}'
                        .toLowerCase()
                        .contains(query);
                  }))
                    ListTile(
                      title: Row(
                        children: [
                          Text(
                            '${expense.amount.fmt} ${AppCurrency.symbol(expense.currency)}',
                          ),
                          if (expense.isInformational) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: const Color(0xFF3B82F6),
                                  width: 0.8,
                                ),
                              ),
                              child: const Text(
                                'قيد إعلامي (مرسمل على المواد)',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1D4ED8),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        '${expense.description} • ${expense.personName.isEmpty ? 'دون مستفيد' : expense.personName}${expense.personShare > 0 ? ' • الحصة ${expense.personShare.fmt}' : ''}${expense.staffId != null ? ' • مسجل في القوى العاملة' : ''}',
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class ReturnsAllowancesScreen extends StatefulWidget {
  final bool factoryOnly;
  final bool workshopOnly;
  final int initialTab;

  const ReturnsAllowancesScreen({
    super.key,
    this.factoryOnly = false,
    this.workshopOnly = false,
    this.initialTab = 0,
  });

  @override
  State<ReturnsAllowancesScreen> createState() =>
      _ReturnsAllowancesScreenState();
}

class _ReturnsAllowancesScreenState extends State<ReturnsAllowancesScreen> {
  static const _factoryTabs = [
    'مرتجعات مشتريات المصنع',
    'مرتجعات مبيعات المصنع',
    'مسموحات مشتريات المصنع',
    'مسموحات مبيعات المصنع',
  ];
  static const _workshopTabs = [
    'مرتجعات مبيعات المعمل',
    'مسموحات مبيعات المعمل',
  ];
  late int _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  List<String> get _tabs {
    if (widget.factoryOnly) return _factoryTabs;
    if (widget.workshopOnly) return _workshopTabs;
    return [..._factoryTabs, ..._workshopTabs];
  }

  String get _kind {
    if (widget.workshopOnly) {
      return _selectedTab == 0 ? 'sales_return' : 'sales_allowance';
    }
    return [
      'purchase_return',
      'sales_return',
      'purchase_allowance',
      'sales_allowance',
      'sales_return',
      'sales_allowance',
    ][_selectedTab];
  }

  String get _module =>
      widget.workshopOnly || (!widget.factoryOnly && _selectedTab >= 4)
      ? 'workshop'
      : 'factory';

  @override
  Widget build(BuildContext context) {
    final erp = context.watch<ERPProvider>();
    final matching = erp.adjustmentInvoices
        .where((invoice) => invoice.module == _module && invoice.kind == _kind)
        .toList();
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 4),
            child: Text(
              'مرتجعات ومسموحات وخصومات الفواتير',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          SizedBox(
            height: 58,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                for (var index = 0; index < _tabs.length; index++)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: ChoiceChip(
                      label: Text(_tabs[index]),
                      selected: index == _selectedTab,
                      onSelected: (_) => setState(() => _selectedTab = index),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
            child: FilledButton.icon(
              onPressed: () => _addInvoice(erp),
              icon: const Icon(Icons.add),
              label: const Text('إضافة فاتورة جديدة'),
            ),
          ),
          Expanded(
            child: matching.isEmpty
                ? const Center(child: Text('لا توجد فواتير في هذا القسم.'))
                : ListView.builder(
                    itemCount: matching.length,
                    itemBuilder: (context, index) {
                      final invoice = matching[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.assignment_return_outlined),
                          title: Text(
                            '${invoice.invoiceNo} • ${invoice.targetInvoiceNo}',
                          ),
                          subtitle: Text(
                            '${invoice.partyName} • ${invoice.description}',
                          ),
                          trailing: Text(
                            '${invoice.amount.fmt} ${AppCurrency.symbol(invoice.currency)}',
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _addInvoice(ERPProvider erp) async {
    final List<_InvoiceOption> candidates;
    if (_module == 'factory') {
      candidates = erp.factoryInvoices
          .where((invoice) {
            final purchase = invoice.invoiceType == 'شراء_مورد';
            return _kind.startsWith('purchase') ? purchase : !purchase;
          })
          .map(
            (invoice) => _InvoiceOption(
              id: invoice.id,
              invoiceNo: invoice.invoiceNo,
              partyName: invoice.partyName,
              currency: invoice.currency,
              totalAmount: invoice.grandTotal,
              items: [
                for (var index = 0; index < invoice.items.length; index++)
                  _AdjustmentItemOption(
                    key: '$index',
                    id: invoice.items[index].itemId,
                    index: index,
                    description: invoice.items[index].description,
                    quantity: invoice.items[index].quantity,
                  ),
              ],
            ),
          )
          .toList();
    } else {
      candidates = erp.workshopInvoices
          .map(
            (invoice) => _InvoiceOption(
              id: invoice.id,
              invoiceNo: invoice.invoiceNo,
              partyName: invoice.clientName,
              currency: invoice.currency,
              totalAmount: invoice.grandTotal,
              items: [
                _AdjustmentItemOption(
                  key: 'workshop',
                  id: invoice.sourceId,
                  index: -1,
                  description: invoice.itemDescription,
                  quantity: 0,
                ),
              ],
            ),
          )
          .toList();
    }
    if (candidates.isEmpty) {
      _message('أضف الفاتورة الأصلية أولاً حتى يمكن ربط الحركة بها.');
      return;
    }
    var target = candidates.first;
    var targetItem = target.items.first;
    var paymentAction = 'تخفيض دين';
    final numberController = TextEditingController(
      text: 'ADJ-${DateTime.now().millisecondsSinceEpoch}',
    );
    final amountController = TextEditingController();
    final quantityController = TextEditingController();
    final descriptionController = TextEditingController();
    final result = await showDialog<AdjustmentInvoiceModel>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_tabs[_selectedTab]),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: target.id,
                    decoration: const InputDecoration(
                      labelText: 'الفاتورة الأصلية',
                    ),
                    items: [
                      for (final invoice in candidates)
                        DropdownMenuItem(
                          value: invoice.id,
                          child: Text(
                            '${invoice.invoiceNo} • ${invoice.partyName}',
                          ),
                        ),
                    ],
                    onChanged: (id) {
                      if (id == null) return;
                      setDialogState(() {
                        target = candidates.firstWhere(
                          (invoice) => invoice.id == id,
                        );
                        targetItem = target.items.first;
                      });
                    },
                  ),
                  if (_kind.endsWith('return'))
                    DropdownButtonFormField<String>(
                      initialValue: targetItem.key,
                      decoration: const InputDecoration(
                        labelText: 'الصنف المرتجع',
                      ),
                      items: [
                        for (final item in target.items)
                          DropdownMenuItem(
                            value: item.key,
                            child: Text(
                              item.quantity > 0
                                  ? '${item.description} • المتاح: ${item.quantity.fmt}'
                                  : item.description,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(
                          () => targetItem = target.items.firstWhere(
                            (item) => item.key == value,
                          ),
                        );
                      },
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'إجمالي الفاتورة: ${target.totalAmount.fmt} ${AppCurrency.symbol(target.currency)} • التعديلات السابقة: ${_adjustmentsFor(erp, target.id).fmt}',
                    ),
                  ),
                  TextField(
                    controller: numberController,
                    decoration: const InputDecoration(
                      labelText: 'رقم فاتورة الحركة',
                    ),
                  ),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText:
                          'المبلغ (${AppCurrency.symbol(target.currency)})',
                    ),
                  ),
                  if (_kind.endsWith('return'))
                    TextField(
                      controller: quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'الكمية المرتجعة',
                      ),
                    ),
                  DropdownButtonFormField<String>(
                    initialValue: paymentAction,
                    decoration: const InputDecoration(
                      labelText: 'طريقة التسوية',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'تخفيض دين',
                        child: Text('تخفيض الدين'),
                      ),
                      DropdownMenuItem(
                        value: 'استرداد نقدي للصندوق الرئيسي',
                        child: Text('تسوية نقدية من/إلى الصندوق الرئيسي'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => paymentAction = value);
                      }
                    },
                  ),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'التفاصيل'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                final quantity = _kind.endsWith('return')
                    ? double.tryParse(quantityController.text)
                    : 0.0;
                if (quantity != null &&
                    targetItem.quantity > 0 &&
                    quantity > targetItem.quantity) {
                  _message('الكمية المرتجعة تتجاوز كمية الصنف في الفاتورة.');
                  return;
                }
                if (amount == null ||
                    amount <= 0 ||
                    quantity == null ||
                    (_kind.endsWith('return') && quantity <= 0) ||
                    numberController.text.trim().isEmpty) {
                  _message('أدخل مبلغاً صحيحاً ورقم فاتورة، وكمية للمرتجع.');
                  return;
                }
                final remaining =
                    (target.totalAmount - _adjustmentsFor(erp, target.id))
                        .clamp(0.0, double.infinity);
                if (amount > remaining) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'المبلغ يتجاوز المتبقي المتاح للفاتورة الأصلية (${remaining.fmt} ${AppCurrency.symbol(target.currency)}).',
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  AdjustmentInvoiceModel(
                    id: 'adjustment_${DateTime.now().microsecondsSinceEpoch}',
                    invoiceNo: numberController.text.trim(),
                    module: _module,
                    kind: _kind,
                    targetInvoiceId: target.id,
                    targetInvoiceNo: target.invoiceNo,
                    itemId: targetItem.id,
                    itemDescription: targetItem.description,
                    itemIndex: targetItem.index,
                    partyName: target.partyName,
                    description: descriptionController.text.trim(),
                    amount: amount,
                    quantity: quantity,
                    paymentAction: paymentAction,
                    currency: target.currency,
                  ),
                );
              },
              child: const Text('حفظ الفاتورة'),
            ),
          ],
        ),
      ),
    );
    numberController.dispose();
    amountController.dispose();
    quantityController.dispose();
    descriptionController.dispose();
    if (result != null && !erp.addAdjustmentInvoice(result)) {
      _message(
        'تعذر حفظ الحركة: تحقق من الرصيد، والكمية المتاحة، وطريقة التسوية.',
      );
    }
  }

  double _adjustmentsFor(ERPProvider erp, String targetId) => erp
      .adjustmentInvoices
      .where(
        (invoice) =>
            invoice.module == _module && invoice.targetInvoiceId == targetId,
      )
      .fold<double>(0, (sum, invoice) => sum + invoice.amount);

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class _InvoiceOption {
  final String id;
  final String invoiceNo;
  final String partyName;
  final String currency;
  final double totalAmount;
  final List<_AdjustmentItemOption> items;

  const _InvoiceOption({
    required this.id,
    required this.invoiceNo,
    required this.partyName,
    required this.currency,
    required this.totalAmount,
    required this.items,
  });
}

class _AdjustmentItemOption {
  final String key;
  final String id;
  final int index;
  final String description;
  final double quantity;

  const _AdjustmentItemOption({
    required this.key,
    required this.id,
    required this.index,
    required this.description,
    required this.quantity,
  });
}

class HistoricalFinancialsScreen extends StatefulWidget {
  const HistoricalFinancialsScreen({super.key});

  @override
  State<HistoricalFinancialsScreen> createState() =>
      _HistoricalFinancialsScreenState();
}

class _HistoricalFinancialsScreenState
    extends State<HistoricalFinancialsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _currencyFilter = 'ALL';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matches(LegacyFinancialRecordModel record) {
    if (_currencyFilter != 'ALL') {
      if (AppCurrency.isSyp(_currencyFilter) && !AppCurrency.isSyp(record.currency)) {
        return false;
      }
      if (AppCurrency.isUsd(_currencyFilter) && !AppCurrency.isUsd(record.currency)) {
        return false;
      }
    }
    if (_searchQuery.trim().isEmpty) return true;
    final text =
        '${record.name} ${record.phone} ${record.description} ${record.amount} ${record.currency} ${record.category}';
    return arabicFuzzyMatch(text, _searchQuery);
  }

  @override
  Widget build(BuildContext context) {
    final erp = context.watch<ERPProvider>();
    final records = erp.openingEntry.legacyFinancials;
    final categories = {
      'suppliers': 'الذمم القديمة للموردين',
      'clients': 'ديون العملاء المعتمدين وزبائن المفرق القديمة',
      'employees': 'الذمم القديمة للموظفين',
    };

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'المالية القديمة • أرصدة القيد الافتتاحي',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        const Text(
          'سجل تاريخي دائم للذمم التي أُدخلت عند إعداد القيد الافتتاحي. تتم التسويات من هذا السجل.',
        ),
        const SizedBox(height: 14),
        SectionSearchAndFilterBar(
          searchController: _searchCtrl,
          searchQuery: _searchQuery,
          onSearchChanged: (value) => setState(() => _searchQuery = value),
          selectedCurrency: _currencyFilter,
          onCurrencyChanged: (curr) => setState(() => _currencyFilter = curr),
          hintText: 'بحث في الأرصدة السابقة بالاسم أو الهاتف أو الوصف أو المبلغ...',
          onClear: () => setState(() => _searchQuery = ''),
        ),
        const SizedBox(height: 16),
        for (final category in categories.entries) ...[
          () {
            final categoryMatches = records
                .where((item) => item.category == category.key && _matches(item))
                .toList();
            return Card(
              key: ValueKey('legacy_${category.key}_${_searchQuery}_$_currencyFilter'),
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: ExpansionTile(
                initiallyExpanded: true,
                title: Row(
                  children: [
                    Text(
                      category.value,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: categoryMatches.isNotEmpty
                            ? const Color(0xFF0F172A).withValues(alpha: 0.08)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${categoryMatches.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: categoryMatches.isNotEmpty
                              ? const Color(0xFF0F172A)
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
                children: [
                  for (final record in categoryMatches)
                    ListTile(
                      title: Text(
                        record.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${record.phone} • ${record.description} • المتبقي ${record.amount.fmt} ${AppCurrency.symbol(record.currency)}',
                      ),
                      trailing: record.amount == 0
                          ? const Chip(
                              label: Text('مسدد', style: TextStyle(color: Colors.green)),
                              backgroundColor: Color(0xFFDCFCE7),
                            )
                          : IconButton(
                              tooltip: category.key == 'clients'
                                  ? 'تحصيل من العميل'
                                  : 'دفع',
                              onPressed: () =>
                                  _settle(context, erp, record, category.key),
                              icon: const Icon(Icons.payments_outlined,
                                  color: Color(0xFF2563EB)),
                            ),
                    ),
                  if (categoryMatches.isEmpty)
                    const ListTile(
                      title: Text(
                        'لا توجد أرصدة مطابقة للبحث أو التصفية الحالية في هذا القسم.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                ],
              ),
            );
          }(),
        ],
      ],
    );
  }

  Future<void> _settle(
    BuildContext context,
    ERPProvider erp,
    LegacyFinancialRecordModel record,
    String category,
  ) async {
    final amountController = TextEditingController(text: record.amount.fmt);
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          category == 'clients'
              ? 'تحصيل من ${record.name}'
              : 'تسديد ${record.name}',
        ),
        content: TextField(
          controller: amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText:
                'المبلغ (حد أقصى ${record.amount.fmt} ${AppCurrency.symbol(record.currency)})',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(amountController.text);
              if (value != null && value > 0 && value <= record.amount) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    amountController.dispose();
    if (amount == null) return;
    final settled = erp.settleLegacyFinancialRecord(record.id, amount, 'main');
    if (!settled && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رصيد الصندوق لا يكفي لإتمام عملية الدفع.'),
        ),
      );
    }
  }
}
