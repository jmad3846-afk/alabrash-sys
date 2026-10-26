import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../core/database/erp_provider.dart';
import '../core/models/models.dart';
import '../core/theme/app_theme.dart';
import 'a4_statement_invoice_selection_dialog.dart';

/// Type of the entity for which the statement of account is generated.
enum AccountStatementType { supplier, accreditedAgent, customer, project }

/// One item line belonging to an invoice shown under it in the statement.
class A4StatementDetailLine {
  final String description;
  final String item;
  final String specifications;
  final String type;
  final String length;
  final String width;
  final String quantityText;
  final double? unitPrice;
  final String servicesText;
  final double total;

  const A4StatementDetailLine({
    required this.description,
    required this.item,
    required this.specifications,
    required this.type,
    required this.length,
    required this.width,
    required this.quantityText,
    required this.unitPrice,
    required this.servicesText,
    required this.total,
  });
}

String _statementServicesText(
  List<ServiceAttachment> services,
  String currency,
) {
  if (services.isEmpty) return '—';
  return services
      .map((service) {
        final notes = service.notes.trim();
        final noteText = notes.isEmpty ? '' : ' ($notes)';
        return '${service.serviceName}: ${service.price.fmt} ${AppCurrency.symbol(currency)}$noteText';
      })
      .join('\n');
}

List<A4StatementDetailLine> _factoryInvoiceDetails(
  FactoryInvoiceModel inv, {
  required bool isSale,
}) {
  if (inv.items.isEmpty) {
    return [
      A4StatementDetailLine(
        description: 'تفاصيل المواد غير متاحة',
        item: '—',
        specifications: '—',
        type: inv.invoiceType,
        length: '—',
        width: '—',
        quantityText: '—',
        unitPrice: null,
        servicesText: _statementServicesText(inv.services, inv.currency),
        total: inv.grandTotal,
      ),
    ];
  }
  return inv.items.asMap().entries.map((entry) {
    final index = entry.key;
    final it = entry.value;
    final itemName = it.typeName.isNotEmpty ? it.typeName : it.description;
    final materialType = it.isMeterItem
        ? (it.meterUnit.isNotEmpty ? it.meterUnit : 'متر')
        : (it.isTailoringItem ? 'تفصيل' : 'بلوك');
    final specs = <String>[
      if (it.grade.isNotEmpty) it.grade,
      it.isGranite ? 'جرانيت' : 'رخام',
      if (it.thicknessCm > 0) 'السماكة ${it.thicknessCm.fmt} سم',
      if (it.heightCm > 0) 'الارتفاع ${it.heightCm.fmt} سم',
    ].join(' • ');
    final quantityText = it.isMeterItem
        ? '${it.quantity.fmt} ${it.meterUnit.isNotEmpty ? it.meterUnit : "متر"}'
        : isSale
        ? '${it.calculatedArea.fmt} ${it.isCubicMeter || it.heightCm > 5 ? "م³" : "م²"} (${it.quantity.fmt} قطعة)'
        : '${it.quantity.fmt} طن';
    return A4StatementDetailLine(
      description: it.description.isNotEmpty ? it.description : itemName,
      item: itemName,
      specifications: specs.isEmpty ? '—' : specs,
      type: materialType,
      length: it.lengthCm > 0 ? '${it.lengthCm.fmt} سم' : '—',
      width: it.widthCm > 0 ? '${it.widthCm.fmt} سم' : '—',
      quantityText: quantityText,
      unitPrice: it.unitPrice,
      servicesText: _statementServicesText([
        ...it.services,
        if (index == 0) ...inv.services,
      ], inv.currency),
      total: it.grandTotal,
    );
  }).toList();
}

List<A4StatementDetailLine> _workshopInvoiceDetails(WorkshopInvoiceModel inv) {
  if (inv.items.isEmpty) {
    return [
      A4StatementDetailLine(
        description: inv.itemDescription.isEmpty
            ? 'تفاصيل الصنف غير متاحة'
            : inv.itemDescription,
        item: inv.itemDescription.isEmpty ? 'صنف ورشة' : inv.itemDescription,
        specifications: inv.isGranite ? 'جرانيت' : 'رخام',
        type: inv.sourceType,
        length: '—',
        width: '—',
        quantityText: '${inv.sourceQuantity.fmt} ${inv.sourceUnitCategory}',
        unitPrice: inv.sourceQuantity > 0
            ? inv.agreedPrice / inv.sourceQuantity
            : inv.agreedPrice,
        servicesText: _statementServicesText(inv.services, inv.currency),
        total: inv.grandTotal,
      ),
    ];
  }
  return inv.items.map((it) {
    final specs = <String>[
      it.isGranite ? 'جرانيت' : 'رخام',
      if (it.heightCm > 0) 'السماكة ${it.heightCm.fmt} سم',
    ].join(' • ');
    return A4StatementDetailLine(
      description: inv.itemDescription.isNotEmpty
          ? inv.itemDescription
          : it.description,
      item: it.description.isNotEmpty ? it.description : 'صنف ورشة',
      specifications: specs,
      type: it.sourceType,
      length: it.lengthCm > 0 ? '${it.lengthCm.fmt} سم' : '—',
      width: it.widthCm > 0 ? '${it.widthCm.fmt} سم' : '—',
      quantityText: '${it.quantity.fmt} ${it.unitCategory}',
      unitPrice: it.unitPrice > 0 ? it.unitPrice : it.agreedPrice,
      servicesText: _statementServicesText(it.services, inv.currency),
      total: it.grandTotal,
    );
  }).toList();
}

/// A single movement/transaction row inside the Statement of Account table.
class A4StatementLineItem {
  final int index;
  final DateTime date;
  final String documentNo;
  final String description;
  final String category;
  final String currency;
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;
  final String status;
  final bool isReturn;
  final String notes;
  final List<A4StatementDetailLine> details;

  const A4StatementLineItem({
    required this.index,
    required this.date,
    required this.documentNo,
    required this.description,
    this.category = '',
    required this.currency,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.status,
    this.isReturn = false,
    this.notes = '',
    this.details = const [],
  });

  String get currencySymbol => AppCurrency.symbol(currency);

  A4StatementLineItem withIndex(int newIndex) => A4StatementLineItem(
    index: newIndex,
    date: date,
    documentNo: documentNo,
    description: description,
    category: category,
    currency: currency,
    totalAmount: totalAmount,
    paidAmount: paidAmount,
    remainingAmount: remainingAmount,
    status: status,
    isReturn: isReturn,
    notes: notes,
    details: details,
  );
}

class A4StatementInvoiceDetails extends StatelessWidget {
  final A4StatementLineItem lineItem;

  const A4StatementInvoiceDetails({super.key, required this.lineItem});

  Widget _field(String label, String value, {bool isTotal = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 9,
                color: isTotal
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF334155),
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldRow(List<(String, String)> fields, {int totalIndex = -1}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < fields.length; i++)
          _field(fields[i].$1, fields[i].$2, isTotal: i == totalIndex),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsetsDirectional.only(start: 38, end: 10, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          ...lineItem.details.map(
            (detail) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                children: [
                  _fieldRow([
                    ('البيان / الوصف', detail.description),
                    ('الصنف', detail.item),
                    ('المواصفات', detail.specifications),
                    ('النوع', detail.type),
                    ('الطول', detail.length),
                  ]),
                  _fieldRow([
                    ('العرض', detail.width),
                    ('الكمية / الأمتار', detail.quantityText),
                    (
                      'سعر المتر / الوحدة',
                      detail.unitPrice == null
                          ? '—'
                          : '${detail.unitPrice!.fmt} ${lineItem.currencySymbol}',
                    ),
                    ('الخدمات', detail.servicesText),
                    (
                      'السعر الإجمالي',
                      '${detail.total.fmt} ${lineItem.currencySymbol}',
                    ),
                  ], totalIndex: 4),
                  if (detail != lineItem.details.last)
                    const Divider(height: 8, color: Color(0xFFCBD5E1)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Standardized data payload for generating and previewing an A4 Statement of Account.
class A4StatementData {
  final AccountStatementType type;
  final String statementNo;
  final DateTime issueDate;
  final String accountId;
  final String accountName;
  final String accountPhone;
  final String accountLocation;
  final String accountDescription;
  final String clientName; // For projects
  final String projectName; // For projects
  final List<A4StatementLineItem> items;
  final double currentBalanceUsd;
  final double currentBalanceSyp;
  final double openingBalanceUsd;
  final double openingBalanceSyp;

  const A4StatementData({
    required this.type,
    required this.statementNo,
    required this.issueDate,
    required this.accountId,
    required this.accountName,
    this.accountPhone = '',
    this.accountLocation = '',
    this.accountDescription = '',
    this.clientName = '',
    this.projectName = '',
    required this.items,
    required this.currentBalanceUsd,
    required this.currentBalanceSyp,
    this.openingBalanceUsd = 0.0,
    this.openingBalanceSyp = 0.0,
  });

  /// Returns a copy that only contains the selected rows (re-numbered).
  A4StatementData copyWithItems(List<A4StatementLineItem> selected) {
    final renumbered = <A4StatementLineItem>[];
    for (int i = 0; i < selected.length; i++) {
      renumbered.add(selected[i].withIndex(i + 1));
    }
    return A4StatementData(
      type: type,
      statementNo: statementNo,
      issueDate: issueDate,
      accountId: accountId,
      accountName: accountName,
      accountPhone: accountPhone,
      accountLocation: accountLocation,
      accountDescription: accountDescription,
      clientName: clientName,
      projectName: projectName,
      items: renumbered,
      currentBalanceUsd: currentBalanceUsd,
      currentBalanceSyp: currentBalanceSyp,
      openingBalanceUsd: openingBalanceUsd,
      openingBalanceSyp: openingBalanceSyp,
    );
  }

  String get roleTitle {
    switch (type) {
      case AccountStatementType.supplier:
        return 'مورد مصنع (Factory Supplier)';
      case AccountStatementType.accreditedAgent:
        return 'وكيل معتمد للمصنع (Accredited Agent)';
      case AccountStatementType.customer:
        return 'عميل / زبون معمل (Factory Customer)';
      case AccountStatementType.project:
        return 'مشروع مصنع (Factory Project)';
    }
  }

  String get roleBadgeText {
    switch (type) {
      case AccountStatementType.supplier:
        return 'موردي المصنع • ذمة دائنة';
      case AccountStatementType.accreditedAgent:
        return 'معتمدي المصنع • ذمة مدينة';
      case AccountStatementType.customer:
        return 'عملاء المصنع • ذمة مدينة';
      case AccountStatementType.project:
        return 'مشاريع المصنع • بيان حساب المشروع';
    }
  }

  Color get roleAccentColor {
    switch (type) {
      case AccountStatementType.supplier:
        return const Color(0xFFDC2626); // Red / Supplier liability
      case AccountStatementType.accreditedAgent:
        return const Color(0xFF2563EB); // Royal Blue
      case AccountStatementType.customer:
        return const Color(0xFF0D9488); // Teal
      case AccountStatementType.project:
        return const Color(0xFF7C3AED); // Purple
    }
  }

  String get balanceBannerTitle {
    switch (type) {
      case AccountStatementType.supplier:
        return 'صافي الرصيد المستحق للمورد (بذمة المصنع):';
      case AccountStatementType.accreditedAgent:
        return 'صافي الرصيد المستحق على المعتمد (لصالح المصنع):';
      case AccountStatementType.customer:
        return 'صافي الرصيد المستحق على العميل (لصالح المصنع):';
      case AccountStatementType.project:
        return 'صافي الرصيد المتبقي لتحصيل المشروع:';
    }
  }

  double get totalInvoicedUsd => items
      .where((i) => !i.isReturn && i.currency == AppCurrency.usd)
      .fold(0.0, (s, i) => s + i.totalAmount);

  double get totalInvoicedSyp => items
      .where((i) => !i.isReturn && i.currency == AppCurrency.syp)
      .fold(0.0, (s, i) => s + i.totalAmount);

  double get totalPaidUsd => items
      .where((i) => !i.isReturn && i.currency == AppCurrency.usd)
      .fold(0.0, (s, i) => s + i.paidAmount);

  double get totalPaidSyp => items
      .where((i) => !i.isReturn && i.currency == AppCurrency.syp)
      .fold(0.0, (s, i) => s + i.paidAmount);

  double get totalReturnsUsd => items
      .where((i) => i.isReturn && i.currency == AppCurrency.usd)
      .fold(0.0, (s, i) => s + i.totalAmount.abs());

  double get totalReturnsSyp => items
      .where((i) => i.isReturn && i.currency == AppCurrency.syp)
      .fold(0.0, (s, i) => s + i.totalAmount.abs());

  bool get isClearedViaReturns =>
      !hasOutstandingDue &&
      (totalReturnsUsd + totalReturnsSyp > 0.001) &&
      (totalPaidUsd < totalInvoicedUsd || totalPaidUsd <= 0.001);

  bool get hasOutstandingDue =>
      currentBalanceUsd > 0.01 || currentBalanceSyp > 0.01;

  String get dualCurrentBalance =>
      AppCurrency.dual(currentBalanceUsd, currentBalanceSyp);

  static List<A4StatementDetailLine> _adjustmentDetails(AdjustmentInvoiceModel ret) {
    if (ret.lines.isNotEmpty) {
      return ret.lines
          .map((l) => A4StatementDetailLine(
                description: l.description.isNotEmpty
                    ? l.description
                    : 'صنف مرتجع',
                item: l.description.isNotEmpty ? l.description : 'صنف مرتجع',
                specifications: l.isDamaged ? 'تالف / هدر غير طبيعي' : 'سليم',
                type: l.sourceType.isNotEmpty
                    ? l.sourceType
                    : (l.unit.isNotEmpty ? l.unit : 'مرتجع'),
                length: '—',
                width: '—',
                quantityText:
                    '${l.quantity.fmt} ${l.unit.isNotEmpty ? l.unit : "وحدة"}',
                unitPrice: l.unitPrice > 0
                    ? l.unitPrice
                    : (l.quantity > 0 ? l.amount / l.quantity : null),
                servicesText: '—',
                total: l.amount,
              ))
          .toList();
    }
    return [
      A4StatementDetailLine(
        description: ret.itemDescription.isNotEmpty
            ? ret.itemDescription
            : (ret.description.isNotEmpty ? ret.description : 'إشعار مرتجع'),
        item: ret.itemDescription.isNotEmpty
            ? ret.itemDescription
            : 'صنف مرتجع',
        specifications: '—',
        type: 'مرتجع',
        length: '—',
        width: '—',
        quantityText: ret.quantity > 0 ? '${ret.quantity.fmt} وحدة' : '—',
        unitPrice: ret.quantity > 0 ? ret.amount / ret.quantity : ret.amount,
        servicesText: '—',
        total: ret.amount,
      ),
    ];
  }

  static A4StatementLineItem _fromAdjustment({
    required int index,
    required AdjustmentInvoiceModel ret,
    required String category,
  }) {
    final isCashRefund = ret.paymentAction.contains('نقدي') ||
        ret.paymentAction == 'cash_refund';
    return A4StatementLineItem(
      index: index,
      date: ret.date,
      documentNo: ret.invoiceNo,
      description: ret.description.isNotEmpty
          ? 'إشعار مرتجع: ${ret.description}'
          : (ret.itemDescription.isNotEmpty
              ? 'إشعار مرتجع: ${ret.itemDescription}'
              : 'إشعار $category'),
      category: category,
      currency: ret.currency,
      totalAmount: ret.amount,
      paidAmount: isCashRefund ? ret.amount : 0.0,
      remainingAmount: 0.0,
      status: isCashRefund ? 'مرتجع نقدي' : 'مرتجع مسوى',
      isReturn: true,
      details: _adjustmentDetails(ret),
    );
  }

  static A4StatementLineItem _fromLegacyReturn({
    required int index,
    required ReturnInvoiceModel ret,
    required String category,
  }) {
    final isCashRefund = ret.paymentAction.contains('نقدي');
    return A4StatementLineItem(
      index: index,
      date: ret.date,
      documentNo: ret.returnNo,
      description: 'إشعار مرتجع: ${ret.itemDescription}',
      category: category,
      currency: ret.currency,
      totalAmount: ret.refundAmount,
      paidAmount: isCashRefund ? ret.refundAmount : 0.0,
      remainingAmount: 0.0,
      status: isCashRefund ? 'مرتجع نقدي' : 'مرتجع مسوى',
      isReturn: true,
      details: [
        A4StatementDetailLine(
          description: ret.itemDescription,
          item: ret.itemDescription,
          specifications: '—',
          type: ret.returnType,
          length: '—',
          width: '—',
          quantityText:
              '${ret.quantity.fmt} ${ret.unit.isNotEmpty ? ret.unit : "وحدة"}',
          unitPrice: ret.quantity > 0
              ? ret.refundAmount / ret.quantity
              : ret.refundAmount,
          servicesText: '—',
          total: ret.refundAmount,
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Factory constructor for Factory Suppliers
  // --------------------------------------------------------------------------
  factory A4StatementData.fromSupplier({
    required SupplierModel supplier,
    required ERPProvider erp,
  }) {
    final invs = erp.factoryInvoices
        .where(
          (i) =>
              i.invoiceType == 'شراء_مورد' &&
              (i.partyId == supplier.id ||
                  i.partyName.trim() == supplier.name.trim()),
        )
        .toList();
    invs.sort((a, b) => a.date.compareTo(b.date));

    final items = <A4StatementLineItem>[];
    int idx = 1;

    // Check opening legacy financial records
    final legacy = erp.openingEntry.legacyFinancials
        .where(
          (r) =>
              r.category == 'suppliers' &&
              r.name.trim() == supplier.name.trim(),
        )
        .toList();
    double legacyUsd = 0.0;
    double legacySyp = 0.0;
    for (final r in legacy) {
      if (AppCurrency.isSyp(r.currency)) {
        legacySyp += r.amount;
      } else {
        legacyUsd += r.amount;
      }
      items.add(
        A4StatementLineItem(
          index: idx++,
          date:
              erp.openingEntry.lockedAt ?? DateTime(DateTime.now().year, 1, 1),
          documentNo: 'قيد افتتاحي',
          description: r.description.isNotEmpty
              ? 'رصيد افتتاحي مدور: ${r.description}'
              : 'رصيد سابق مدور من القيد الافتتاحي',
          category: 'قيد افتتاحي',
          currency: r.currency,
          totalAmount: r.amount,
          paidAmount: 0.0,
          remainingAmount: r.amount,
          status: 'رصيد مدور',
        ),
      );
    }

    for (final inv in invs) {
      final desc = inv.items.isNotEmpty
          ? inv.items
                .map((it) {
                  final name = it.typeName.isNotEmpty
                      ? it.typeName
                      : it.description;
                  final qty = it.isMeterItem
                      ? '${it.quantity.fmt} ${it.meterUnit.isNotEmpty ? it.meterUnit : "متر"}'
                      : '${it.quantity.fmt} طن';
                  return '$name ($qty)';
                })
                .join(' + ')
          : 'فاتورة توريد مواد خام ومستلزمات';

      final originalRemaining = (inv.grandTotal - inv.advancePayment).clamp(0.0, double.infinity);
      final status = originalRemaining <= 0.01
          ? 'مدفوعة بالكامل'
          : (inv.remainingBalance <= 0.01 ? 'مصفى بالمرتجعات' : 'مستحق الدفع');

      items.add(
        A4StatementLineItem(
          index: idx++,
          date: inv.date,
          documentNo: inv.invoiceNo,
          description: desc,
          category: 'فاتورة شراء',
          currency: inv.currency,
          totalAmount: inv.grandTotal,
          paidAmount: inv.advancePayment,
          remainingAmount: originalRemaining,
          status: status,
          notes: inv.isGoodsDelivered ? 'واصلة' : 'غير واصلة (شحن مرسمل)',
          details: _factoryInvoiceDetails(inv, isSale: false),
        ),
      );
    }

    // Check return invoices
    final adjReturns = erp.adjustmentInvoices
        .where((r) =>
            r.isReturn &&
            (r.partyName.trim() == supplier.name.trim() ||
                invs.any((i) => i.id == r.targetInvoiceId)))
        .toList();
    for (final ret in adjReturns) {
      items.add(
        _fromAdjustment(
          index: idx++,
          ret: ret,
          category: 'مرتجع مشتريات',
        ),
      );
    }

    final legacyReturns = erp.returnInvoices
        .where((r) =>
            r.partyName.trim() == supplier.name.trim() &&
            !adjReturns.any((a) =>
                a.invoiceNo == r.returnNo ||
                (a.targetInvoiceId.isNotEmpty &&
                    a.targetInvoiceId == r.parentInvoiceId &&
                    (a.amount - r.refundAmount).abs() < 0.01)))
        .toList();
    for (final ret in legacyReturns) {
      items.add(
        _fromLegacyReturn(
          index: idx++,
          ret: ret,
          category: 'مرتجع مشتريات',
        ),
      );
    }

    items.sort((a, b) => a.date.compareTo(b.date));
    for (int i = 0; i < items.length; i++) {
      items[i] = items[i].withIndex(i + 1);
    }

    final serial =
        'SOA-SUP-${supplier.name.hashCode.abs().toString().padLeft(6, "0").substring(0, 6)}';

    return A4StatementData(
      type: AccountStatementType.supplier,
      statementNo: serial,
      issueDate: DateTime.now(),
      accountId: supplier.id,
      accountName: supplier.name,
      accountPhone: supplier.phone,
      accountLocation: supplier.location,
      items: items,
      currentBalanceUsd: supplier.debtBalance,
      currentBalanceSyp: supplier.debtBalanceSyp,
      openingBalanceUsd: legacyUsd,
      openingBalanceSyp: legacySyp,
    );
  }

  // --------------------------------------------------------------------------
  // Factory constructor for Factory Accredited Agents
  // --------------------------------------------------------------------------
  factory A4StatementData.fromAccreditedAgent({
    required ClientModel client,
    required ERPProvider erp,
  }) {
    final invs = erp.factoryInvoices
        .where(
          (i) =>
              i.invoiceType == 'بيع_معتمد' &&
              (i.partyId == client.id ||
                  i.partyName.trim() == client.name.trim()),
        )
        .toList();
    invs.sort((a, b) => a.date.compareTo(b.date));

    final items = <A4StatementLineItem>[];
    int idx = 1;

    final legacy = erp.openingEntry.legacyFinancials
        .where(
          (r) => r.category == 'clients' && r.name.trim() == client.name.trim(),
        )
        .toList();
    double legacyUsd = 0.0;
    double legacySyp = 0.0;
    for (final r in legacy) {
      if (AppCurrency.isSyp(r.currency)) {
        legacySyp += r.amount;
      } else {
        legacyUsd += r.amount;
      }
      items.add(
        A4StatementLineItem(
          index: idx++,
          date:
              erp.openingEntry.lockedAt ?? DateTime(DateTime.now().year, 1, 1),
          documentNo: 'قيد افتتاحي',
          description: r.description.isNotEmpty
              ? 'رصيد افتتاحي سابق: ${r.description}'
              : 'رصيد ذمة افتتاحية سابقة',
          category: 'قيد افتتاحي',
          currency: r.currency,
          totalAmount: r.amount,
          paidAmount: 0.0,
          remainingAmount: r.amount,
          status: 'رصيد مدور',
        ),
      );
    }

    for (final inv in invs) {
      final desc = inv.items.isNotEmpty
          ? inv.items
                .map((it) {
                  final name = it.typeName.isNotEmpty
                      ? it.typeName
                      : it.description;
                  return '$name (${it.quantity.fmt} قطعة)';
                })
                .join(' + ')
          : 'فاتورة مبيعات مستودع المصنع';

      final originalRemaining = (inv.grandTotal - inv.advancePayment).clamp(0.0, double.infinity);
      final status = originalRemaining <= 0.01
          ? 'مسددة بالكامل'
          : (inv.remainingBalance <= 0.01 ? 'مصفى بالمرتجعات' : 'مستحق التحصيل');

      items.add(
        A4StatementLineItem(
          index: idx++,
          date: inv.date,
          documentNo: inv.invoiceNo,
          description: desc,
          category: 'فاتورة مبيعات',
          currency: inv.currency,
          totalAmount: inv.grandTotal,
          paidAmount: inv.advancePayment,
          remainingAmount: originalRemaining,
          status: status,
          details: _factoryInvoiceDetails(inv, isSale: true),
        ),
      );
    }

    // Check return invoices
    final adjReturns = erp.adjustmentInvoices
        .where((r) =>
            r.isReturn &&
            (r.partyName.trim() == client.name.trim() ||
                invs.any((i) => i.id == r.targetInvoiceId)))
        .toList();
    for (final ret in adjReturns) {
      items.add(
        _fromAdjustment(
          index: idx++,
          ret: ret,
          category: 'مرتجع مبيعات',
        ),
      );
    }

    final legacyReturns = erp.returnInvoices
        .where((r) =>
            r.partyName.trim() == client.name.trim() &&
            !adjReturns.any((a) =>
                a.invoiceNo == r.returnNo ||
                (a.targetInvoiceId.isNotEmpty &&
                    a.targetInvoiceId == r.parentInvoiceId &&
                    (a.amount - r.refundAmount).abs() < 0.01)))
        .toList();
    for (final ret in legacyReturns) {
      items.add(
        _fromLegacyReturn(
          index: idx++,
          ret: ret,
          category: 'مرتجع مبيعات',
        ),
      );
    }

    items.sort((a, b) => a.date.compareTo(b.date));
    for (int i = 0; i < items.length; i++) {
      items[i] = items[i].withIndex(i + 1);
    }

    final serial =
        'SOA-AGT-${client.name.hashCode.abs().toString().padLeft(6, "0").substring(0, 6)}';

    return A4StatementData(
      type: AccountStatementType.accreditedAgent,
      statementNo: serial,
      issueDate: DateTime.now(),
      accountId: client.id,
      accountName: client.name,
      accountPhone: client.phone,
      accountLocation: client.location,
      accountDescription: client.description,
      items: items,
      currentBalanceUsd: client.debtBalance,
      currentBalanceSyp: client.debtBalanceSyp,
      openingBalanceUsd: legacyUsd,
      openingBalanceSyp: legacySyp,
    );
  }

  // --------------------------------------------------------------------------
  // Factory constructor for Factory Customers (Workshop Retail Clients)
  // --------------------------------------------------------------------------
  factory A4StatementData.fromCustomer({
    required ClientModel client,
    required ERPProvider erp,
  }) {
    final invs = erp.workshopInvoices
        .where(
          (i) =>
              i.projectId.isEmpty && i.clientName.trim() == client.name.trim(),
        )
        .toList();
    invs.sort((a, b) => a.date.compareTo(b.date));

    final items = <A4StatementLineItem>[];
    int idx = 1;

    final legacy = erp.openingEntry.legacyFinancials
        .where(
          (r) => r.category == 'clients' && r.name.trim() == client.name.trim(),
        )
        .toList();
    double legacyUsd = 0.0;
    double legacySyp = 0.0;
    for (final r in legacy) {
      if (AppCurrency.isSyp(r.currency)) {
        legacySyp += r.amount;
      } else {
        legacyUsd += r.amount;
      }
      items.add(
        A4StatementLineItem(
          index: idx++,
          date:
              erp.openingEntry.lockedAt ?? DateTime(DateTime.now().year, 1, 1),
          documentNo: 'قيد افتتاحي',
          description: r.description.isNotEmpty
              ? 'رصيد افتتاحي سابق: ${r.description}'
              : 'رصيد ذمة زبون سابقة',
          category: 'قيد افتتاحي',
          currency: r.currency,
          totalAmount: r.amount,
          paidAmount: 0.0,
          remainingAmount: r.amount,
          status: 'رصيد مدور',
        ),
      );
    }

    for (final inv in invs) {
      String desc;
      if (inv.items.isNotEmpty) {
        desc = inv.items
            .map((it) {
              return '${it.description.isNotEmpty ? it.description : "صنف ورشة"} (${it.quantity.fmt} ${it.unitCategory})';
            })
            .join(' + ');
      } else {
        desc = inv.itemDescription.isNotEmpty
            ? '${inv.itemDescription} (${inv.sourceType})'
            : 'أعمال وتفصيل رخام وجرانيت ورشة المعمل';
      }

      final originalRemaining = (inv.grandTotal - (inv.cashPaidNow + inv.depositDeducted)).clamp(0.0, double.infinity);
      final status = originalRemaining <= 0.01
          ? 'مسددة بالكامل'
          : (inv.remainingBalance <= 0.01 ? 'مصفى بالمرتجعات' : 'مستحق التحصيل');

      items.add(
        A4StatementLineItem(
          index: idx++,
          date: inv.date,
          documentNo: inv.invoiceNo,
          description: desc,
          category: inv.sourceType,
          currency: inv.currency,
          totalAmount: inv.grandTotal,
          paidAmount: inv.cashPaidNow + inv.depositDeducted,
          remainingAmount: originalRemaining,
          status: status,
          details: _workshopInvoiceDetails(inv),
        ),
      );
    }

    // Check return invoices
    final adjReturns = erp.adjustmentInvoices
        .where((r) =>
            r.isReturn &&
            (r.partyName.trim() == client.name.trim() ||
                invs.any((i) => i.id == r.targetInvoiceId)))
        .toList();
    for (final ret in adjReturns) {
      items.add(
        _fromAdjustment(
          index: idx++,
          ret: ret,
          category: 'مرتجع مبيعات معمل',
        ),
      );
    }

    final legacyReturns = erp.returnInvoices
        .where((r) =>
            r.partyName.trim() == client.name.trim() &&
            !adjReturns.any((a) =>
                a.invoiceNo == r.returnNo ||
                (a.targetInvoiceId.isNotEmpty &&
                    a.targetInvoiceId == r.parentInvoiceId &&
                    (a.amount - r.refundAmount).abs() < 0.01)))
        .toList();
    for (final ret in legacyReturns) {
      items.add(
        _fromLegacyReturn(
          index: idx++,
          ret: ret,
          category: 'مرتجع مبيعات معمل',
        ),
      );
    }

    items.sort((a, b) => a.date.compareTo(b.date));
    for (int i = 0; i < items.length; i++) {
      items[i] = items[i].withIndex(i + 1);
    }

    final serial =
        'SOA-CUST-${client.name.hashCode.abs().toString().padLeft(6, "0").substring(0, 6)}';

    return A4StatementData(
      type: AccountStatementType.customer,
      statementNo: serial,
      issueDate: DateTime.now(),
      accountId: client.id,
      accountName: client.name,
      accountPhone: client.phone,
      accountLocation: client.location,
      accountDescription: client.description,
      items: items,
      currentBalanceUsd: client.debtBalance,
      currentBalanceSyp: client.debtBalanceSyp,
      openingBalanceUsd: legacyUsd,
      openingBalanceSyp: legacySyp,
    );
  }

  // --------------------------------------------------------------------------
  // Factory constructor for Factory Projects
  // --------------------------------------------------------------------------
  factory A4StatementData.fromProject({
    required WorkshopProjectModel project,
    required ERPProvider erp,
  }) {
    final invs = erp.workshopInvoices
        .where((i) => i.projectId == project.id)
        .toList();
    invs.sort((a, b) => a.date.compareTo(b.date));

    final items = <A4StatementLineItem>[];
    int idx = 1;

    for (final inv in invs) {
      String desc;
      if (inv.items.isNotEmpty) {
        desc = inv.items
            .map((it) {
              return '${it.description.isNotEmpty ? it.description : "بند مشروع"} (${it.quantity.fmt} ${it.unitCategory})';
            })
            .join(' + ');
      } else {
        desc = inv.itemDescription.isNotEmpty
            ? '${inv.itemDescription} (${inv.sourceType})'
            : 'تنفيذ أعمال رخام وجرانيت للمشروع';
      }

      final originalRemaining = (inv.grandTotal - (inv.cashPaidNow + inv.depositDeducted)).clamp(0.0, double.infinity);
      final status = originalRemaining <= 0.01
          ? 'مسدد بالكامل'
          : (inv.remainingBalance <= 0.01 ? 'مصفى بالمرتجعات' : 'متبقي');

      items.add(
        A4StatementLineItem(
          index: idx++,
          date: inv.date,
          documentNo: inv.invoiceNo,
          description: desc,
          category: 'فاتورة مشروع',
          currency: inv.currency,
          totalAmount: inv.grandTotal,
          paidAmount: inv.cashPaidNow + inv.depositDeducted,
          remainingAmount: originalRemaining,
          status: status,
          details: _workshopInvoiceDetails(inv),
        ),
      );
    }

    // Check return invoices for this project
    final adjReturns = erp.adjustmentInvoices
        .where((r) =>
            r.isReturn &&
            invs.any((i) => i.id == r.targetInvoiceId))
        .toList();
    for (final ret in adjReturns) {
      items.add(
        _fromAdjustment(
          index: idx++,
          ret: ret,
          category: 'مرتجع مشروع',
        ),
      );
    }

    items.sort((a, b) => a.date.compareTo(b.date));
    for (int i = 0; i < items.length; i++) {
      items[i] = items[i].withIndex(i + 1);
    }

    final dueUsd = erp.projectDue(project.id);
    final dueSyp = erp.projectDueSyp(project.id);

    final serial =
        'SOA-PRJ-${project.name.hashCode.abs().toString().padLeft(6, "0").substring(0, 6)}';

    return A4StatementData(
      type: AccountStatementType.project,
      statementNo: serial,
      issueDate: DateTime.now(),
      accountId: project.id,
      accountName: 'مشروع: ${project.name}',
      clientName: project.clientName,
      projectName: project.name,
      accountPhone: project.phone,
      accountLocation: '',
      accountDescription: project.description,
      items: items,
      currentBalanceUsd: dueUsd,
      currentBalanceSyp: dueSyp,
    );
  }
}

/// A4 Paper Statement of Account Print Preview Modal Dialog.
class A4StatementPrintDialog extends StatefulWidget {
  final A4StatementData statementData;

  const A4StatementPrintDialog({super.key, required this.statementData});

  /// Launches the invoice selection step, then the preview modal.
  static Future<void> show(
    BuildContext context, {
    required A4StatementData statementData,
  }) async {
    A4StatementData toPreview = statementData;
    if (statementData.items.isNotEmpty) {
      final selected = await showDialog<List<A4StatementLineItem>>(
        context: context,
        barrierDismissible: true,
        builder: (_) => A4StatementInvoiceSelectionDialog(data: statementData),
      );
      if (selected == null) return;
      toPreview = statementData.copyWithItems(selected);
    }
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => A4StatementPrintDialog(statementData: toPreview),
    );
  }

  @override
  State<A4StatementPrintDialog> createState() => _A4StatementPrintDialogState();
}

class _A4StatementPrintDialogState extends State<A4StatementPrintDialog> {
  final List<GlobalKey> _pageKeys = [];
  bool _isPrinting = false;
  bool _isBlackAndWhite = false;

  static const ColorFilter _blackAndWhiteFilter = ColorFilter.matrix(<double>[
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);

  Widget _wrapWithPrintMode(Widget child) {
    if (!_isBlackAndWhite) return child;
    return ColorFiltered(colorFilter: _blackAndWhiteFilter, child: child);
  }

  late final List<List<A4StatementLineItem>> _paginatedItems;

  @override
  void initState() {
    super.initState();
    _paginate();
  }

  double _rowWeight(A4StatementLineItem it) => 1.0 + 1.1 * it.details.length;

  void _paginate() {
    final allItems = widget.statementData.items;
    if (allItems.isEmpty) {
      _paginatedItems = [[]];
      _pageKeys.add(GlobalKey());
      return;
    }

    // Rows now include their item lines, so pages are filled by weight.
    final totalWeight = allItems.fold<double>(0.0, (s, i) => s + _rowWeight(i));
    if (totalWeight <= 11) {
      _paginatedItems = [allItems];
      _pageKeys.add(GlobalKey());
      return;
    }

    _paginatedItems = [];
    var page = <A4StatementLineItem>[];
    var weight = 0.0;
    var cap = 10.0; // page 1 also holds header + metadata
    for (final it in allItems) {
      final w = _rowWeight(it);
      if (page.isNotEmpty && weight + w > cap) {
        _paginatedItems.add(page);
        _pageKeys.add(GlobalKey());
        page = <A4StatementLineItem>[];
        weight = 0.0;
        cap = 14.0;
      }
      page.add(it);
      weight += w;
    }
    if (page.isNotEmpty) {
      _paginatedItems.add(page);
      _pageKeys.add(GlobalKey());
    }
  }

  Future<void> _handleDirectPrint() async {
    setState(() => _isPrinting = true);
    try {
      final pdfDoc = pw.Document();

      for (int i = 0; i < _pageKeys.length; i++) {
        final key = _pageKeys[i];
        final boundary =
            key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) continue;

        final ui.Image image = await boundary.toImage(pixelRatio: 2.5);
        final ByteData? byteData = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (byteData == null) continue;

        final Uint8List pngBytes = byteData.buffer.asUint8List();
        final pdfImage = pw.MemoryImage(pngBytes);

        pdfDoc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) => pw.FullPage(
              ignoreMargins: true,
              child: pw.Center(
                child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
              ),
            ),
          ),
        );
      }

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfDoc.save(),
        name:
            'كشف_حساب_${widget.statementData.accountName}${_isBlackAndWhite ? "_BW" : ""}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر إرسال أمر الطباعة: $e'),
            backgroundColor: AppColors.dangerWaste,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final erp = Provider.of<ERPProvider>(context);
    final centerInfo = erp.centerInfo;
    final data = widget.statementData;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 960,
        height: MediaQuery.of(context).size.height * 0.95,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 28,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top Toolbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF334155),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: Color(0xFF38BDF8),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'معاينة كشف الحساب قياس A4 (Statement of Account Preview)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${data.accountName} • ${data.roleTitle} • رقم المستند: ${data.statementNo}',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      // Color / B&W Version Toggle
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        padding: const EdgeInsets.all(2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () =>
                                  setState(() => _isBlackAndWhite = false),
                              borderRadius: BorderRadius.circular(6),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: !_isBlackAndWhite
                                      ? const Color(0xFF1E293B)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: !_isBlackAndWhite
                                      ? Border.all(
                                          color: const Color(0x8038BDF8),
                                        )
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.palette_rounded,
                                      size: 14,
                                      color: !_isBlackAndWhite
                                          ? const Color(0xFF38BDF8)
                                          : const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'ملونة (الأصل)',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: !_isBlackAndWhite
                                            ? FontWeight.w900
                                            : FontWeight.w600,
                                        color: !_isBlackAndWhite
                                            ? Colors.white
                                            : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () =>
                                  setState(() => _isBlackAndWhite = true),
                              borderRadius: BorderRadius.circular(6),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _isBlackAndWhite
                                      ? const Color(0xFF1E293B)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: _isBlackAndWhite
                                      ? Border.all(
                                          color: const Color(0x80E2E8F0),
                                        )
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.filter_b_and_w_rounded,
                                      size: 14,
                                      color: _isBlackAndWhite
                                          ? Colors.white
                                          : const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'أبيض وأسود',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: _isBlackAndWhite
                                            ? FontWeight.w900
                                            : FontWeight.w600,
                                        color: _isBlackAndWhite
                                            ? Colors.white
                                            : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isBlackAndWhite
                              ? const Color(0xFF334155)
                              : const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 11,
                          ),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _isPrinting ? null : _handleDirectPrint,
                        icon: _isPrinting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _isBlackAndWhite
                                    ? Icons.print_outlined
                                    : Icons.print_rounded,
                                size: 18,
                              ),
                        label: Text(
                          _isPrinting
                              ? 'جارٍ المعالجة...'
                              : _isBlackAndWhite
                              ? 'طباعة أبيض وأسود / PDF'
                              : 'طباعة ملونة / PDF',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        tooltip: 'إغلاق المعاينة',
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white70,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Scrollable Preview Container displaying standard A4 sheets
            Expanded(
              child: Container(
                color: const Color(0xFF0B132B),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 16,
                  ),
                  child: Center(
                    child: Column(
                      children: List.generate(_paginatedItems.length, (
                        pageIdx,
                      ) {
                        final isFirstPage = pageIdx == 0;
                        final isLastPage =
                            pageIdx == _paginatedItems.length - 1;
                        final pageItems = _paginatedItems[pageIdx];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: RepaintBoundary(
                            key: _pageKeys[pageIdx],
                            child: _wrapWithPrintMode(
                              _buildA4Paper(
                                context: context,
                                centerInfo: centerInfo,
                                data: data,
                                pageItems: pageItems,
                                pageNumber: pageIdx + 1,
                                totalPages: _paginatedItems.length,
                                isFirstPage: isFirstPage,
                                isLastPage: isLastPage,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Single A4 sheet (794px width x 1123px min height)
  Widget _buildA4Paper({
    required BuildContext context,
    required CenterInfoModel centerInfo,
    required A4StatementData data,
    required List<A4StatementLineItem> pageItems,
    required int pageNumber,
    required int totalPages,
    required bool isFirstPage,
    required bool isLastPage,
  }) {
    return Container(
      width: 794,
      constraints: const BoxConstraints(minHeight: 1123),
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Accent Ribbon
            Container(
              height: 5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0F172A),
                    data.roleAccentColor,
                    const Color(0xFF2563EB),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 1. Company / Center Header
            _buildCompanyHeader(centerInfo),
            const SizedBox(height: 12),

            // 2. Statement Title Banner & Account Metadata
            if (isFirstPage) ...[
              _buildStatementTitleBanner(data),
              const SizedBox(height: 12),
              _buildAccountMetaSection(data),
              const SizedBox(height: 16),
            ] else ...[
              // Continuation banner on secondary pages
              _buildContinuationHeader(data, pageNumber, totalPages),
              const SizedBox(height: 14),
            ],

            // 3. Transactions Table
            _buildTransactionsTable(pageItems, data),
            const SizedBox(height: 16),

            // If last page: 4. Financial Summary & Totals + Signatures
            if (isLastPage) ...[
              _buildFinancialSummary(data),
              const SizedBox(height: 24),
              _buildSignaturesFooter(centerInfo, data),
              const SizedBox(height: 16),
            ] else ...[
              // Page break note
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.centerLeft,
                child: Text(
                  'يتبع في الصفحة التالية ($pageNumber من $totalPages)...',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // 5. Bottom System Verification Footer
            Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'برنامج Sh Ab\'ad • هاتف: 0931691900 • مستند مالي معتمد',
                      style: TextStyle(fontSize: 9.5, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'صفحة $pageNumber من $totalPages • تاريخ الطباعة: ${intl.DateFormat("yyyy-MM-dd HH:mm").format(DateTime.now())}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 1. Company Header with full details and logo
  Widget _buildCompanyHeader(CenterInfoModel center) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Center info
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                center.centerName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 3),
              if (center.slogan.isNotEmpty)
                Text(
                  center.slogan,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFD97706),
                  ),
                ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  if (center.ownerName.isNotEmpty)
                    _buildHeaderBadge(
                      Icons.person_outline_rounded,
                      'المالك/الإدارة: ${center.ownerName}',
                    ),
                  if (center.commercialRegNo.isNotEmpty)
                    _buildHeaderBadge(
                      Icons.receipt_long_rounded,
                      'س.ت: ${center.commercialRegNo}',
                    ),
                  if (center.taxId.isNotEmpty)
                    _buildHeaderBadge(
                      Icons.shield_outlined,
                      'الرقم الضريبي: ${center.taxId}',
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(
                    Icons.phone_in_talk_rounded,
                    size: 13,
                    color: Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'هاتف: ${center.phone1}${center.phone2.isNotEmpty ? " • ${center.phone2}" : ""}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                    ),
                  ),
                  if (center.address.isNotEmpty) ...[
                    const SizedBox(width: 14),
                    const Icon(
                      Icons.location_on_outlined,
                      size: 13,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        center.address,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // Logo
        Expanded(
          flex: 2,
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: _buildCenterLogo(center),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderBadge(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
        ),
      ],
    );
  }

  Widget _buildCenterLogo(CenterInfoModel center) {
    final path = center.logoPath.trim();
    if (path.isNotEmpty) {
      if (path.startsWith('http://') || path.startsWith('https://')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            path,
            width: 86,
            height: 86,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _buildFallbackLogo(center),
          ),
        );
      }
      final file = File(path);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            file,
            width: 86,
            height: 86,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _buildFallbackLogo(center),
          ),
        );
      }
    }
    return _buildFallbackLogo(center);
  }

  Widget _buildFallbackLogo(CenterInfoModel center) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.domain_rounded, size: 34, color: Color(0xFF0F172A)),
          SizedBox(height: 3),
          Text(
            'شعار المركز',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Statement Title Banner
  Widget _buildStatementTitleBanner(A4StatementData data) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Role Badge & Statement Title (Flexible so it never overflows)
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3.5,
                  ),
                  decoration: BoxDecoration(
                    color: data.roleAccentColor,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    data.roleBadgeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Flexible(
                  child: Text(
                    'كشف حساب مالي تفصيلي',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Statement Serial & Issue Date
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Text(
                  'رقم الكشف: ${data.statementNo}',
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'تاريخ الإصدار: ${intl.DateFormat("yyyy-MM-dd").format(data.issueDate)}',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContinuationHeader(
    A4StatementData data,
    int pageNumber,
    int totalPages,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'تابع كشف حساب: ${data.accountName} (${data.roleTitle})',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'الصفحة $pageNumber من $totalPages',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  /// 2b. Account Metadata Section
  Widget _buildAccountMetaSection(A4StatementData data) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 4,
                child: _buildMetaField(
                  label: 'اسم صاحب الحساب / الجهة:',
                  value: data.accountName,
                  isBold: true,
                  valueColor: const Color(0xFF0F172A),
                ),
              ),
              Expanded(
                flex: 3,
                child: _buildMetaField(
                  label: 'الصفة / التصنيف:',
                  value: data.roleTitle,
                ),
              ),
              Expanded(
                flex: 3,
                child: _buildMetaField(
                  label: 'حالة الحساب المالية:',
                  value: data.hasOutstandingDue
                      ? 'ذمة مستحقة'
                      : (data.isClearedViaReturns
                          ? 'مصفى بالمرتجعات'
                          : 'خالص ومسدد بالكامل'),
                  valueColor: data.hasOutstandingDue
                      ? const Color(0xFFDC2626)
                      : (data.isClearedViaReturns
                          ? const Color(0xFF7C3AED)
                          : const Color(0xFF16A34A)),
                  isBold: true,
                ),
              ),
            ],
          ),
          const Divider(height: 14, color: Color(0xFFE2E8F0)),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: _buildMetaField(
                  label: data.type == AccountStatementType.project
                      ? 'العميل صاحب المشروع:'
                      : 'رقم الهاتف / التواصل:',
                  value: data.type == AccountStatementType.project
                      ? (data.clientName.isNotEmpty ? data.clientName : '—')
                      : (data.accountPhone.isNotEmpty
                            ? data.accountPhone
                            : '—'),
                ),
              ),
              Expanded(
                flex: 3,
                child: _buildMetaField(
                  label: data.type == AccountStatementType.project
                      ? 'هاتف المشروع:'
                      : 'العنوان / الموقع:',
                  value: data.type == AccountStatementType.project
                      ? (data.accountPhone.isNotEmpty ? data.accountPhone : '—')
                      : (data.accountLocation.isNotEmpty
                            ? data.accountLocation
                            : '—'),
                ),
              ),
              Expanded(
                flex: 3,
                child: _buildMetaField(
                  label: 'إجمالي الحركات المسجلة:',
                  value: '${data.items.length} حركة / فاتورة',
                ),
              ),
            ],
          ),
          if (data.accountDescription.isNotEmpty) ...[
            const Divider(height: 14, color: Color(0xFFE2E8F0)),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                children: [
                  const Text(
                    'ملاحظات الحساب: ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      data.accountDescription,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF334155),
                      ),
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildMetaField({
    required String label,
    required String value,
    bool isBold = false,
    Color valueColor = const Color(0xFF334155),
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// 3. Transactions Table
  Widget _buildTransactionsTable(
    List<A4StatementLineItem> pageItems,
    A4StatementData data,
  ) {
    if (pageItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        alignment: Alignment.center,
        child: Column(
          children: const [
            Icon(
              Icons.receipt_long_outlined,
              size: 36,
              color: Color(0xFF94A3B8),
            ),
            SizedBox(height: 8),
            Text(
              'لا توجد حركات أو فواتير مسجلة حالياً على هذا الحساب.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'الرصيد يمثل ذمة افتتاحية أو لم تسجل عليه حركات شراء/بيع بعد.',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Table Header
          Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: const [
                SizedBox(
                  width: 28,
                  child: Text(
                    'م',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Text(
                    'التاريخ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    'رقم السند/الفاتورة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Text(
                    'البيان وتفاصيل العملية',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    'العملة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 82,
                  child: Text(
                    'القيمة الإجمالية',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    'المدفوع/المسدد',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 82,
                  child: Text(
                    'المتبقي',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 74,
                  child: Text(
                    'الحالة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          // Table Rows
          ...List.generate(pageItems.length, (idx) {
            final it = pageItems[idx];
            final isEven = idx % 2 == 0;
            final isDue = it.remainingAmount > 0.01;
            final isClearedReturn = it.status == 'مصفى بالمرتجعات';
            final statusBg = it.isReturn
                ? const Color(0xFFF3E8FF)
                : (isClearedReturn
                    ? const Color(0xFFF3E8FF)
                    : (isDue ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7)));
            final statusTextColor = it.isReturn
                ? const Color(0xFF6B21A8)
                : (isClearedReturn
                    ? const Color(0xFF6B21A8)
                    : (isDue ? const Color(0xFF991B1B) : const Color(0xFF166534)));

            final rowWidget = Container(
              color: it.isReturn
                  ? const Color(0xFFFAF5FF)
                  : (isEven ? Colors.white : const Color(0xFFF8FAFC)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${it.index}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: 72,
                    child: Text(
                      intl.DateFormat('yyyy-MM-dd').format(it.date),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      it.documentNo,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: it.isReturn
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Text(
                      it.description,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppCurrency.isSyp(it.currency)
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          it.currencySymbol,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppCurrency.isSyp(it.currency)
                                ? const Color(0xFFB45309)
                                : const Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 82,
                    child: Text(
                      it.isReturn
                          ? '-${it.totalAmount.fmt} ${it.currencySymbol}'
                          : '${it.totalAmount.fmt} ${it.currencySymbol}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: it.isReturn
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      '${it.paidAmount.fmt} ${it.currencySymbol}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF16A34A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: 82,
                    child: Text(
                      '${it.remainingAmount.fmt} ${it.currencySymbol}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDue
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: 74,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          it.status,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: statusTextColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                rowWidget,
                if (it.details.isNotEmpty)
                  A4StatementInvoiceDetails(lineItem: it),
              ],
            );
          }),
        ],
      ),
    );
  }

  /// 4. Financial Summary & Totals Box
  Widget _buildFinancialSummary(A4StatementData data) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // USD Totals breakdown (if any USD movements)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.attach_money_rounded,
                              size: 14,
                              color: Color(0xFF2563EB),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'حركات الدولار (\$ USD)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _buildSummaryLine(
                          'إجمالي الفواتير / المطالبات:',
                          '${data.totalInvoicedUsd.fmt} \$',
                        ),
                        if (data.totalReturnsUsd > 0.001)
                          _buildSummaryLine(
                            'إجمالي المرتجعات:',
                            '-${data.totalReturnsUsd.fmt} \$',
                            color: const Color(0xFF7C3AED),
                            isBold: true,
                          ),
                        _buildSummaryLine(
                          'إجمالي المدفوع / المسدد:',
                          '${data.totalPaidUsd.fmt} \$',
                          color: const Color(0xFF16A34A),
                        ),
                        _buildSummaryLine(
                          'المتبقي بالدولار:',
                          '${data.currentBalanceUsd.fmt} \$',
                          color: data.currentBalanceUsd > 0.01
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF16A34A),
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // SYP Totals breakdown
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.currency_exchange_rounded,
                              size: 14,
                              color: Color(0xFFD97706),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'حركات الليرة السورية (ل.س SYP)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _buildSummaryLine(
                          'إجمالي الفواتير / المطالبات:',
                          '${data.totalInvoicedSyp.fmt} ل.س',
                        ),
                        if (data.totalReturnsSyp > 0.001)
                          _buildSummaryLine(
                            'إجمالي المرتجعات:',
                            '-${data.totalReturnsSyp.fmt} ل.س',
                            color: const Color(0xFF7C3AED),
                            isBold: true,
                          ),
                        _buildSummaryLine(
                          'إجمالي المدفوع / المسدد:',
                          '${data.totalPaidSyp.fmt} ل.س',
                          color: const Color(0xFF16A34A),
                        ),
                        _buildSummaryLine(
                          'المتبقي بالليرة السورية:',
                          '${data.currentBalanceSyp.fmt} ل.س',
                          color: data.currentBalanceSyp > 0.01
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF16A34A),
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Highlighted Net Outstanding Balance Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: data.hasOutstandingDue
                  ? const Color(0xFFFEF2F2)
                  : const Color(0xFFF0FDF4),
              border: Border(
                top: BorderSide(
                  color: data.hasOutstandingDue
                      ? const Color(0xFFFCA5A5)
                      : const Color(0xFF86EFAC),
                ),
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(7),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        data.hasOutstandingDue
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline_rounded,
                        color: data.hasOutstandingDue
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF16A34A),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          data.balanceBannerTitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: data.hasOutstandingDue
                                ? const Color(0xFF991B1B)
                                : const Color(0xFF166534),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  data.dualCurrentBalance,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: data.hasOutstandingDue
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLine(
    String label,
    String value, {
    Color color = const Color(0xFF0F172A),
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// 5. Signatures & Approvals Section
  Widget _buildSignaturesFooter(CenterInfoModel center, A4StatementData data) {
    return Row(
      children: [
        Expanded(
          child: _buildSignatureBox(
            'توقيع منظم الكشف / المحاسب',
            'التوقيع: ...................................',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSignatureBox(
            'المدير المالي وإدارة المركز',
            center.centerName,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSignatureBox(
            'مصادقة صاحب الحساب / المستلم',
            'الاسم: ${data.accountName}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSignatureBox(
            'خاتم الحسابات والإدارة المالية',
            'خاتم الاعتماد الرسمي',
          ),
        ),
      ],
    );
  }

  Widget _buildSignatureBox(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF334155),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
