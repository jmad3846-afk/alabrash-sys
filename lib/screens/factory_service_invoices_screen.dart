import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../core/database/erp_provider.dart';
import '../core/models/models.dart';

class FactoryServiceInvoicesScreen extends StatefulWidget {
  const FactoryServiceInvoicesScreen({super.key});

  @override
  State<FactoryServiceInvoicesScreen> createState() =>
      _FactoryServiceInvoicesScreenState();
}

class _FactoryServiceInvoicesScreenState
    extends State<FactoryServiceInvoicesScreen> {
  static const _background = Color(0xFFF8FAFC);
  static const _panel = Colors.white;
  static const _border = Color(0xFFE2E8F0);
  static const _accent = Color(0xFF2563EB);

  final _notesController = TextEditingController();
  final List<_ServiceInvoiceDraftRow> _rows = [_ServiceInvoiceDraftRow()];
  DateTime _invoiceDate = DateTime.now();
  String? _clientId;
  String _currency = AppCurrency.usd;
  bool _saving = false;

  @override
  void dispose() {
    _notesController.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  double get _total =>
      _rows.fold<double>(0, (sum, row) => sum + row.quantity * row.unitPrice);

  InputDecoration _decoration(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(color: Color(0xFF475569)),
    hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: _border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: _border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: _accent, width: 1.5),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final erp = context.watch<ERPProvider>();
    final clients = erp.clients
        .where((client) => client.name.trim().isNotEmpty)
        .toList();
    if (_clientId != null && !clients.any((client) => client.id == _clientId)) {
      _clientId = null;
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  const Icon(Icons.content_cut, color: _accent, size: 30),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'فواتير الخدمات وأجور القص',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'أجور تنفيذ على حجر مملوك للعميل، دون حركة على مخزون المصنع.',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _panelCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        SizedBox(
                          width: 300,
                          child: DropdownButtonFormField<String>(
                            key: ValueKey(_clientId),
                            initialValue: _clientId,
                            dropdownColor: _panel,
                            style: const TextStyle(color: Color(0xFF0F172A)),
                            decoration: _decoration('العميل'),
                            hint: const Text(
                              'اختر اسماً من الأشخاص',
                              style: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                            items: clients
                                .map(
                                  (client) => DropdownMenuItem(
                                    value: client.id,
                                    child: Text(client.name.trim()),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) => setState(() {
                              _clientId = value;
                              final client = clients
                                  .where((item) => item.id == value)
                                  .firstOrNull;
                              if (client != null) {
                                _currency = client.currencyClassification;
                              }
                            }),
                          ),
                        ),
                        SizedBox(
                          width: 205,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0F172A),
                              side: const BorderSide(color: _border),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                            ),
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_month),
                            label: Text(
                              intl.DateFormat(
                                'yyyy/MM/dd',
                              ).format(_invoiceDate),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          child: DropdownButtonFormField<String>(
                            key: ValueKey(_currency),
                            initialValue: _currency,
                            dropdownColor: _panel,
                            style: const TextStyle(color: Color(0xFF0F172A)),
                            decoration: _decoration('العملة'),
                            items: const [
                              DropdownMenuItem(
                                value: AppCurrency.usd,
                                child: Text('دولار أمريكي'),
                              ),
                              DropdownMenuItem(
                                value: AppCurrency.syp,
                                child: Text('ليرة سورية'),
                              ),
                            ],
                            onChanged: (value) => setState(() {
                              if (value != null) _currency = value;
                            }),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: _border),
                          ),
                          child: Text(
                            'رقم الفاتورة  ${erp.nextServiceInvoiceNumber(_invoiceDate)}',
                            style: const TextStyle(
                              color: _accent,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _buildItemsGrid(),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _notesController,
                      minLines: 1,
                      maxLines: 3,
                      style: const TextStyle(color: Color(0xFF0F172A)),
                      decoration: _decoration('ملاحظات الفاتورة'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Spacer(),
                        const Text(
                          'الصافي المستحق',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          '${_total.toStringAsFixed(2)} ${AppCurrency.symbol(_currency)}',
                          style: const TextStyle(
                            color: _accent,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 18),
                        FilledButton.icon(
                          onPressed: _saving ? null : () => _save(erp, clients),
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 17,
                            ),
                          ),
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: const Text(
                            'حفظ الفاتورة',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'الفواتير المحفوظة (${erp.serviceInvoices.length})',
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              if (erp.serviceInvoices.isEmpty)
                _panelCard(
                  child: const Text(
                    'لا توجد فواتير خدمات محفوظة بعد.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                )
              else
                ...erp.serviceInvoices.reversed.map(
                  (invoice) => _panelCard(
                    child: Row(
                      children: [
                        const Icon(Icons.receipt_long, color: _accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${invoice.invoiceNumber} • ${invoice.clientName}',
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${intl.DateFormat('yyyy/MM/dd').format(invoice.invoiceDate)} • ${invoice.items.length} بند خدمة',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${invoice.totalAmount.toStringAsFixed(2)} ${AppCurrency.symbol(invoice.currency)}',
                          style: const TextStyle(
                            color: _accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panelCard({required Widget child}) => Card(
    color: _panel,
    margin: const EdgeInsets.only(bottom: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: _border),
    ),
    child: Padding(padding: const EdgeInsets.all(18), child: child),
  );

  Widget _buildItemsGrid() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'بنود الخدمة',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () =>
                setState(() => _rows.add(_ServiceInvoiceDraftRow())),
            style: OutlinedButton.styleFrom(
              foregroundColor: _accent,
              side: const BorderSide(color: _accent),
            ),
            icon: const Icon(Icons.add),
            label: const Text('إضافة بند'),
          ),
        ],
      ),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: const WidgetStatePropertyAll(Color(0xFFF1F5F9)),
          dataRowMinHeight: 68,
          dataRowMaxHeight: 78,
          columnSpacing: 12,
          columns: const [
            DataColumn(
              label: Text(
                'نوع الخدمة',
                style: TextStyle(color: Color(0xFF0F172A)),
              ),
            ),
            DataColumn(
              label: Text(
                'وصف حجر العميل ومقاساته',
                style: TextStyle(color: Color(0xFF0F172A)),
              ),
            ),
            DataColumn(
              label: Text('الكمية', style: TextStyle(color: Color(0xFF0F172A))),
            ),
            DataColumn(
              label: Text(
                'سعر الوحدة',
                style: TextStyle(color: Color(0xFF0F172A)),
              ),
            ),
            DataColumn(
              label: Text(
                'الإجمالي',
                style: TextStyle(color: Color(0xFF0F172A)),
              ),
            ),
            DataColumn(label: Text('')),
          ],
          rows: [
            for (var index = 0; index < _rows.length; index++)
              _buildItemRow(index),
          ],
        ),
      ),
    ],
  );

  DataRow _buildItemRow(int index) {
    final row = _rows[index];
    return DataRow(
      cells: [
        DataCell(
          SizedBox(
            width: 170,
            child: TextField(
              controller: row.serviceController,
              style: const TextStyle(color: Color(0xFF0F172A)),
              decoration: _decoration(
                'الخدمة',
                hint: 'قص بلوك حر، جلي وتلميع...',
              ),
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 300,
            child: TextField(
              controller: row.descriptionController,
              style: const TextStyle(color: Color(0xFF0F172A)),
              decoration: _decoration(
                'تفاصيل الحجر',
                hint: 'نوع الحجر، الأبعاد، تفاصيل الشغل...',
              ),
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 95,
            child: TextField(
              controller: row.quantityController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(color: Color(0xFF0F172A)),
              decoration: _decoration('الكمية'),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 115,
            child: TextField(
              controller: row.unitPriceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(color: Color(0xFF0F172A)),
              decoration: _decoration('سعر الوحدة'),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 100,
            child: Text(
              (row.quantity * row.unitPrice).toStringAsFixed(2),
              style: const TextStyle(
                color: _accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        DataCell(
          IconButton(
            tooltip: 'حذف البند',
            onPressed: _rows.length == 1
                ? null
                : () => setState(() {
                    _rows.removeAt(index).dispose();
                  }),
            icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _invoiceDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: _accent),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _invoiceDate = picked);
  }

  void _save(ERPProvider erp, List<ClientModel> clients) {
    final client = clients.where((item) => item.id == _clientId).firstOrNull;
    if (client == null) {
      _showMessage('اختر العميل من قائمة الأشخاص.');
      return;
    }
    final items = <ServiceInvoiceItemModel>[];
    for (var index = 0; index < _rows.length; index++) {
      final row = _rows[index];
      final quantity = double.tryParse(row.quantityController.text.trim());
      final unitPrice = double.tryParse(row.unitPriceController.text.trim());
      if (row.serviceController.text.trim().isEmpty ||
          row.descriptionController.text.trim().isEmpty ||
          quantity == null ||
          !quantity.isFinite ||
          quantity <= 0 ||
          unitPrice == null ||
          !unitPrice.isFinite ||
          unitPrice < 0) {
        _showMessage('أكمل نوع الخدمة ووصف الحجر والكمية والسعر لكل بند.');
        return;
      }
      items.add(
        ServiceInvoiceItemModel(
          id: 'service_item_${DateTime.now().microsecondsSinceEpoch}_$index',
          serviceName: row.serviceController.text.trim(),
          customDescription: row.descriptionController.text.trim(),
          quantity: quantity,
          unitPrice: unitPrice,
        ),
      );
    }
    if (_total <= 0) {
      _showMessage('إجمالي الفاتورة يجب أن يكون أكبر من صفر.');
      return;
    }

    setState(() => _saving = true);
    final invoiceId = 'service_${DateTime.now().microsecondsSinceEpoch}';
    final invoice = ServiceInvoiceModel(
      id: invoiceId,
      invoiceNumber: erp.nextServiceInvoiceNumber(_invoiceDate),
      clientId: client.id,
      clientName: client.name.trim(),
      invoiceDate: _invoiceDate,
      currency: _currency,
      items: items,
      notes: _notesController.text.trim(),
    );
    final saved = erp.addFactoryServiceInvoice(invoice);
    setState(() => _saving = false);
    if (!saved) {
      _showMessage('تعذر حفظ الفاتورة. راجع بيانات العميل والبنود.');
      return;
    }
    for (final row in _rows) {
      row.dispose();
    }
    setState(() {
      _rows
        ..clear()
        ..add(_ServiceInvoiceDraftRow());
      _notesController.clear();
    });
    _showMessage('تم حفظ الفاتورة وإضافة أجورها إلى حساب العميل.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ServiceInvoiceDraftRow {
  final serviceController = TextEditingController();
  final descriptionController = TextEditingController();
  final quantityController = TextEditingController(text: '1');
  final unitPriceController = TextEditingController();

  double get quantity => double.tryParse(quantityController.text.trim()) ?? 0;
  double get unitPrice => double.tryParse(unitPriceController.text.trim()) ?? 0;

  void dispose() {
    serviceController.dispose();
    descriptionController.dispose();
    quantityController.dispose();
    unitPriceController.dispose();
  }
}
