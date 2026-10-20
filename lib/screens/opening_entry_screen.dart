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
    Map<String, String> initialValues = const {},
    Map<String, List<DropdownMenuItem<String>>> fieldOptions = const {},
    String initialCurrency = AppCurrency.usd,
  }) async {
    final controllers = {
      for (final field in fields)
        field: TextEditingController(text: initialValues[field] ?? ''),
    };
    var currency = initialCurrency;
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
                      child: fieldOptions.containsKey(field)
                          ? DropdownButtonFormField<String>(
                              initialValue:
                                  initialValues[field]?.isNotEmpty == true
                                  ? initialValues[field]
                                  : null,
                              decoration: InputDecoration(
                                labelText: field,
                                border: const OutlineInputBorder(),
                              ),
                              items: fieldOptions[field],
                              onChanged: (value) =>
                                  controllers[field]!.text = value ?? '',
                            )
                          : TextField(
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

  Future<void> _addFixedAsset(
    ERPProvider erp,
    String category, {
    FixedAssetModel? existing,
  }) async {
    final value = await _showEntryDialog('إضافة أصل ثابت • $category', const [
      'اسم الأصل',
      'المبلغ',
      'الوصف',
    ], initialValues: {
      'اسم الأصل': existing?.name ?? '',
      'المبلغ': existing?.amount.fmt ?? '',
      'الوصف': existing?.description ?? '',
    }, initialCurrency: existing?.currency ?? AppCurrency.usd);
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
    final asset = FixedAssetModel(
        id: existing?.id ??
            'opening_asset_${DateTime.now().microsecondsSinceEpoch}',
        category: category,
        name: value['اسم الأصل']!,
        amount: amount,
        description: value['الوصف'] ?? '',
        currency: value['currency']!,
      );
    if (existing == null) {
      erp.addOpeningFixedAsset(asset);
    } else {
      erp.updateOpeningFixedAsset(asset);
    }
  }

  Future<void> _addStockItem(
    ERPProvider erp,
    String category, {
    OpeningStockItemModel? existing,
  }) async {
    final isBlock = category == 'بلوكات خام المصنع';
    final isMeter = category.contains('أمتار');
    final isSimple = category == 'تفصيل بسيط';
    final isComplex = category == 'تفصيل معقد';
    if (isBlock && erp.blockTypes.isEmpty) {
      _showMessage('أضف نوع بلوك من قسم «الأنواع» في المصنع أولاً.');
      return;
    }
    if (isMeter && erp.meterTypes.isEmpty) {
      _showMessage('أضف نوع متر من واجهة المصنع أولاً.');
      return;
    }
    if (isSimple && erp.simpleTailorings.isEmpty) {
      _showMessage('أنشئ نوع تفصيل بسيط من واجهة المعمل أولاً.');
      return;
    }
    if (isComplex && erp.complexTailorings.isEmpty) {
      _showMessage('أنشئ نوع تفصيل معقد من واجهة المعمل أولاً.');
      return;
    }
    final typeField = isBlock || isMeter || isSimple || isComplex;
    final existingTypeId = existing == null
        ? null
        : isBlock
        ? _firstOrNull(
            erp.blockTypes.where(
              (type) =>
                  type.id == existing.typeId ||
                  (type.typeName == existing.typeName &&
                      (existing.grade.isEmpty || type.grade == existing.grade)),
            ),
          )?.id
        : isMeter
        ? _firstOrNull(
            erp.meterTypes.where(
              (type) =>
                  type.id == existing.typeId ||
                  type.typeName == existing.typeName,
            ),
          )?.id
        : isSimple || isComplex
        ? _firstOrNull(
            (isSimple ? erp.simpleTailorings : erp.complexTailorings).where(
              (item) =>
                  item.id == existing.typeId || item.name == existing.typeName,
            ),
          )?.id
        : null;
    final options = <DropdownMenuItem<String>>[];
    if (isBlock) {
      options.addAll(
        erp.blockTypes.map(
          (type) => DropdownMenuItem(
            value: type.id,
            child: Text('${type.typeName} • ${type.grade}'),
          ),
        ),
      );
    } else if (isMeter) {
      options.addAll(
        erp.meterTypes.map(
          (type) => DropdownMenuItem(
            value: type.id,
            child: Text(
              '${type.typeName} • ${type.grade} • ${type.thicknessCm} سم',
            ),
          ),
        ),
      );
    } else if (isSimple || isComplex) {
      final products = isSimple
          ? erp.simpleTailorings
          : erp.complexTailorings;
      options.addAll(
        products.map(
          (product) => DropdownMenuItem(
            value: product.id,
            child: Text('${product.name} • ${product.unitSymbol}'),
          ),
        ),
      );
    }
    final qtyLabel = isBlock
        ? 'الكمية بالطن'
        : isMeter
        ? 'الكمية بالأمتار'
        : (isSimple || isComplex)
        ? 'الكمية بالمتر المربع أو المكعب'
        : 'الكمية';
    final costPriceLabel = isBlock
        ? 'سعر تكلفة الطن الأولي (Initial Ton Price)'
        : (isMeter || isSimple || isComplex)
        ? 'سعر تكلفة المتر الأولي (Initial Meter Price)'
        : 'سعر التكلفة الأولي (Initial Cost Price)';
    final sellingPriceLabel = (isMeter || isSimple || isComplex)
        ? 'سعر بيع المتر (Selling Price per Meter)'
        : 'سعر البيع (Selling Price)';

    final value = await _showEntryDialog('إضافة مخزون • $category', [
      typeField ? 'النوع' : 'اسم الصنف / النوع',
      qtyLabel,
      costPriceLabel,
      if (!isBlock) sellingPriceLabel,
      if (isBlock) 'اسم المورد',
      'الوصف',
    ], initialValues: {
      if (existing != null)
        'النوع': existingTypeId ?? '',
      if (existing != null && !typeField) 'اسم الصنف / النوع': existing.typeName,
      if (existing != null) qtyLabel: existing.quantity.fmt,
      if (existing != null) costPriceLabel: existing.unitPrice.fmt,
      if (existing != null && !isBlock)
        sellingPriceLabel: existing.sellingPrice > 0 ? existing.sellingPrice.fmt : '',
      if (existing != null) 'اسم المورد': existing.supplierName,
      if (existing != null) 'الوصف': existing.description,
    },
    showCurrency: false,
    fieldOptions: typeField ? {'النوع': options} : const {},
    initialCurrency: AppCurrency.usd,
    );
    if (value == null ||
        value[typeField ? 'النوع' : 'اسم الصنف / النوع']!.isEmpty) {
      if (value != null) _showMessage('اختر نوع المخزون أو أدخل اسمه.');
      return;
    }
    final selectedId = value['النوع'] ?? '';
    final blockType = isBlock
        ? _firstOrNull(erp.blockTypes.where((type) => type.id == selectedId))
        : null;
    final meterType = isMeter
        ? _firstOrNull(erp.meterTypes.where((type) => type.id == selectedId))
        : null;
    final tailoringItems = isSimple
        ? erp.simpleTailorings
        : isComplex
        ? erp.complexTailorings
        : const <WorkshopTailoringModel>[];
    final tailoredItem = (isSimple || isComplex)
        ? _firstOrNull(tailoringItems.where((item) => item.id == selectedId))
        : null;
    final quantity = double.tryParse(value[qtyLabel] ?? '') ?? 0;
    final unitPrice = double.tryParse(value[costPriceLabel] ?? '') ?? 0;
    final sellingPrice = isBlock
        ? 0.0
        : (double.tryParse(value[sellingPriceLabel] ?? '') ?? 0.0);
    if (quantity <= 0 ||
        unitPrice < 0 ||
        sellingPrice < 0 ||
        (isBlock &&
            (unitPrice <= 0 || (value['اسم المورد'] ?? '').isEmpty))) {
      _showMessage(isBlock
          ? 'تحقق من كمية الطن وسعر التكلفة واسم المورد.'
          : 'تحقق من الكمية وسعر التكلفة وسعر البيع.');
      return;
    }
    final item = OpeningStockItemModel(
        id: existing?.id ??
            'opening_stock_${DateTime.now().microsecondsSinceEpoch}',
        category: category,
        typeName: blockType?.typeName ??
            meterType?.typeName ??
            tailoredItem?.name ??
            value['اسم الصنف / النوع']!,
        typeId: blockType?.id ?? meterType?.id ?? tailoredItem?.id ?? '',
        grade: blockType?.grade ?? meterType?.grade ?? '',
        isGranite: blockType?.isGranite ?? meterType?.isGranite ?? false,
        thicknessCm: meterType?.thicknessCm ?? 0,
        supplierName: value['اسم المورد'] ?? '',
        quantity: quantity,
        unitPrice: unitPrice,
        sellingPrice: isBlock ? 0.0 : sellingPrice,
        description: value['الوصف'] ?? '',
        currency: AppCurrency.usd,
      );
    if (existing == null) {
      erp.addOpeningStockItem(item);
    } else {
      erp.updateOpeningStockItem(item);
    }
  }

  String _openingStockUnit(ERPProvider erp, OpeningStockItemModel item) {
    if (item.category == 'بلوكات خام المصنع') return 'طن';
    if (item.category == 'أمتار المصنع' || item.category == 'أمتار المعمل') {
      final type = _firstOrNull(
        erp.meterTypes.where((candidate) => candidate.id == item.typeId),
      );
      return type?.category == 'متر مكعب' ? 'م³' : 'م²';
    }
    if (item.category == 'تفصيل بسيط' || item.category == 'تفصيل معقد') {
      final products = item.category == 'تفصيل بسيط'
          ? erp.simpleTailorings
          : erp.complexTailorings;
      return _firstOrNull(
            products.where((candidate) => candidate.id == item.typeId),
          )?.unitSymbol ??
          'م²/م³';
    }
    return 'وحدة';
  }

  Future<void> _addLegacyRecord(
    ERPProvider erp,
    String category, {
    LegacyFinancialRecordModel? existing,
  }) async {
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
    ], initialValues: {
      'الاسم': existing?.name ?? '',
      'رقم الهاتف': existing?.phone ?? '',
      'المبلغ': existing?.amount.fmt ?? '',
      'الوصف': existing?.description ?? '',
    }, initialCurrency: existing?.currency ?? AppCurrency.usd);
    if (value == null || value['الاسم']!.isEmpty) return;
    final amount = double.tryParse(value['المبلغ']!) ?? 0;
    if (amount <= 0) {
      _showMessage('أدخل مبلغاً أكبر من الصفر.');
      return;
    }
    final record = LegacyFinancialRecordModel(
        id: existing?.id ?? 'legacy_${DateTime.now().microsecondsSinceEpoch}',
        category: category,
        name: value['الاسم']!,
        phone: value['رقم الهاتف'] ?? '',
        currency: value['currency']!,
        amount: amount,
        description: value['الوصف'] ?? '',
      );
    if (existing == null) {
      erp.addOpeningFinancialRecord(record);
    } else {
      erp.updateOpeningFinancialRecord(record);
    }
  }

  Future<bool> _confirmDelete(String label) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('هل تريد حذف $label من القيد الافتتاحي؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      ) ??
      false;

  T? _firstOrNull<T>(Iterable<T> values) {
    final iterator = values.iterator;
    return iterator.moveNext() ? iterator.current : null;
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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${asset.amount.fmt} ${AppCurrency.symbol(asset.currency)}',
                            ),
                            if (!entry.isLocked) ...[
                              IconButton(
                                tooltip: 'تعديل',
                                onPressed: () => _addFixedAsset(
                                  erp,
                                  asset.category,
                                  existing: asset,
                                ),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'حذف',
                                onPressed: () async {
                                  if (await _confirmDelete(asset.name)) {
                                    erp.deleteOpeningFixedAsset(asset.id);
                                  }
                                },
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.dangerWaste,
                                ),
                              ),
                            ],
                          ],
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
                  'الكمية وسعر الوحدة بالدولار USD والقيمة الإجمالية تحفظ ضمن النوع المخصص.',
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
                          'الكمية: ${item.quantity.fmt} ${_openingStockUnit(erp, item)} • سعر التكلفة: ${item.unitPrice.fmt} ${AppCurrency.symbol(item.currency)}${item.sellingPrice > 0 ? ' • سعر البيع: ${item.sellingPrice.fmt} ${AppCurrency.symbol(item.currency)}' : ''}${item.supplierName.isEmpty ? '' : ' • المورد: ${item.supplierName}'} • ${item.description}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${item.totalPrice.fmt} ${AppCurrency.symbol(item.currency)}',
                            ),
                            if (!entry.isLocked) ...[
                              IconButton(
                                tooltip: 'تعديل',
                                onPressed: () => _addStockItem(
                                  erp,
                                  item.category,
                                  existing: item,
                                ),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'حذف',
                                onPressed: () async {
                                  if (await _confirmDelete(item.typeName)) {
                                    erp.deleteOpeningStockItem(item.id);
                                  }
                                },
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.dangerWaste,
                                ),
                              ),
                            ],
                          ],
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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${record.amount.fmt} ${AppCurrency.symbol(record.currency)}',
                            ),
                            if (!entry.isLocked) ...[
                              IconButton(
                                tooltip: 'تعديل',
                                onPressed: () => _addLegacyRecord(
                                  erp,
                                  record.category,
                                  existing: record,
                                ),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'حذف',
                                onPressed: () async {
                                  if (await _confirmDelete(record.name)) {
                                    erp.deleteOpeningFinancialRecord(record.id);
                                  }
                                },
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.dangerWaste,
                                ),
                              ),
                            ],
                          ],
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
                          try {
                            erp.lockOpeningEntry();
                            _showMessage('تم اعتماد القيد الافتتاحي وحفظه.');
                          } on StateError catch (error) {
                            _showMessage(error.message);
                          }
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
