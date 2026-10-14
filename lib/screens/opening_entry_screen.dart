import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';
import '../core/theme/app_theme.dart';

class OpeningEntryScreen extends StatefulWidget {
  const OpeningEntryScreen({super.key});

  @override
  State<OpeningEntryScreen> createState() => _OpeningEntryScreenState();
}

class _OpeningEntryScreenState extends State<OpeningEntryScreen> {
  static const _assetCategories = [
    'أراضي',
    'مباني وعقارات',
    'آلات ومعدات',
    'آليات ونقل',
    'أثاث',
  ];

  static const _stockCategories = [
    'بلوكات خام المصنع',
    'أمتار المصنع',
    'أمتار المعمل',
    'تفصيل بسيط',
    'تفصيل معقد',
    'قطع زائدة وخردة',
  ];

  final Map<String, TextEditingController> _cashControllers = {};
  bool _cashControllersReady = false;

  @override
  void dispose() {
    for (final controller in _cashControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeCashControllers(OpeningEntryModel entry) {
    if (_cashControllersReady) return;
    final initialValues = {
      'mainUsd': entry.mainCashValue,
      'mainSyp': entry.mainCashValueSyp,
      'scrapUsd': entry.scrapCashValue,
      'scrapSyp': entry.scrapCashValueSyp,
      'orderUsd': entry.orderCashValue,
      'orderSyp': entry.orderCashValueSyp,
    };
    for (final value in initialValues.entries) {
      _cashControllers[value.key] = TextEditingController(
        text: value.value.fmt,
      );
    }
    _cashControllersReady = true;
  }

  void _updateCash(ERPProvider erp, String key, String value) {
    if (erp.openingEntry.isLocked) return;
    final amount = double.tryParse(value) ?? 0;
    switch (key) {
      case 'mainUsd':
        erp.openingEntry.mainCashValue = amount;
        break;
      case 'mainSyp':
        erp.openingEntry.mainCashValueSyp = amount;
        break;
      case 'scrapUsd':
        erp.openingEntry.scrapCashValue = amount;
        break;
      case 'scrapSyp':
        erp.openingEntry.scrapCashValueSyp = amount;
        break;
      case 'orderUsd':
        erp.openingEntry.orderCashValue = amount;
        break;
      case 'orderSyp':
        erp.openingEntry.orderCashValueSyp = amount;
        break;
    }
    erp.refresh();
  }

  Future<Map<String, String>?> _showEntryDialog(
    String title,
    List<String> fields, {
    bool showCurrency = true,
  }) async {
    final controllers = {
      for (final field in fields) field: TextEditingController(),
    };
    var currency = AppCurrency.usd;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final field in fields)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: controllers[field],
                        keyboardType:
                            field.contains('المبلغ') ||
                                field.contains('الكمية') ||
                                field.contains('سعر')
                            ? const TextInputType.numberWithOptions(
                                decimal: true,
                              )
                            : TextInputType.text,
                        decoration: InputDecoration(
                          labelText: field,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  if (showCurrency)
                    DropdownButtonFormField<String>(
                      initialValue: currency,
                      decoration: const InputDecoration(
                        labelText: 'العملة',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: AppCurrency.usd,
                          child: Text('دولار أمريكي (USD)'),
                        ),
                        DropdownMenuItem(
                          value: AppCurrency.syp,
                          child: Text('ليرة سورية (SYP)'),
                        ),
                      ],
                      onChanged: (value) => setDialogState(
                        () => currency = value ?? AppCurrency.usd,
                      ),
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
                final values = {
                  for (final field in fields)
                    field: controllers[field]!.text.trim(),
                  'currency': currency,
                };
                Navigator.pop(dialogContext, values);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    for (final controller in controllers.values) {
      controller.dispose();
    }
    return result;
  }

  Future<void> _addFixedAsset(ERPProvider erp, String category) async {
    final value = await _showEntryDialog('إضافة أصل ثابت • $category', const [
      'اسم الأصل',
      'المبلغ',
      'الوصف',
    ]);
    if (value == null ||
        value['اسم الأصل']!.isEmpty ||
        value['الوصف']!.isEmpty) {
      if (value != null) _showMessage('أدخل اسم الأصل ووصفه.');
      return;
    }
    final amount = double.tryParse(value['المبلغ']!) ?? 0;
    if (amount <= 0) {
      _showMessage('أدخل مبلغاً أكبر من الصفر.');
      return;
    }
    erp.addOpeningFixedAsset(
      FixedAssetModel(
        id: 'opening_asset_${DateTime.now().microsecondsSinceEpoch}',
        category: category,
        name: value['اسم الأصل']!,
        amount: amount,
        description: value['الوصف'] ?? '',
        currency: value['currency']!,
      ),
    );
  }

  Future<void> _addStockItem(ERPProvider erp, String category) async {
    final isBlock = category == 'بلوكات خام المصنع';
    final isMeter = category.contains('أمتار');
    final value = await _showEntryDialog('إضافة مخزون • $category', [
      isBlock || isMeter ? 'النوع' : 'اسم الصنف / النوع',
      isBlock
          ? 'الكمية بالطن'
          : isMeter
          ? 'الكمية بالأمتار'
          : 'الكمية',
      isBlock
          ? 'سعر الطن'
          : isMeter
          ? 'سعر المتر'
          : 'سعر الوحدة',
      'الوصف',
    ]);
    if (value == null ||
        value[isBlock || isMeter ? 'النوع' : 'اسم الصنف / النوع']!.isEmpty) {
      return;
    }
    final quantity =
        double.tryParse(
          value[isBlock
              ? 'الكمية بالطن'
              : isMeter
              ? 'الكمية بالأمتار'
              : 'الكمية']!,
        ) ??
        0;
    final unitPrice =
        double.tryParse(
          value[isBlock
              ? 'سعر الطن'
              : isMeter
              ? 'سعر المتر'
              : 'سعر الوحدة']!,
        ) ??
        0;
    if (quantity <= 0 || unitPrice < 0) {
      _showMessage('تحقق من الكمية وسعر الوحدة.');
      return;
    }
    erp.addOpeningStockItem(
      OpeningStockItemModel(
        id: 'opening_stock_${DateTime.now().microsecondsSinceEpoch}',
        category: category,
        typeName: value[isBlock || isMeter ? 'النوع' : 'اسم الصنف / النوع']!,
        quantity: quantity,
        unitPrice: unitPrice,
        description: value['الوصف'] ?? '',
        currency: value['currency']!,
      ),
    );
  }

  Future<void> _addLegacyRecord(ERPProvider erp, String category) async {
    final titles = {
      'clients': 'ذمة عميل / معتمد قديم',
      'suppliers': 'ذمة مورد قديمة',
      'employees': 'مستحقات موظف قديمة',
    };
    final value = await _showEntryDialog(titles[category]!, const [
      'الاسم',
      'رقم الهاتف',
      'المبلغ',
      'الوصف',
    ]);
    if (value == null || value['الاسم']!.isEmpty) return;
    final amount = double.tryParse(value['المبلغ']!) ?? 0;
    if (amount <= 0) {
      _showMessage('أدخل مبلغاً أكبر من الصفر.');
      return;
    }
    erp.addOpeningFinancialRecord(
      LegacyFinancialRecordModel(
        id: 'legacy_${DateTime.now().microsecondsSinceEpoch}',
        category: category,
        name: value['الاسم']!,
        phone: value['رقم الهاتف'] ?? '',
        currency: value['currency']!,
        amount: amount,
        description: value['الوصف'] ?? '',
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final erp = context.watch<ERPProvider>();
    final entry = erp.openingEntry;
    _initializeCashControllers(entry);
    final fixedTotal = entry.fixedAssets.isEmpty
        ? entry.landValue +
              entry.buildingsValue +
              entry.machineryValue +
              entry.vehiclesValue +
              entry.furnitureValue
        : entry.fixedAssets.fold<double>(
            0,
            (sum, asset) =>
                sum +
                (!asset.isSold && asset.currency == AppCurrency.usd
                    ? asset.amount
                    : 0),
          );
    final fixedTotalSyp = entry.fixedAssets
        .where((asset) => !asset.isSold && asset.currency == AppCurrency.syp)
        .fold<double>(0, (sum, asset) => sum + asset.amount);
    final stockTotal = entry.openingStock
        .where((item) => item.currency == AppCurrency.usd)
        .fold<double>(0, (sum, item) => sum + item.totalPrice);
    final stockTotalSyp = entry.openingStock
        .where((item) => item.currency == AppCurrency.syp)
        .fold<double>(0, (sum, item) => sum + item.totalPrice);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'القيد الافتتاحي والميزانية',
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'أدخل الأصول والمخزون والأرصدة التاريخية بالتفصيل قبل اعتماد الميزانية.',
                        style: TextStyle(color: AppColors.brandSecondaryText),
                      ),
                    ],
                  ),
                ),
                Chip(
                  avatar: Icon(
                    entry.isLocked ? Icons.lock : Icons.edit,
                    color: entry.isLocked
                        ? AppColors.successGreen
                        : AppColors.accentPrimary,
                  ),
                  label: Text(entry.isLocked ? 'معتمد ومغلق' : 'قيد الإعداد'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (entry.isLocked)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    'تم اعتماد القيد الافتتاحي. البيانات التاريخية محفوظة للرجوع إليها، وتُجرى الحركات الجديدة من شاشاتها التشغيلية.',
                  ),
                ),
              ),
            _section(
              title: 'الأصول الثابتة',
              subtitle: 'أدخل كل أصل باسمه وقيمته ووصفه ضمن نوعه.',
              trailing: Text(
                'الإجمالي: ${fixedTotal.fmt} \$ • ${fixedTotalSyp.fmt} ل.س',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in _assetCategories)
                        OutlinedButton.icon(
                          onPressed: entry.isLocked
                              ? null
                              : () => _addFixedAsset(erp, category),
                          icon: const Icon(Icons.add),
                          label: Text(category),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (entry.fixedAssets.isEmpty)
                    const Text('لم تتم إضافة أصول تفصيلية بعد.')
                  else
                    ...entry.fixedAssets.map(
                      (asset) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.apartment),
                        title: Text('${asset.name} • ${asset.category}'),
                        subtitle: Text(
                          '${asset.description} ${asset.isSold ? '• مباع' : ''}',
                        ),
                        trailing: Text(
                          '${asset.amount.fmt} ${AppCurrency.symbol(asset.currency)}',
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _section(
              title: 'الأصول المتداولة • الصناديق',
              subtitle: 'رصيد افتتاحي مستقل بالليرة والدولار لكل صندوق.',
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _cashInput(erp, 'الصندوق الرئيسي • USD', 'mainUsd', entry),
                  _cashInput(erp, 'الصندوق الرئيسي • SYP', 'mainSyp', entry),
                  _cashInput(erp, 'صندوق الخردة • USD', 'scrapUsd', entry),
                  _cashInput(erp, 'صندوق الخردة • SYP', 'scrapSyp', entry),
                  _cashInput(erp, 'صندوق الطلبيات • USD', 'orderUsd', entry),
                  _cashInput(erp, 'صندوق الطلبيات • SYP', 'orderSyp', entry),
                ],
              ),
            ),
            _section(
              title: 'البضائع والمخزون الحالي',
              subtitle:
                  'الكمية وسعر الوحدة والقيمة الإجمالية تحفظ ضمن النوع المخصص.',
              trailing: Text(
                'قيمة المخزون التفصيلي: ${stockTotal.fmt} \$ • ${stockTotalSyp.fmt} ل.س',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in _stockCategories)
                        OutlinedButton.icon(
                          onPressed: entry.isLocked
                              ? null
                              : () => _addStockItem(erp, category),
                          icon: const Icon(Icons.add_box_outlined),
                          label: Text(category),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (entry.openingStock.isEmpty)
                    const Text('لم تتم إضافة أصناف مخزون تفصيلية بعد.')
                  else
                    ...entry.openingStock.map(
                      (item) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.inventory_2_outlined),
                        title: Text('${item.typeName} • ${item.category}'),
                        subtitle: Text(
                          'الكمية: ${item.quantity.fmt} • سعر الوحدة: ${item.unitPrice.fmt} ${AppCurrency.symbol(item.currency)} • ${item.description}',
                        ),
                        trailing: Text(
                          '${item.totalPrice.fmt} ${AppCurrency.symbol(item.currency)}',
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _section(
              title: 'الذمم والمستحقات التاريخية',
              subtitle:
                  'تظهر هذه الأرصدة في «المالية القديمة» ويمكن تسوية الموردين والموظفين منها.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final category in const [
                        'clients',
                        'suppliers',
                        'employees',
                      ])
                        OutlinedButton.icon(
                          onPressed: entry.isLocked
                              ? null
                              : () => _addLegacyRecord(erp, category),
                          icon: const Icon(Icons.person_add_alt_1),
                          label: Text(
                            {
                              'clients': 'إضافة دين عميل / معتمد',
                              'suppliers': 'إضافة دين مورد',
                              'employees': 'إضافة مستحق موظف',
                            }[category]!,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (entry.legacyFinancials.isEmpty)
                    const Text('لا توجد أرصدة تاريخية مدخلة.')
                  else
                    ...entry.legacyFinancials.map(
                      (record) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.receipt_long),
                        title: Text(record.name),
                        subtitle: Text(
                          '${record.phone} • ${record.description} • ${record.category}',
                        ),
                        trailing: Text(
                          '${record.amount.fmt} ${AppCurrency.symbol(record.currency)}',
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _section(
              title: 'ملخص القيد الافتتاحي',
              subtitle:
                  'يُحتسب رأس المال المتبقي من الأصول مطروحاً منها الالتزامات.',
              child: Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  _summary('الأصول الثابتة', fixedTotal),
                  _summary('المخزون التفصيلي', stockTotal),
                  _summary('ذمم العملاء', entry.customerDebtsValue),
                  _summary('ذمم الموردين', entry.supplierPayablesValue),
                  _summary('رواتب ومستحقات', entry.workerSalariesValue),
                  _summary('حقوق الملكية التقديرية', entry.totalEquity),
                ],
              ),
            ),
            if (!entry.isLocked)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: entry.isBalanced
                      ? () {
                          erp.lockOpeningEntry();
                          _showMessage('تم اعتماد القيد الافتتاحي وحفظه.');
                        }
                      : null,
                  icon: const Icon(Icons.lock_outline),
                  label: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('اعتماد القيد الافتتاحي'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cashInput(
    ERPProvider erp,
    String label,
    String key,
    OpeningEntryModel entry,
  ) {
    return SizedBox(
      width: 250,
      child: TextField(
        controller: _cashControllers[key],
        enabled: !entry.isLocked,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (value) => _updateCash(erp, key, value),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.brandSecondaryText),
            ),
            const Divider(height: 22),
            child,
          ],
        ),
      ),
    );
  }

  Widget _summary(String label, double amount) => SizedBox(
    width: 230,
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(
        '${amount.fmt} \$',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
  );
}
