import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';
import '../core/theme/app_theme.dart';

/// Master invoice offered inside the return / allowance dialog.
class ReturnTargetInvoice {
  final String id;
  final String invoiceNo;
  final String partyName;
  final String partyId;
  final String currency;
  final double totalAmount;
  final DateTime date;

  const ReturnTargetInvoice({
    required this.id,
    required this.invoiceNo,
    required this.partyName,
    required this.partyId,
    required this.currency,
    required this.totalAmount,
    required this.date,
  });

  String get label =>
      '$invoiceNo • $partyName • ${totalAmount.fmt} ${AppCurrency.symbol(currency)}';
}

/// One master-invoice line rendered as a row of the dialog table.
class _LineRow {
  final int index;
  final String itemId;
  final String description;
  final String unit;
  final double originalQty;
  final double alreadyReturned;
  final double unitPrice;
  final bool readOnly;
  final TextEditingController controller;

  _LineRow({
    required this.index,
    required this.itemId,
    required this.description,
    required this.unit,
    required this.originalQty,
    required this.alreadyReturned,
    required this.unitPrice,
    this.readOnly = false,
  }) : controller = TextEditingController(
         text: readOnly ? AppCurrency.fmt(originalQty, 4) : '',
       );

  double get availableQty {
    final value = originalQty - alreadyReturned;
    return value > 0 ? value : 0;
  }

  double get qty {
    if (readOnly) return originalQty;
    final parsed = double.tryParse(controller.text.trim().replaceAll(',', '.'));
    if (parsed == null || !parsed.isFinite || parsed < 0) return 0;
    return parsed;
  }

  bool get exceedsAvailable => !readOnly && qty > availableQty + 0.0000001;

  double get amount => AppCurrency.money(qty * unitPrice);

  void dispose() => controller.dispose();
}

/// Shared "Invoice Return (مرتجع) / Allowance (مسموح)" document dialog.
///
/// * Returns load **every** line of the selected master invoice, accept a
///   returned quantity per line (unit aware) and calculate each line amount
///   automatically as `quantity × original unit price`.
/// * Allowances render the same lines read-only and only accept a single
///   allowance amount — inventory is never touched.
class ReturnAllowanceDialog extends StatefulWidget {
  final ERPProvider erp;
  final String module; // 'factory' | 'workshop'
  final String kind; // purchase_return | sales_return | purchase_allowance | sales_allowance
  final String title;

  const ReturnAllowanceDialog({
    super.key,
    required this.erp,
    required this.module,
    required this.kind,
    required this.title,
  });

  static Future<AdjustmentInvoiceModel?> show(
    BuildContext context, {
    required ERPProvider erp,
    required String module,
    required String kind,
    required String title,
  }) => showDialog<AdjustmentInvoiceModel>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ReturnAllowanceDialog(
      erp: erp,
      module: module,
      kind: kind,
      title: title,
    ),
  );

  @override
  State<ReturnAllowanceDialog> createState() => _ReturnAllowanceDialogState();
}

class _ReturnAllowanceDialogState extends State<ReturnAllowanceDialog> {
  static const String _cashAction = 'استرداد نقدي للصندوق الرئيسي';
  static const String _debtAction = 'تخفيض دين';

  late final TextEditingController _docNoController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  late String _paymentAction;

  ReturnTargetInvoice? _target;
  List<_LineRow> _rows = const [];
  String? _error;

  bool get _isReturn => widget.kind.endsWith('return');
  bool get _isPurchase => widget.kind.startsWith('purchase');
  bool get _isFactory => widget.module == 'factory';

  @override
  void initState() {
    super.initState();
    _paymentAction = _debtAction;
    _docNoController = TextEditingController(
      text: 'ADJ-${DateTime.now().microsecondsSinceEpoch}',
    );
    _amountController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _docNoController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Candidates & rows
  // ------------------------------------------------------------------
  List<ReturnTargetInvoice> get _candidates {
    if (_isFactory) {
      return widget.erp.factoryInvoices
          .where((invoice) {
            final purchase = invoice.invoiceType == 'شراء_مورد';
            return _isPurchase ? purchase : !purchase;
          })
          .map(
            (invoice) => ReturnTargetInvoice(
              id: invoice.id,
              invoiceNo: invoice.invoiceNo,
              partyName: invoice.partyName,
              partyId: invoice.partyId,
              currency: invoice.currency,
              totalAmount: invoice.grandTotal,
              date: invoice.date,
            ),
          )
          .toList();
    }
    return widget.erp.workshopInvoices
        .map(
          (invoice) => ReturnTargetInvoice(
            id: invoice.id,
            invoiceNo: invoice.invoiceNo,
            partyName: invoice.clientName,
            partyId: '',
            currency: invoice.currency,
            totalAmount: invoice.grandTotal,
            date: invoice.date,
          ),
        )
        .toList();
  }

  ReturnTargetInvoice? _invoiceById(String id) {
    for (final candidate in _candidates) {
      if (candidate.id == id) return candidate;
    }
    return null;
  }

  void _selectTarget(ReturnTargetInvoice? target) {
    for (final row in _rows) {
      row.dispose();
    }
    setState(() {
      _target = target;
      _rows = target == null ? const [] : _buildRows(target);
      _error = null;
    });
  }

  List<_LineRow> _buildRows(ReturnTargetInvoice target) {
    final rows = <_LineRow>[];
    if (_isFactory) {
      final invoice = widget.erp.factoryInvoices.firstWhere(
        (item) => item.id == target.id,
      );
      for (var index = 0; index < invoice.items.length; index++) {
        final item = invoice.items[index];
        final unitQty = item.quantity > 0
            ? item.calculatedArea / item.quantity
            : 1.0;
        final unitPrice = AppCurrency.money(item.unitPrice * unitQty);
        final alreadyReturned = widget.erp.returnedQuantityOf(
          module: widget.module,
          targetInvoiceId: target.id,
          lineIndex: index,
          itemId: item.itemId,
          description: item.description,
        );
        rows.add(
          _LineRow(
            index: index,
            itemId: item.itemId,
            description: item.description,
            unit: item.isMeterItem
                ? (item.meterUnit.isNotEmpty ? item.meterUnit : 'متر مربع')
                : (item.itemCategory == 'tailoring' ||
                          item.itemId.startsWith('tailoring_')
                      ? 'قطعة'
                      : 'طن'),
            originalQty: item.quantity,
            alreadyReturned: alreadyReturned,
            unitPrice: unitPrice,
            readOnly: !_isReturn,
          ),
        );
      }
      return rows;
    }

    final invoice = widget.erp.workshopInvoices.firstWhere(
      (item) => item.id == target.id,
    );
    final lines = widget.erp.workshopInvoiceLines(invoice);
    for (var index = 0; index < lines.length; index++) {
      final item = lines[index];
      final unitPrice = AppCurrency.money(
        item.quantity > 0 ? item.agreedPrice / item.quantity : item.agreedPrice,
      );
      final alreadyReturned = widget.erp.returnedQuantityOf(
        module: widget.module,
        targetInvoiceId: target.id,
        lineIndex: index,
        itemId: item.sourceId,
        description: item.description,
      );
      rows.add(
        _LineRow(
          index: index,
          itemId: item.sourceId,
          description: item.description,
          unit: item.unitCategory,
          originalQty: item.quantity,
          alreadyReturned: alreadyReturned,
          unitPrice: unitPrice,
          readOnly: !_isReturn,
        ),
      );
    }
    return rows;
  }

  // ------------------------------------------------------------------
  // Amounts
  // ------------------------------------------------------------------
  double get _totalAmount {
    if (_isReturn) {
      var total = 0.0;
      for (final row in _rows) {
        total = AppCurrency.money(total + row.amount);
      }
      return total;
    }
    return AppCurrency.money(
      double.tryParse(_amountController.text.trim().replaceAll(',', '.')) ?? 0,
    );
  }

  double get _totalQuantity {
    var total = 0.0;
    for (final row in _rows) {
      total = AppCurrency.money(total + row.qty);
    }
    return total;
  }

  double get _adjustmentCapacity {
    if (_target == null) return 0;
    double grandTotal = 0;
    if (_isFactory) {
      for (final invoice in widget.erp.factoryInvoices) {
        if (invoice.id == _target!.id) {
          grandTotal = invoice.grandTotal;
          break;
        }
      }
    } else {
      for (final invoice in widget.erp.workshopInvoices) {
        if (invoice.id == _target!.id) {
          grandTotal = invoice.grandTotal;
          break;
        }
      }
    }
    final alreadyAdjusted = widget.erp.adjustmentInvoices
        .where(
          (doc) =>
              doc.module == widget.module &&
              doc.targetInvoiceId == _target!.id,
        )
        .fold<double>(0, (sum, doc) => sum + doc.amount);
    return AppCurrency.money(grandTotal - alreadyAdjusted);
  }

  double get _partyBalance {
    if (_target == null) return 0;
    return widget.erp.partyAdjustmentBalanceOf(
      supplier: _isPurchase,
      partyName: _target!.partyName,
      partyId: _target!.partyId,
      currency: _target!.currency,
    );
  }

  /// How the chosen settlement will actually be applied.
  ({double cash, double account}) get _settlementSplit {
    final total = _totalAmount;
    if (_paymentAction == _debtAction) {
      return (cash: 0.0, account: total);
    }
    final balance = _partyBalance;
    final account = total < balance ? total : balance;
    return (
      cash: AppCurrency.money(total - account),
      account: AppCurrency.money(account),
    );
  }

  // ------------------------------------------------------------------
  // Validation
  // ------------------------------------------------------------------
  String? _validate() {
    if (_target == null) return 'اختر الفاتورة الأصلية أولاً.';
    if (_docNoController.text.trim().isEmpty) {
      return 'أدخل رقماً لفاتورة الحركة.';
    }
    final total = _totalAmount;
    if (total <= 0) {
      return _isReturn
          ? 'أدخل كمية مرتجعة واحدة على الأقل.'
          : 'أدخل مبلغ السمح (مبلغاً أكبر من صفر).';
    }
    final capacity = _adjustmentCapacity;
    if (total > capacity + 0.0000001) {
      return 'المبلغ ${total.fmt} ${AppCurrency.symbol(_target!.currency)} '
          'يتجاوز المتبقي المتاح للفاتورة الأصلية (${capacity.fmt} '
          '${AppCurrency.symbol(_target!.currency)}).';
    }
    if (_isReturn) {
      for (final row in _rows) {
        if (row.exceedsAvailable) {
          return 'الكمية المرتجعة للصنف "${row.description}" تتجاوز الكمية '
              'المتاحة (${row.availableQty.fmt} ${row.unit}).';
        }
      }
    }
    final split = _settlementSplit;
    if (_paymentAction == _debtAction && split.account > _partyBalance + 0.0000001) {
      return 'رصيد الذمة الحالي ${_partyBalance.fmt} '
          '${AppCurrency.symbol(_target!.currency)} لا يغطي المبلغ الكامل — '
          'اختر التسوية النقدية من الصندوق.';
    }
    if (split.cash > 0 &&
        !_isPurchase &&
        widget.erp.cashOf('main', _target!.currency) + 0.0001 < split.cash) {
      return 'رصيد الصندوق الرئيسي غير كافٍ لصرف ${split.cash.fmt} '
          '${AppCurrency.symbol(_target!.currency)}.';
    }
    return null;
  }

  void _save() {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final target = _target!;
    Navigator.of(context).pop(
      AdjustmentInvoiceModel(
        id: 'adjustment_${DateTime.now().microsecondsSinceEpoch}',
        invoiceNo: _docNoController.text.trim(),
        module: widget.module,
        kind: widget.kind,
        targetInvoiceId: target.id,
        targetInvoiceNo: target.invoiceNo,
        itemId: _rows.isNotEmpty ? _rows.first.itemId : '',
        itemDescription: _rows
            .map((row) => row.description)
            .where((text) => text.trim().isNotEmpty)
            .join(' + '),
        itemIndex: _rows.isNotEmpty ? _rows.first.index : -1,
        partyName: target.partyName,
        description: _notesController.text.trim(),
        amount: _totalAmount,
        quantity: _isReturn ? _totalQuantity : 0,
        paymentAction: _paymentAction,
        currency: target.currency,
        lines: [
          for (final row in _rows)
            if (!_isReturn || row.qty > 0)
              AdjustmentLineModel(
                itemId: row.itemId,
                itemIndex: row.index,
                description: row.description,
                unit: row.unit,
                quantity: row.qty,
                unitPrice: row.unitPrice,
                amount: row.amount,
              ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // UI
  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 900;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Container(
        width: _isReturn ? 980 : 780,
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width - 32,
          maxHeight: MediaQuery.sizeOf(context).height - 48,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  _isReturn
                      ? Icons.assignment_return_rounded
                      : Icons.discount_rounded,
                  color: _isReturn ? AppColors.dangerWaste : AppColors.partnersEquityAccent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'إغلاق',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Divider(height: 22),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildInvoicePicker(),
                    const SizedBox(height: 14),
                    _buildInvoiceSummary(),
                    const SizedBox(height: 14),
                    if (_target != null) ...[
                      _isReturn ? _buildReturnTable(isNarrow) : _buildAllowanceTable(isNarrow),
                      const SizedBox(height: 14),
                    ],
                    _buildTotalsCard(),
                    const SizedBox(height: 14),
                    _buildSettlementFields(),
                    const SizedBox(height: 14),
                    _buildDocumentFields(),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.chipBgRed,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.dangerWaste,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إلغاء'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _isReturn
                        ? AppColors.dangerWaste
                        : AppColors.partnersEquityAccent,
                  ),
                  onPressed: _save,
                  icon: Icon(
                    _isReturn
                        ? Icons.assignment_return_rounded
                        : Icons.discount_rounded,
                    size: 18,
                  ),
                  label: Text(_isReturn ? 'حفظ فاتورة المرتجع' : 'حفظ فاتورة السمح'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoicePicker() {
    final candidates = _candidates;
    if (candidates.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.chipBgAmber,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'لا توجد فواتير أصلية في هذا القسم — أنشئ الفاتورة أولاً حتى يمكن ربط الحركة بها.',
          style: TextStyle(
            color: Color(0xFF92400E),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: _target?.id,
      decoration: const InputDecoration(
        labelText: 'الفاتورة الأصلية (Master Invoice)',
        helperText: 'سيتم تحميل جميع بنود الفاتورة تلقائياً',
      ),
      items: [
        for (final invoice in candidates)
          DropdownMenuItem(value: invoice.id, child: Text(invoice.label)),
      ],
      onChanged: (id) {
        if (id == null) return;
        _selectTarget(_invoiceById(id));
      },
    );
  }

  Widget _buildInvoiceSummary() {
    final target = _target;
    if (target == null) return const SizedBox.shrink();
    final capacity = _adjustmentCapacity;
    final dateLabel = intl.DateFormat('yyyy/MM/dd').format(target.date);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.chipBgBlue,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.panelBorder),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 6,
        children: [
          _summaryItem('رقم الفاتورة', target.invoiceNo),
          _summaryItem('الطرف', target.partyName),
          _summaryItem('التاريخ', dateLabel),
          _summaryItem(
            'إجمالي الفاتورة',
            '${target.totalAmount.fmt} ${AppCurrency.symbol(target.currency)}',
          ),
          _summaryItem(
            'المتاح للتعديل',
            '${capacity.fmt} ${AppCurrency.symbol(target.currency)}',
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.brandSecondaryText),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  static const _headerStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.bold,
    color: AppColors.brandPrimaryText,
  );
  static const _cellStyle = TextStyle(fontSize: 11);

  List<DataColumn> get _returnColumns => const [
    DataColumn(label: Text('#', style: _headerStyle)),
    DataColumn(label: Text('الصنف', style: _headerStyle)),
    DataColumn(label: Text('الوحدة', style: _headerStyle)),
    DataColumn(label: Text('الكمية', style: _headerStyle)),
    DataColumn(label: Text('مرتجع', style: _headerStyle)),
    DataColumn(label: Text('المتاح', style: _headerStyle)),
    DataColumn(label: Text('سعر الوحدة', style: _headerStyle)),
    DataColumn(label: Text('الكمية المرتجعة', style: _headerStyle)),
    DataColumn(label: Text('المبلغ', style: _headerStyle)),
    DataColumn(label: Text('', style: _headerStyle)),
  ];

  List<DataColumn> get _allowanceColumns => const [
    DataColumn(label: Text('#', style: _headerStyle)),
    DataColumn(label: Text('الصنف', style: _headerStyle)),
    DataColumn(label: Text('الوحدة', style: _headerStyle)),
    DataColumn(label: Text('الكمية', style: _headerStyle)),
    DataColumn(label: Text('مرتجع سابقاً', style: _headerStyle)),
    DataColumn(label: Text('سعر الوحدة', style: _headerStyle)),
    DataColumn(label: Text('قيمة البند', style: _headerStyle)),
  ];

  Widget _buildReturnTable(bool isNarrow) {
    if (_rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'لا توجد بنود في الفاتورة المختارة.',
          style: TextStyle(color: AppColors.brandSecondaryText),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'بنود الفاتورة — أدخل الكمية المرتجعة لكل بند (المبلغ يُحسب تلقائياً)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  for (final row in _rows) {
                    if (row.availableQty > 0) {
                      row.controller.text = AppCurrency.fmt(row.availableQty, 4);
                    }
                  }
                });
              },
              icon: const Icon(Icons.select_all_rounded, size: 16),
              label: const Text('إرجاع كل البنود', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.panelBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 34,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 48,
              columnSpacing: 10,
              horizontalMargin: 10,
              columns: _returnColumns,
              rows: [
                for (final row in _rows)
                  DataRow(
                    cells: [
                      DataCell(Text('${row.index + 1}', style: _cellStyle)),
                      DataCell(
                        SizedBox(
                          width: 200,
                          child: Text(
                            row.description,
                            style: _cellStyle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(row.unit, style: _cellStyle)),
                      DataCell(Text(AppCurrency.fmt(row.originalQty, 4), style: _cellStyle)),
                      DataCell(Text(AppCurrency.fmt(row.alreadyReturned, 4), style: _cellStyle)),
                      DataCell(
                        Text(
                          AppCurrency.fmt(row.availableQty, 4),
                          style: _cellStyle.copyWith(
                            fontWeight: FontWeight.bold,
                            color: row.availableQty > 0
                                ? AppColors.successGreen
                                : AppColors.brandSecondaryText,
                          ),
                        ),
                      ),
                      DataCell(Text(row.unitPrice.fmt, style: _cellStyle)),
                      DataCell(
                        SizedBox(
                          width: 108,
                          child: TextField(
                            controller: row.controller,
                            enabled: row.availableQty > 0,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: const TextStyle(fontSize: 11),
                            textAlign: TextAlign.center,
                            onChanged: (_) => setState(() => _error = null),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              errorText: row.exceedsAvailable ? '!' : null,
                              errorStyle: const TextStyle(fontSize: 10),
                              hintText: '0',
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          row.amount.fmt,
                          style: _cellStyle.copyWith(
                            fontWeight: FontWeight.bold,
                            color: row.amount > 0
                                ? AppColors.dangerWaste
                                : AppColors.brandSecondaryText,
                          ),
                        ),
                      ),
                      DataCell(
                        IconButton(
                          tooltip: 'إرجاع الكمية المتاحة بالكامل',
                          visualDensity: VisualDensity.compact,
                          iconSize: 16,
                          onPressed: row.availableQty > 0
                              ? () {
                                  setState(() {
                                    row.controller.text = AppCurrency.fmt(
                                      row.availableQty,
                                      4,
                                    );
                                    _error = null;
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.undo_rounded),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAllowanceTable(bool isNarrow) {
    if (_rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'لا توجد بنود في الفاتورة المختارة.',
          style: TextStyle(color: AppColors.brandSecondaryText),
        ),
      );
    }
    final target = _target!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'بنود الفاتورة (للاطلاع فقط) — لا توجد حركة مخزون مع السمح',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.panelBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 34,
              dataRowMinHeight: 36,
              dataRowMaxHeight: 44,
              columnSpacing: 12,
              horizontalMargin: 10,
              columns: _allowanceColumns,
              rows: [
                for (final row in _rows)
                  DataRow(
                    cells: [
                      DataCell(Text('${row.index + 1}', style: _cellStyle)),
                      DataCell(
                        SizedBox(
                          width: 240,
                          child: Text(
                            row.description,
                            style: _cellStyle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(row.unit, style: _cellStyle)),
                      DataCell(Text(AppCurrency.fmt(row.originalQty, 4), style: _cellStyle)),
                      DataCell(Text(AppCurrency.fmt(row.alreadyReturned, 4), style: _cellStyle)),
                      DataCell(Text(row.unitPrice.fmt, style: _cellStyle)),
                      DataCell(
                        Text(
                          AppCurrency.money(row.originalQty * row.unitPrice).fmt,
                          style: _cellStyle.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() => _error = null),
          decoration: InputDecoration(
            labelText: 'مبلغ السمح (${AppCurrency.symbol(target.currency)})',
            helperText: 'يُخصم مباشرة من ذمة الطرف دون أي حركة مخزون',
          ),
        ),
      ],
    );
  }

  Widget _buildTotalsCard() {
    final target = _target;
    final total = _totalAmount;
    final currency = target?.currency ?? AppCurrency.usd;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isReturn ? AppColors.chipBgRed : AppColors.chipBgAmber,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.panelBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isReturn ? 'إجمالي قيمة المرتجع' : 'إجمالي مبلغ السمح',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.brandSecondaryText,
                  ),
                ),
                Text(
                  '${total.fmt} ${AppCurrency.symbol(currency)}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _isReturn ? AppColors.dangerWaste : AppColors.partnersEquityAccent,
                  ),
                ),
              ],
            ),
          ),
          if (_isReturn)
            Text(
              'إجمالي الكمية المرتجعة: ${_totalQuantity.fmt}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.brandSecondaryText,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSettlementFields() {
    final target = _target;
    final currency = target?.currency ?? AppCurrency.usd;
    final cashLabel = _isPurchase
        ? 'من الصندوق — استرداد نقدي من الطرف'
        : 'إلى الصندوق — صرف نقدي للطرف';
    final split = _settlementSplit;
    final showSplit = target != null && _paymentAction == _cashAction && _totalAmount > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _paymentAction,
          decoration: const InputDecoration(labelText: 'طريقة التسوية المالية'),
          items: [
            DropdownMenuItem(
              value: _debtAction,
              child: Text('تسوية حساب (تخفيض الذمة المالية)'),
            ),
            DropdownMenuItem(value: _cashAction, child: Text(cashLabel)),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _paymentAction = value;
              _error = null;
            });
          },
        ),
        if (showSplit)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 16,
              children: [
                Text(
                  'نقداً من/إلى الصندوق: ${split.cash.fmt} ${AppCurrency.symbol(currency)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentPrimary,
                  ),
                ),
                Text(
                  'تسوية على حساب الطرف: ${split.account.fmt} ${AppCurrency.symbol(currency)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.scrapBoxAccent,
                  ),
                ),
                Text(
                  'ذمة الطرف الحالية: ${_partyBalance.fmt} ${AppCurrency.symbol(currency)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.brandSecondaryText,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDocumentFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _docNoController,
          decoration: const InputDecoration(labelText: 'رقم فاتورة الحركة'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'التفاصيل / الملاحظات'),
        ),
      ],
    );
  }
}
