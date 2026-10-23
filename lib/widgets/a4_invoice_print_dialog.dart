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

/// Single line item in the standardized A4 Printable Invoice Table.
class A4InvoiceLineItem {
  final int index;
  final String description;
  final String gradeAndSpecs;
  final String dimensionsText;
  final double? lengthCm;
  final double? widthCm;
  final double? heightCm;
  final double? count;
  final String quantityText;
  final double unitPrice;
  final String servicesText;
  final double lineTotal;

  const A4InvoiceLineItem({
    required this.index,
    required this.description,
    this.gradeAndSpecs = '—',
    this.dimensionsText = '—',
    this.lengthCm,
    this.widthCm,
    this.heightCm,
    this.count,
    required this.quantityText,
    required this.unitPrice,
    this.servicesText = '—',
    required this.lineTotal,
  });

  bool get hasDimensions {
    if (lengthCm != null && lengthCm! > 0 && widthCm != null && widthCm! > 0) {
      return true;
    }
    if (dimensionsText != '—') {
      if (dimensionsText.contains('×') ||
          dimensionsText.contains('x') ||
          dimensionsText.contains('X') ||
          dimensionsText.contains('*')) {
        return true;
      }
      final match = RegExp(r'(\d+(?:\.\d+)?)\s*[*×xX]\s*(\d+(?:\.\d+)?)')
          .firstMatch(dimensionsText);
      if (match != null) return true;
    }
    return false;
  }

  String get lengthDisplay {
    if (lengthCm != null && lengthCm! > 0) {
      return '${lengthCm!.fmt} سم';
    }
    if (dimensionsText != '—') {
      final match = RegExp(r'(\d+(?:\.\d+)?)\s*[*×xX]\s*(\d+(?:\.\d+)?)')
          .firstMatch(dimensionsText);
      if (match != null) {
        final val = double.tryParse(match.group(1)!);
        return val != null ? '${val.fmt} سم' : '${match.group(1)} سم';
      }
      final parts = dimensionsText.replaceAll('سم', '').split(RegExp(r'[*×xX]'));
      if (parts.isNotEmpty && parts[0].trim().isNotEmpty) {
        final val = double.tryParse(parts[0].trim());
        return val != null ? '${val.fmt} سم' : '${parts[0].trim()} سم';
      }
    }
    return '—';
  }

  String get widthDisplay {
    if (widthCm != null && widthCm! > 0) {
      return '${widthCm!.fmt} سم';
    }
    if (dimensionsText != '—') {
      final match = RegExp(r'(\d+(?:\.\d+)?)\s*[*×xX]\s*(\d+(?:\.\d+)?)')
          .firstMatch(dimensionsText);
      if (match != null) {
        final val = double.tryParse(match.group(2)!);
        return val != null ? '${val.fmt} سم' : '${match.group(2)} سم';
      }
      final parts = dimensionsText.replaceAll('سم', '').split(RegExp(r'[*×xX]'));
      if (parts.length > 1 && parts[1].trim().isNotEmpty) {
        final val = double.tryParse(parts[1].trim());
        return val != null ? '${val.fmt} سم' : '${parts[1].trim()} سم';
      }
    }
    return '—';
  }
}

/// Standardized data payload adapted from any invoice type.
class A4InvoiceData {
  final String invoiceTypeTitle;
  final String invoiceNo;
  final DateTime date;
  final String partyName;
  final String partyRole; // 'العميل' | 'المورد' | 'المعتمد'
  final String partyPhone;
  final String currency;
  final String paymentStatus;
  final List<A4InvoiceLineItem> items;
  final double subtotal;
  final double servicesTotal;
  final double shippingFee;
  final double discount;
  final double grandTotal;
  final double paidAmount;
  final double remainingBalance;
  final String notes;
  final bool isGoodsDelivered;
  final bool hasFulfillmentSection;
  final String fulfillmentTitle;
  final bool isWorkshopOrder;

  const A4InvoiceData({
    required this.invoiceTypeTitle,
    required this.invoiceNo,
    required this.date,
    required this.partyName,
    this.partyRole = 'العميل',
    this.partyPhone = '—',
    required this.currency,
    required this.paymentStatus,
    required this.items,
    required this.subtotal,
    this.servicesTotal = 0.0,
    this.shippingFee = 0.0,
    this.discount = 0.0,
    required this.grandTotal,
    required this.paidAmount,
    required this.remainingBalance,
    this.notes = '',
    this.isGoodsDelivered = true,
    this.hasFulfillmentSection = false,
    this.fulfillmentTitle = 'أمر تشغيل وتجهيز المصنع / المعمل',
    this.isWorkshopOrder = false,
  });

  bool get hasDimensions => isWorkshopOrder || items.any((it) => it.hasDimensions);

  /// Factory adapter for Factory Invoices (Supplier Purchase & Approved Clients POS).
  factory A4InvoiceData.fromFactoryInvoice(FactoryInvoiceModel inv) {
    final isPurchase = inv.invoiceType == 'شراء_مورد';
    final isCash = inv.isCashInvoice;
    final typeTitle = isPurchase
        ? 'فاتورة مشتريات من مورد (بلوكات وأمتار)'
        : (isCash
            ? 'فاتورة مبيعات معتمدين (نقدي) — مستودع المصنع'
            : 'فاتورة مبيعات معتمدين (آجل) — مستودع المصنع');
    final role = isPurchase ? 'المورد' : 'المعتمد / العميل';

    final items = <A4InvoiceLineItem>[];
    for (int i = 0; i < inv.items.length; i++) {
      final it = inv.items[i];
      final dim = (it.lengthCm > 0 && it.widthCm > 0)
          ? '${it.lengthCm.fmt} × ${it.widthCm.fmt} سم'
          : '—';
      final srvText = it.services.isNotEmpty
          ? it.services.map((s) {
              final note = s.notes.trim();
              if (note.isNotEmpty) {
                return '${s.serviceName}: ${s.price.fmt}\$ ($note)';
              }
              return '${s.serviceName}: ${s.price.fmt}\$';
            }).join('\n')
          : '—';
      final qtyLabel = isPurchase
          ? (it.isMeterItem
              ? '${it.quantity.fmt} ${it.meterUnit.isNotEmpty ? it.meterUnit : "متر"}'
              : '${it.quantity.fmt} طن')
          : '${it.calculatedArea.fmt} ${it.heightCm > 5 ? "م³" : "م²"}\n(${it.quantity.fmt} قطعة)';
      final specs = it.isMeterItem
          ? '${it.grade}${it.thicknessCm > 0 ? " • ${it.thicknessCm.fmt} سم" : ""} ${it.isGranite ? "(جرانيت)" : "(رخام)"}'
          : '${it.grade} ${it.isGranite ? "(جرانيت)" : "(رخام)"}';

      items.add(A4InvoiceLineItem(
        index: i + 1,
        description: it.typeName.isNotEmpty ? it.typeName : it.description,
        gradeAndSpecs: specs,
        dimensionsText: dim,
        lengthCm: it.lengthCm > 0 ? it.lengthCm : null,
        widthCm: it.widthCm > 0 ? it.widthCm : null,
        heightCm: it.heightCm > 0 ? it.heightCm : null,
        quantityText: qtyLabel,
        unitPrice: it.unitPrice,
        servicesText: srvText,
        lineTotal: it.grandTotal > 0 ? it.grandTotal : (it.quantity * it.unitPrice),
      ));
    }

    return A4InvoiceData(
      invoiceTypeTitle: typeTitle,
      invoiceNo: inv.invoiceNo,
      date: inv.date,
      partyName: inv.partyName,
      partyRole: role,
      partyPhone: '—',
      currency: inv.currency,
      paymentStatus: inv.isDue ? 'مستحق الدفع' : 'مدفوعة بالكامل',
      items: items,
      subtotal: inv.subtotal,
      servicesTotal: inv.itemsServicesTotal,
      shippingFee: isPurchase ? 0.0 : inv.shippingFee,
      discount: inv.discountAmount,
      grandTotal: inv.grandTotal,
      paidAmount: inv.advancePayment,
      remainingBalance: inv.remainingBalance,
      notes: isPurchase
          ? (inv.isGoodsDelivered
              ? 'شحنة واصلة للمصنع'
              : (inv.shippingFee > 0
                  ? 'تكلفة الشحن (${inv.shippingFee.fmt} ${inv.currencySymbol}) أُضيفت للتكلفة الرأسمالية للمواد وسُجلت بالمصروفات ولا تُحمّل على المورد.'
                  : 'شحنة غير واصلة'))
          : (inv.isGoodsDelivered
              ? 'شحن واصل للعنوان المطلوب'
              : 'الاستلام من أرض المستودع (الزبون يستلم النقل)'),
      isGoodsDelivered: inv.isGoodsDelivered,
      hasFulfillmentSection: !isPurchase,
      fulfillmentTitle: isCash
          ? 'أمر تشغيل وتجهيز طلبية المعتمدين (نقدي) — قسم المصنع'
          : 'أمر تشغيل وتجهيز طلبية المعتمدين (آجل) — قسم المصنع',
    );
  }

  /// Factory adapter for Factory Custom Orders (أمر تشغيل وتجهيز ورشة المصنع).
  factory A4InvoiceData.fromFactoryOrder(FactoryOrderModel ord) {
    final items = <A4InvoiceLineItem>[];
    for (int i = 0; i < ord.items.length; i++) {
      final it = ord.items[i];
      final dim = (it.lengthCm > 0 && it.widthCm > 0)
          ? '${it.lengthCm.fmt} × ${it.widthCm.fmt}${it.heightCm > 5 ? " × ${it.heightCm.fmt}" : ""} سم'
          : '—';
      final srvText = it.services.isNotEmpty
          ? it.services.map((s) {
              final note = s.notes.trim();
              if (note.isNotEmpty) {
                return '${s.serviceName}: ${s.price.fmt}\$ ($note)';
              }
              return '${s.serviceName}: ${s.price.fmt}\$';
            }).join('\n')
          : '—';
      final qtyLabel =
          '${it.calculatedArea.fmt} ${it.heightCm > 5 ? "م³" : "م²"}\n(${it.quantity.fmt} قطعة)';
      final specs =
          '${it.grade} ${it.isGranite ? "(جرانيت)" : "(رخام)"}${it.thicknessCm > 0 ? " • ${it.thicknessCm.fmt} سم" : ""}';

      items.add(A4InvoiceLineItem(
        index: i + 1,
        description: it.typeName.isNotEmpty ? it.typeName : it.description,
        gradeAndSpecs: specs,
        dimensionsText: dim,
        lengthCm: it.lengthCm > 0 ? it.lengthCm : null,
        widthCm: it.widthCm > 0 ? it.widthCm : null,
        heightCm: it.heightCm > 0 ? it.heightCm : null,
        quantityText: qtyLabel,
        unitPrice: it.unitPrice,
        servicesText: srvText,
        lineTotal: it.grandTotal > 0 ? it.grandTotal : (it.quantity * it.unitPrice),
      ));
    }

    return A4InvoiceData(
      invoiceTypeTitle: 'أمر تشغيل ورشة وتجهيز طلبية مصنع (Factory Workshop Order)',
      invoiceNo: ord.orderNo,
      date: ord.date,
      partyName: ord.clientName,
      partyRole: 'الزبون / المعتمد',
      partyPhone: ord.clientPhone.isNotEmpty ? ord.clientPhone : '—',
      currency: ord.currency,
      paymentStatus: 'عربون محجوز: ${ord.depositAmount.fmt} ${ord.currencySymbol} (صندوق الطلبيات المعزول)',
      items: items,
      subtotal: ord.subtotal,
      servicesTotal: ord.itemsServicesTotal,
      shippingFee: ord.shippingFee,
      discount: ord.discountAmount,
      grandTotal: ord.grandTotal,
      paidAmount: ord.depositAmount,
      remainingBalance: ord.remainingBalance,
      notes: ord.isGoodsDelivered
          ? 'التوصيل: نوصّل نحن (${ord.shippingFee.fmt} ${ord.currencySymbol})'
          : 'التوصيل: الزبون يستلم النقل من أرض المصنع',
      isGoodsDelivered: ord.isGoodsDelivered,
      hasFulfillmentSection: true,
      fulfillmentTitle: 'أمر تشغيل ورشة المصنع وتجهيز وتفصيل الطلبية',
    );
  }

  /// Factory adapter for Workshop Custom Orders (أمر تشغيل وتنفيذ ورشة المعمل).
  factory A4InvoiceData.fromWorkshopOrder(WorkshopOrderModel ord) {
    final items = <A4InvoiceLineItem>[];

    if (ord.items.isNotEmpty) {
      for (int i = 0; i < ord.items.length; i++) {
        final it = ord.items[i];

        // Determine numerical dimensions
        double? l = it.lengthCm > 0 ? it.lengthCm : null;
        double? w = it.widthCm > 0 ? it.widthCm : null;
        if ((l == null || w == null) && it.description.isNotEmpty) {
          final m = RegExp(r'(\d+(?:\.\d+)?)\s*[*×xX]\s*(\d+(?:\.\d+)?)').firstMatch(it.description);
          if (m != null) {
            l ??= double.tryParse(m.group(1)!);
            w ??= double.tryParse(m.group(2)!);
          }
        }

        final count = it.effectiveCount;
        final hasDim = (l != null && l > 0 && w != null && w > 0);
        final dim = hasDim
            ? '${l.fmt} × ${w.fmt}${it.heightCm > 0 ? " × ${it.heightCm.fmt}" : ""} سم'
            : (it.description.isNotEmpty ? it.description : '${it.quantity.fmt} ${it.unitCategory}');

        final srvText = it.services.isNotEmpty
            ? it.services.map((s) {
                final note = s.notes.trim();
                return note.isNotEmpty
                    ? '${s.serviceName} ($note)'
                    : s.serviceName;
              }).join('\n')
            : '—';

        // Formatted Quantity (Count) field:
        // For workshop execution, craftsmen clearly see the count (العدد / القطع)
        // along with the total quantity/area (م² or م³).
        final String qtyLabel;
        if (hasDim && it.quantity > 0 && it.unitCategory == 'متر مربع') {
          qtyLabel = '${count.fmt} قطعة\n(${it.quantity.fmt} متر مربع)';
        } else if (hasDim && it.quantity > 0 && it.unitCategory == 'متر مكعب') {
          qtyLabel = '${count.fmt} قطعة\n(${it.quantity.fmt} متر مكعب)';
        } else if (it.unitCategory == 'قطعة') {
          qtyLabel = '${it.quantity.fmt} قطعة';
        } else {
          qtyLabel = count > 0 && count != it.quantity
              ? '${count.fmt} قطعة\n(${it.quantity.fmt} ${it.unitCategory})'
              : '${it.quantity.fmt} ${it.unitCategory}';
        }

        final specs = '${it.sourceType}${it.isGranite ? " • جرانيت" : " • رخام"}';

        items.add(A4InvoiceLineItem(
          index: i + 1,
          description: it.description.isNotEmpty ? it.description : 'بند طلبية معمل',
          gradeAndSpecs: specs,
          dimensionsText: dim,
          lengthCm: l,
          widthCm: w,
          heightCm: it.heightCm > 0 ? it.heightCm : null,
          count: count > 0 ? count : null,
          quantityText: qtyLabel,
          unitPrice: it.unitPrice > 0 ? it.unitPrice : it.agreedPrice,
          servicesText: srvText,
          lineTotal: it.agreedPrice + it.servicesTotal,
        ));
      }
    } else {
      // If ord.items is empty (custom order), extract dimensions from customDimensionsText if present
      final dimText = ord.customDimensionsText.isNotEmpty ? ord.customDimensionsText : 'حسب المخطط';
      final m = RegExp(r'(\d+(?:\.\d+)?)\s*[*×xX]\s*(\d+(?:\.\d+)?)').firstMatch(dimText);
      final lCm = m != null ? double.tryParse(m.group(1)!) : null;
      final wCm = m != null ? double.tryParse(m.group(2)!) : null;

      items.add(A4InvoiceLineItem(
        index: 1,
        description: ord.customDimensionsText.isNotEmpty
            ? ord.customDimensionsText
            : 'طلبية معمل خاصة',
        gradeAndSpecs: 'تفصيل وتجهيز حسب الطلب والمخطط',
        dimensionsText: dimText,
        lengthCm: lCm,
        widthCm: wCm,
        count: 1.0,
        quantityText: '1 طلبية (العدد: 1)',
        unitPrice: ord.agreedPrice,
        servicesText: 'تنفيذ وتجهيز ورشة المعمل',
        lineTotal: ord.agreedPrice,
      ));
    }

    final subtotal = ord.items.isNotEmpty
        ? ord.items.fold(0.0, (s, i) => s + i.agreedPrice)
        : ord.agreedPrice;
    final srvTotal = ord.items.fold(0.0, (s, i) => s + i.servicesTotal);

    return A4InvoiceData(
      invoiceTypeTitle: 'أمر تشغيل وتنفيذ ورشة المعمل (Workshop Fulfillment Order)',
      invoiceNo: ord.orderNo,
      date: ord.date,
      partyName: ord.clientName,
      partyRole: 'الزبون / العميل',
      partyPhone: ord.clientPhone.isNotEmpty ? ord.clientPhone : '—',
      currency: ord.currency,
      paymentStatus: 'عربون محجوز: ${ord.depositAmount.fmt} ${ord.currencySymbol} (صندوق الطلبيات المعزول)',
      items: items,
      subtotal: subtotal,
      servicesTotal: srvTotal,
      shippingFee: 0.0,
      discount: 0.0,
      grandTotal: ord.agreedPrice,
      paidAmount: ord.depositAmount,
      remainingBalance: (ord.agreedPrice - ord.depositAmount).clamp(0.0, double.infinity),
      notes: ord.photoPath.isNotEmpty
          ? 'مرفق صورة / مخطط تنفيذي خاص بالطلبية في الورشة'
          : 'أمر تشغيل وتفصيل ورشة المعمل',
      isGoodsDelivered: true,
      hasFulfillmentSection: true,
      fulfillmentTitle: 'أمر تجهيز وتفصيل وتصنيع ورشة المعمل',
      isWorkshopOrder: true,
    );
  }

  /// Factory adapter for Workshop Workspace Invoices, Factory Invoices, and Project Invoices.
  factory A4InvoiceData.fromWorkshopInvoice(
    WorkshopInvoiceModel inv, {
    String? projectName,
  }) {
    final items = <A4InvoiceLineItem>[];

    if (inv.items.isNotEmpty) {
      int idx = 1;
      for (final item in inv.items) {
        final dim = (item.lengthCm > 0 && item.widthCm > 0)
            ? '${item.lengthCm.fmt} × ${item.widthCm.fmt} سم'
            : '${item.quantity.fmt} ${item.unitCategory}';
        final srvText = item.services.isNotEmpty
            ? item.services
                .map((s) {
                  final note = s.notes.trim();
                  if (note.isNotEmpty) {
                    return '${s.serviceName}: ${s.price.fmt}\$ ($note)';
                  }
                  return '${s.serviceName} (${s.price.fmt}\$)';
                })
                .join('\n')
            : '—';
        items.add(A4InvoiceLineItem(
          index: idx++,
          description: item.description.isNotEmpty
              ? item.description
              : 'صنف ورشة المعمل',
          gradeAndSpecs: item.sourceType,
          dimensionsText: dim,
          lengthCm: item.lengthCm > 0 ? item.lengthCm : null,
          widthCm: item.widthCm > 0 ? item.widthCm : null,
          heightCm: item.heightCm > 0 ? item.heightCm : null,
          quantityText:
              '${item.quantity.fmt} ${item.unitCategory == "متر مكعب" ? "م³" : item.unitCategory == "متر مربع" ? "م²" : "وحدة"}',
          unitPrice: item.unitPrice > 0 ? item.unitPrice : item.agreedPrice,
          servicesText: srvText,
          lineTotal: item.agreedPrice + item.servicesTotal,
        ));
      }
    } else {
      final srvText = inv.services.isNotEmpty
          ? inv.services.map((s) {
              final note = s.notes.trim();
              if (note.isNotEmpty) {
                return '${s.serviceName}: ${s.price.fmt}\$ ($note)';
              }
              return '${s.serviceName} (${s.price.fmt}\$)';
            }).join('\n')
          : '—';

      items.add(A4InvoiceLineItem(
        index: 1,
        description: inv.itemDescription.isNotEmpty
            ? inv.itemDescription
            : 'تفصيل رخام وجرانيت ورشة المعمل',
        gradeAndSpecs: inv.sourceType,
        dimensionsText: '${inv.sourceQuantity.fmt} ${inv.sourceUnitCategory}',
        quantityText: (inv.sourceType == 'تفصيل بسيط' || inv.sourceType == 'تفصيل معقد')
            ? '${inv.sourceQuantity.fmt} ${inv.sourceUnitCategory == "متر مكعب" ? "م³" : "م²"}'
            : '1 مقطوعية',
        unitPrice: inv.agreedPrice,
        servicesText: srvText,
        lineTotal: inv.agreedPrice,
      ));
    }

    final isProject = inv.projectId.isNotEmpty || (projectName != null && projectName.isNotEmpty);
    final isCash = inv.isCashInvoice;
    final typeTitle = isProject
        ? (isCash
            ? 'فاتورة مشروع (سداد نقدي) — إدارة المصنع'
            : 'فاتورة مشروع (آجل ومستخلص) — إدارة المصنع')
        : (isCash
            ? 'فاتورة مبيعات نقدية — المصنع والمعمل'
            : 'فاتورة مبيعات وتوريد — المصنع والمعمل');

    return A4InvoiceData(
      invoiceTypeTitle: typeTitle,
      invoiceNo: inv.invoiceNo,
      date: inv.date,
      partyName: inv.clientName,
      partyRole: isProject ? 'المشروع / الجهة' : 'العميل / الزبون',
      partyPhone: '—',
      currency: inv.currency,
      paymentStatus: inv.remainingBalance > 0.01 ? 'مستحق الدفع' : 'مدفوعة بالكامل',
      items: items,
      subtotal: inv.itemsSubtotal,
      servicesTotal: inv.servicesTotal,
      shippingFee: 0.0,
      discount: inv.salesDiscount,
      grandTotal: inv.grandTotal,
      paidAmount: inv.cashPaidNow + inv.depositDeducted,
      remainingBalance: inv.remainingBalance,
      notes: 'المصدر: ${inv.sourceType} • ${inv.isGranite ? "جرانيت طبيعي" : "رخام طبيعي"}',
      isGoodsDelivered: true,
      hasFulfillmentSection: true,
      fulfillmentTitle: isProject
          ? 'أمر تشغيل وتجهيز بنود المشروع — قسم المصنع والورشة'
          : (isCash
              ? 'أمر تشغيل وتجهيز طلبية المصنع (نقدي) — الورشة'
              : 'أمر تشغيل وتجهيز طلبية المصنع (آجل) — الورشة'),
    );
  }

  /// Factory adapter for Return Invoices.
  factory A4InvoiceData.fromReturnInvoice(ReturnInvoiceModel inv) {
    final items = <A4InvoiceLineItem>[
      A4InvoiceLineItem(
        index: 1,
        description: inv.itemDescription,
        gradeAndSpecs: inv.returnType,
        dimensionsText: 'مرتجع نظامي',
        quantityText: '${inv.quantity.fmt} وحدة',
        unitPrice: inv.quantity > 0 ? (inv.refundAmount / inv.quantity) : inv.refundAmount,
        servicesText: inv.paymentAction,
        lineTotal: inv.refundAmount,
      ),
    ];

    return A4InvoiceData(
      invoiceTypeTitle: 'إشعار فاتورة مرتجع (${inv.returnType})',
      invoiceNo: inv.returnNo,
      date: inv.date,
      partyName: inv.partyName,
      partyRole: 'الجهة / الطرف',
      partyPhone: '—',
      currency: inv.currency,
      paymentStatus: 'تمت التسوية (${inv.paymentAction})',
      items: items,
      subtotal: inv.refundAmount,
      servicesTotal: 0.0,
      shippingFee: 0.0,
      discount: 0.0,
      grandTotal: inv.refundAmount,
      paidAmount: inv.refundAmount,
      remainingBalance: 0.0,
      notes: 'معالجة مالية: ${inv.paymentAction}',
      isGoodsDelivered: true,
      hasFulfillmentSection: false,
      fulfillmentTitle: 'أمر تشغيل وتجهيز المصنع',
    );
  }
}

/// A4 Paper Invoice Print Preview Modal Dialog.
class A4InvoicePrintDialog extends StatefulWidget {
  final A4InvoiceData invoiceData;

  const A4InvoicePrintDialog({
    super.key,
    required this.invoiceData,
  });

  /// Convenient helper to show the dialog
  static Future<void> show(
    BuildContext context, {
    required A4InvoiceData invoiceData,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => A4InvoicePrintDialog(invoiceData: invoiceData),
    );
  }

  @override
  State<A4InvoicePrintDialog> createState() => _A4InvoicePrintDialogState();
}

class _A4InvoicePrintDialogState extends State<A4InvoicePrintDialog> {
  final List<GlobalKey> _pageKeys = [];
  bool _isPrinting = false;
  late bool _includeFulfillment;
  late bool _forceTwoPages;
  bool _isBlackAndWhite = false;

  static const ColorFilter _blackAndWhiteFilter = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ]);

  Widget _wrapWithPrintMode(Widget child) {
    if (!_isBlackAndWhite) return child;
    return ColorFiltered(
      colorFilter: _blackAndWhiteFilter,
      child: child,
    );
  }

  @override
  void initState() {
    super.initState();
    _includeFulfillment = widget.invoiceData.hasFulfillmentSection;
    // By default, if there are more than 2 items, separate into 2 full pages
    _forceTwoPages = widget.invoiceData.items.length > 2;
    _syncPageKeys();
  }

  void _syncPageKeys() {
    _pageKeys.clear();
    if (!_includeFulfillment) {
      _pageKeys.add(GlobalKey());
    } else {
      if (_forceTwoPages || widget.invoiceData.items.length > 2) {
        _pageKeys.add(GlobalKey()); // Page 1: Financial invoice
        _pageKeys.add(GlobalKey()); // Page 2: Factory fulfillment sheet
      } else {
        _pageKeys.add(GlobalKey()); // Merged single A4 sheet
      }
    }
  }

  Future<void> _handleDirectPrint() async {
    setState(() => _isPrinting = true);
    try {
      final pdfDoc = pw.Document();

      for (int i = 0; i < _pageKeys.length; i++) {
        final key = _pageKeys[i];
        final boundary = key.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary == null) continue;

        final ui.Image image = await boundary.toImage(pixelRatio: 2.5);
        final ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
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
        name: 'فاتورة_${widget.invoiceData.invoiceNo}${_isBlackAndWhite ? "_BW" : ""}.pdf',
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
    final inv = widget.invoiceData;
    final isTwoPagesMode = _includeFulfillment && (_forceTwoPages || inv.items.length > 2);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      backgroundColor: Colors.transparent,
      child: Container(
        width: (MediaQuery.of(context).size.width * 0.95).clamp(960.0, 1160.0),
        height: MediaQuery.of(context).size.height * 0.95,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFCBD5E1)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 28,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top Toolbar (Light modern theme with responsive non-overflowing controls)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  // Title and metadata (Wrapped in Expanded to completely prevent any overflow)
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: Color(0xFF2563EB),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: const Text(
                                      'معاينة طباعة الفاتورة وقسيمة التشغيل',
                                      style: TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Text(
                                      isTwoPagesMode ? 'صفحتان A4' : 'صفحة واحدة A4',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'رقم الفاتورة: ${inv.invoiceNo} • ${inv.partyName}',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Middle / Right controls: Toggles & Print (Compact, responsive horizontal scroll to prevent overflow)
                  Flexible(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Toggle to include / exclude factory fulfillment section
                          if (inv.hasFulfillmentSection) ...[
                            FilterChip(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              avatar: Icon(
                                _includeFulfillment ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                size: 14,
                                color: _includeFulfillment ? const Color(0xFF0D9488) : const Color(0xFF64748B),
                              ),
                              label: const Text(
                                'قسيمة المصنع',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              selected: _includeFulfillment,
                              selectedColor: const Color(0xFFCCFBF1),
                              checkmarkColor: Colors.transparent,
                              onSelected: (val) {
                                setState(() {
                                  _includeFulfillment = val;
                                  _syncPageKeys();
                                });
                              },
                            ),
                            const SizedBox(width: 6),
                          ],

                          // Page splitting toggle if items can fit on 1 page
                          if (_includeFulfillment && inv.items.length <= 2) ...[
                            FilterChip(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              avatar: Icon(
                                _forceTwoPages ? Icons.file_copy_outlined : Icons.description_outlined,
                                size: 14,
                                color: const Color(0xFF2563EB),
                              ),
                              label: Text(
                                _forceTwoPages ? 'صفحتان' : 'صفحة واحدة',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              selected: _forceTwoPages,
                              selectedColor: const Color(0xFFDBEAFE),
                              onSelected: (val) {
                                setState(() {
                                  _forceTwoPages = val;
                                  _syncPageKeys();
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                          ],

                          // Color / B&W Version Toggle
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            padding: const EdgeInsets.all(2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () => setState(() => _isBlackAndWhite = false),
                                  borderRadius: BorderRadius.circular(6),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: !_isBlackAndWhite ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: !_isBlackAndWhite
                                          ? const [
                                              BoxShadow(
                                                color: Color(0x14000000),
                                                blurRadius: 4,
                                                offset: Offset(0, 1),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.palette_rounded,
                                          size: 13,
                                          color: !_isBlackAndWhite ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'ملونة',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: !_isBlackAndWhite ? FontWeight.w900 : FontWeight.w600,
                                            color: !_isBlackAndWhite ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => setState(() => _isBlackAndWhite = true),
                                  borderRadius: BorderRadius.circular(6),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: _isBlackAndWhite ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: _isBlackAndWhite
                                          ? const [
                                              BoxShadow(
                                                color: Color(0x14000000),
                                                blurRadius: 4,
                                                offset: Offset(0, 1),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.filter_b_and_w_rounded,
                                          size: 13,
                                          color: _isBlackAndWhite ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'أبيض وأسود',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: _isBlackAndWhite ? FontWeight.w900 : FontWeight.w600,
                                            color: _isBlackAndWhite ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Print button
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isBlackAndWhite ? const Color(0xFF0F172A) : const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              elevation: 1,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                                    _isBlackAndWhite ? Icons.print_outlined : Icons.print_rounded,
                                    size: 16,
                                  ),
                            label: Text(
                              _isPrinting
                                  ? 'طباعة...'
                                  : _isBlackAndWhite
                                      ? 'طباعة (${_pageKeys.length})'
                                      : 'طباعة (${_pageKeys.length})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                            tooltip: 'إغلاق',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Preview Canvas
            Expanded(
              child: Container(
                color: const Color(0xFFE2E8F0),
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: _buildPreviewPages(context, centerInfo, inv),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds preview pages based on pagination mode
  Widget _buildPreviewPages(
    BuildContext context,
    CenterInfoModel centerInfo,
    A4InvoiceData inv,
  ) {
    if (!_includeFulfillment) {
      // Single Financial Invoice Page
      return RepaintBoundary(
        key: _pageKeys[0],
        child: _wrapWithPrintMode(
          _buildA4PaperInvoice(
            context,
            centerInfo,
            inv,
            pageNumber: 1,
            totalPages: 1,
          ),
        ),
      );
    }

    final isTwoPages = _forceTwoPages || inv.items.length > 2;
    if (!isTwoPages) {
      // Merged single A4 page with perforated cut-line
      return RepaintBoundary(
        key: _pageKeys[0],
        child: _wrapWithPrintMode(
          _buildA4PaperCombined(context, centerInfo, inv),
        ),
      );
    }

    // 2 Separate A4 Pages
    return Column(
      children: [
        // Page 1 Header Banner
        _buildPageIndicatorBanner(
          pageNumber: 1,
          totalPages: 2,
          title: 'القسم الأول: الفاتورة المالية المعتمدة (نسخة العميل / المحاسبة)',
          accentColor: _isBlackAndWhite ? const Color(0xFF334155) : const Color(0xFF2563EB),
        ),
        const SizedBox(height: 8),
        RepaintBoundary(
          key: _pageKeys[0],
          child: _wrapWithPrintMode(
            _buildA4PaperInvoice(
              context,
              centerInfo,
              inv,
              pageNumber: 1,
              totalPages: 2,
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Page 2 Header Banner
        _buildPageIndicatorBanner(
          pageNumber: 2,
          totalPages: 2,
          title: 'القسم الثاني: أمر تشغيل وتجهيز المصنع / المعمل (نسخة الورشة والمستودع)',
          accentColor: _isBlackAndWhite ? const Color(0xFF475569) : const Color(0xFF0D9488),
        ),
        const SizedBox(height: 8),
        RepaintBoundary(
          key: _pageKeys[1],
          child: _wrapWithPrintMode(
            _buildA4PaperFulfillment(
              context,
              centerInfo,
              inv,
              pageNumber: 2,
              totalPages: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageIndicatorBanner({
    required int pageNumber,
    required int totalPages,
    required String title,
    required Color accentColor,
  }) {
    return Container(
      width: 794,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          Text(
            'ورقة $pageNumber من $totalPages (A4)',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PAGE 1: OFFICIAL FINANCIAL INVOICE
  // ==========================================================================
  Widget _buildA4PaperInvoice(
    BuildContext context,
    CenterInfoModel centerInfo,
    A4InvoiceData inv, {
    int pageNumber = 1,
    int totalPages = 1,
  }) {
    return Container(
      width: 794,
      constraints: const BoxConstraints(minHeight: 1123),
      padding: const EdgeInsets.symmetric(horizontal: 38, vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2B000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Accent Ribbon
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF0D9488), Color(0xFFD97706)],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 1. INVOICE HEADER (Sawmill Details & Logo)
          _buildInvoiceHeader(centerInfo),
          const SizedBox(height: 14),

          // Official Invoice Title Banner & Metadata Box
          _buildInvoiceMetaSection(inv),
          const SizedBox(height: 16),

          // 2. INVOICE BODY: Structured Light Table
          _buildItemsTable(inv),
          const SizedBox(height: 16),

          // 3. FINANCIAL SUMMARY & TOTALS (Bottom Section - terms box removed)
          _buildFinancialSummary(inv),
          const SizedBox(height: 24),

          // Bottom System Footer Line (Signatures section removed as requested)
          _buildSystemFooterLine(pageNumber: pageNumber, totalPages: totalPages),
        ],
      ),
    );
  }

  // ==========================================================================
  // PAGE 2: FACTORY & WORKSHOP FULFILLMENT WORK ORDER
  // ==========================================================================
  Widget _buildA4PaperFulfillment(
    BuildContext context,
    CenterInfoModel centerInfo,
    A4InvoiceData inv, {
    int pageNumber = 2,
    int totalPages = 2,
  }) {
    return Container(
      width: 794,
      constraints: const BoxConstraints(minHeight: 1123),
      padding: const EdgeInsets.symmetric(horizontal: 38, vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2B000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Accent Ribbon (Teal/Emerald theme for production/factory)
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF0284C7), Color(0xFF10B981)],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 1. Factory Header
          _buildInvoiceHeader(centerInfo, subtitleOverride: 'قسم التشغيل والتجهيز الميداني بالمصنع'),
          const SizedBox(height: 14),

          // 2. Work Order Meta Banner
          _buildFulfillmentMetaBanner(inv),
          const SizedBox(height: 16),

          // 3. Fulfillment Items Table (Repeated line items for cutting and fulfillment)
          _buildFulfillmentItemsTable(inv),
          const SizedBox(height: 16),

          // Bottom System Footer Line (Signatures section removed as requested)
          _buildSystemFooterLine(
            pageNumber: pageNumber,
            totalPages: totalPages,
            customLabel: 'أمر تشغيل وتجهيز طلبية المصنع • مستند تنفيذي معتمد',
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // COMBINED SINGLE A4 SHEET (When items <= 2 and space fits)
  // ==========================================================================
  Widget _buildA4PaperCombined(
    BuildContext context,
    CenterInfoModel centerInfo,
    A4InvoiceData inv,
  ) {
    return Container(
      width: 794,
      constraints: const BoxConstraints(minHeight: 1123),
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2B000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Accent Ribbon
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF0D9488), Color(0xFFD97706)],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // SECTION 1: FINANCIAL INVOICE
          _buildInvoiceHeader(centerInfo, isCompact: true),
          const SizedBox(height: 10),
          _buildInvoiceMetaSection(inv, isCompact: true),
          const SizedBox(height: 10),
          _buildItemsTable(inv),
          const SizedBox(height: 10),
          _buildFinancialSummary(inv, isCompact: true),
          const SizedBox(height: 14),

          // PERFORATED CUT LINE (قسيمة قص أمر تشغيل المصنع)
          _buildPerforatedDivider(inv),
          const SizedBox(height: 14),

          // SECTION 2: FACTORY FULFILLMENT TABLE
          _buildFulfillmentMetaBanner(inv, isCompact: true),
          const SizedBox(height: 10),
          _buildFulfillmentItemsTable(inv),
          const SizedBox(height: 14),

          // Bottom System Footer Line
          _buildSystemFooterLine(
            pageNumber: 1,
            totalPages: 1,
            customLabel: 'فاتورة مالية وقسيمة تشغيل المصنع • مستند معتمد',
          ),
        ],
      ),
    );
  }

  /// Perforated cut divider separating invoice from factory work order
  Widget _buildPerforatedDivider(A4InvoiceData inv) {
    return Row(
      children: [
        const Icon(Icons.content_cut_rounded, size: 16, color: Color(0xFF64748B)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: const Text(
            'قص هنا: قسيمة أمر تشغيل وتجهيز طلبية المصنع / المعمل',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Color(0xFF334155),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const dashWidth = 5.0;
              const dashSpace = 4.0;
              final dashCount = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  dashCount,
                  (_) => const SizedBox(
                    width: dashWidth,
                    height: 1.5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: Color(0xFF94A3B8)),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // SHARED HEADER AND COMPONENTS
  // ==========================================================================
  Widget _buildInvoiceHeader(
    CenterInfoModel center, {
    bool isCompact = false,
    String? subtitleOverride,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Right Side: Sawmill / Center Details
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                center.centerName,
                style: TextStyle(
                  fontSize: isCompact ? 18 : 22,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitleOverride ?? (center.slogan.isNotEmpty ? center.slogan : 'لإدارة وتشغيل الرخام والجرانيت الطبيعي والصناعي'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD97706),
                ),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 14,
                runSpacing: 3,
                children: [
                  if (center.ownerName.isNotEmpty)
                    _buildHeaderBadge(Icons.person_outline_rounded, 'الإدارة: ${center.ownerName}'),
                  if (center.commercialRegNo.isNotEmpty)
                    _buildHeaderBadge(Icons.receipt_long_rounded, 'س.ت: ${center.commercialRegNo}'),
                  if (center.taxId.isNotEmpty)
                    _buildHeaderBadge(Icons.shield_outlined, 'الرقم الضريبي: ${center.taxId}'),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.phone_in_talk_rounded, size: 12, color: Color(0xFF2563EB)),
                  const SizedBox(width: 4),
                  Text(
                    'هاتف: ${center.phone1}${center.phone2.isNotEmpty ? " • ${center.phone2}" : ""}',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                  if (center.address.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF64748B)),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        center.address,
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // Left Side: Center Logo
        Expanded(
          flex: 2,
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: _buildCenterLogo(center, isCompact: isCompact),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderBadge(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: const Color(0xFF64748B)),
        const SizedBox(width: 3),
        Text(
          text,
          style: const TextStyle(fontSize: 10.5, color: Color(0xFF334155), fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildCenterLogo(CenterInfoModel center, {bool isCompact = false}) {
    final size = isCompact ? 68.0 : 84.0;
    final path = center.logoPath.trim();
    if (path.isNotEmpty) {
      if (path.startsWith('http://') || path.startsWith('https://')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            path,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _buildFallbackLogo(center, size: size),
          ),
        );
      }
      final file = File(path);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _buildFallbackLogo(center, size: size),
          ),
        );
      }
    }
    return _buildFallbackLogo(center, size: size);
  }

  Widget _buildFallbackLogo(CenterInfoModel center, {double size = 84.0}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.domain_rounded, size: 30, color: Color(0xFF0F172A)),
          SizedBox(height: 2),
          Text(
            'شعار المركز',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  /// Official Invoice Title Banner & Metadata Box (Light Modern Aesthetic)
  Widget _buildInvoiceMetaSection(A4InvoiceData inv, {bool isCompact = false}) {
    final isPaid = inv.paymentStatus.contains('مدفوعة') || inv.paymentStatus.contains('تم الدفع');
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        children: [
          // Banner Title Row (Light header, dark bold text)
          Container(
            padding: EdgeInsets.symmetric(
              vertical: isCompact ? 6 : 8,
              horizontal: 14,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          inv.invoiceTypeTitle,
                          style: TextStyle(
                            fontSize: isCompact ? 13 : 14,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isPaid ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                    ),
                  ),
                  child: Text(
                    inv.paymentStatus,
                    style: TextStyle(
                      color: isPaid ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Metadata Grid
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: isCompact ? 8 : 10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetaItem('رقم الفاتورة:', inv.invoiceNo, isPrimary: true),
                ),
                Expanded(
                  child: _buildMetaItem(
                    'تاريخ الإصدار:',
                    intl.DateFormat('yyyy-MM-dd • hh:mm a').format(inv.date),
                  ),
                ),
                Expanded(
                  child: _buildMetaItem('${inv.partyRole}:', inv.partyName, isPrimary: true),
                ),
                Expanded(
                  child: _buildMetaItem(
                    'العملة الأساسية:',
                    '${inv.currency} (${AppCurrency.symbol(inv.currency)})',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(String label, String value, {bool isPrimary = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF475569),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isPrimary ? FontWeight.w900 : FontWeight.bold,
            color: isPrimary ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // INVOICE TABLE (LIGHT HEADER, HIGH CONTRAST)
  // ==========================================================================
  Widget _buildItemsTable(A4InvoiceData inv) {
    final hasDim = inv.hasDimensions;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Table(
          columnWidths: hasDim
              ? const {
                  0: FixedColumnWidth(28), // #
                  1: FlexColumnWidth(2.4), // Description
                  2: FlexColumnWidth(1.5), // Specs
                  3: FlexColumnWidth(1.1), // Length
                  4: FlexColumnWidth(1.1), // Width
                  5: FlexColumnWidth(1.6), // Qty / Meters
                  6: FlexColumnWidth(1.4), // Unit Price
                  7: FlexColumnWidth(2.5), // Services & formula
                  8: FlexColumnWidth(1.6), // Total
                }
              : const {
                  0: FixedColumnWidth(30), // #
                  1: FlexColumnWidth(2.6), // Description
                  2: FlexColumnWidth(1.6), // Specs
                  3: FlexColumnWidth(1.7), // Dimensions
                  4: FlexColumnWidth(1.8), // Qty / Meters
                  5: FlexColumnWidth(1.5), // Unit Price
                  6: FlexColumnWidth(2.8), // Services & formula
                  7: FlexColumnWidth(1.7), // Total
                },
          border: TableBorder.all(
            color: const Color(0xFFCBD5E1),
            width: 1,
          ),
          children: [
            // Table Header Row: Light slate background, crisp dark text
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
              children: hasDim
                  ? [
                      const _TableHeaderCell('#'),
                      const _TableHeaderCell('البيان والمادة'),
                      const _TableHeaderCell('المواصفات والنوع'),
                      const _TableHeaderCell('الطول (سم)'),
                      const _TableHeaderCell('العرض (سم)'),
                      _TableHeaderCell(inv.isWorkshopOrder ? 'الكمية (العدد)' : 'الكمية / الأمتار (م²)'),
                      const _TableHeaderCell('سعر المتر / الوحدة'),
                      const _TableHeaderCell('الخدمات الملحقة وحسابها'),
                      const _TableHeaderCell('الإجمالي'),
                    ]
                  : [
                      const _TableHeaderCell('#'),
                      const _TableHeaderCell('البيان والمادة'),
                      const _TableHeaderCell('المواصفات والنوع'),
                      const _TableHeaderCell('الأبعاد (سم)'),
                      _TableHeaderCell(inv.isWorkshopOrder ? 'الكمية (العدد)' : 'الكمية / الأمتار (م²)'),
                      const _TableHeaderCell('سعر المتر / الوحدة'),
                      const _TableHeaderCell('الخدمات الملحقة وحسابها'),
                      const _TableHeaderCell('الإجمالي'),
                    ],
            ),

            // Table Data Rows: Alternating white and soft tint
            ...inv.items.map((it) {
              final isEven = it.index % 2 == 0;
              return TableRow(
                decoration: BoxDecoration(
                  color: isEven ? const Color(0xFFF8FAFC) : Colors.white,
                ),
                children: hasDim
                    ? [
                        _TableCell(it.index.toString(), isCenter: true),
                        _TableCell(it.description, isBold: true),
                        _TableCell(it.gradeAndSpecs),
                        _TableCell(it.lengthDisplay, isCenter: true),
                        _TableCell(it.widthDisplay, isCenter: true),
                        _TableCell(it.quantityText, isCenter: true, isBold: true),
                        _TableCell('${it.unitPrice.fmt} ${AppCurrency.symbol(inv.currency)}', isCenter: true),
                        _TableCell(it.servicesText, isSmall: true),
                        _TableCell(
                          '${it.lineTotal.fmt} ${AppCurrency.symbol(inv.currency)}',
                          isCenter: true,
                          isBold: true,
                          color: const Color(0xFF0F172A),
                        ),
                      ]
                    : [
                        _TableCell(it.index.toString(), isCenter: true),
                        _TableCell(it.description, isBold: true),
                        _TableCell(it.gradeAndSpecs),
                        _TableCell(it.dimensionsText, isCenter: true),
                        _TableCell(it.quantityText, isCenter: true, isBold: true),
                        _TableCell('${it.unitPrice.fmt} ${AppCurrency.symbol(inv.currency)}', isCenter: true),
                        _TableCell(it.servicesText, isSmall: true),
                        _TableCell(
                          '${it.lineTotal.fmt} ${AppCurrency.symbol(inv.currency)}',
                          isCenter: true,
                          isBold: true,
                          color: const Color(0xFF0F172A),
                        ),
                      ],
              );
            }),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // FINANCIAL SUMMARY (TERMS/NOTES BOX REMOVED AS REQUESTED)
  // ==========================================================================
  Widget _buildFinancialSummary(A4InvoiceData inv, {bool isCompact = false}) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Container(
        width: 380,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
        ),
        child: Column(
          children: [
            _buildTotalRow('المجموع الفرعي للأصناف:', '${inv.subtotal.fmt} ${AppCurrency.symbol(inv.currency)}'),
            if (inv.servicesTotal > 0)
              _buildTotalRow('إجمالي الخدمات الإضافية:', '+ ${inv.servicesTotal.fmt} ${AppCurrency.symbol(inv.currency)}'),
            if (inv.shippingFee > 0)
              _buildTotalRow('أجور النقل والتوصيل:', '+ ${inv.shippingFee.fmt} ${AppCurrency.symbol(inv.currency)}'),
            if (inv.discount > 0)
              _buildTotalRow(
                'الخصم المسموح به:',
                '- ${inv.discount.fmt} ${AppCurrency.symbol(inv.currency)}',
                color: const Color(0xFF16A34A),
              ),

            // Grand Total: Soft light amber highlight with bold dark text
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3C7),
                border: Border.symmetric(
                  horizontal: BorderSide(color: Color(0xFFFDE68A), width: 1.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'الإجمالي النهائي الصافي:',
                      style: TextStyle(
                        color: Color(0xFF78350F),
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  Text(
                    '${inv.grandTotal.fmt} ${AppCurrency.symbol(inv.currency)}',
                    style: const TextStyle(
                      color: Color(0xFF92400E),
                      fontWeight: FontWeight.w900,
                      fontSize: 15.5,
                    ),
                  ),
                ],
              ),
            ),

            _buildTotalRow(
              'المدفوع / العربون المقبوض:',
              '${inv.paidAmount.fmt} ${AppCurrency.symbol(inv.currency)}',
              isBold: true,
            ),
            _buildTotalRow(
              inv.partyRole == 'المورد'
                  ? 'المتبقي لصالح المورد:'
                  : 'المتبقي بذمة العميل:',
              '${inv.remainingBalance.fmt} ${AppCurrency.symbol(inv.currency)}',
              isBold: true,
              color: inv.remainingBalance > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: const Color(0xFF475569),
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
              color: color ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // FACTORY FULFILLMENT COMPONENTS (WORK ORDER FOR WORKSHOP/SAWMILL)
  // ==========================================================================
  Widget _buildFulfillmentMetaBanner(A4InvoiceData inv, {bool isCompact = false}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA), // Light mint/teal
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF99F6E4)),
      ),
      child: Column(
        children: [
          // Work Order Header Bar
          Container(
            padding: EdgeInsets.symmetric(
              vertical: isCompact ? 6 : 8,
              horizontal: 14,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFCCFBF1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
              border: Border(bottom: BorderSide(color: Color(0xFF99F6E4))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.handyman_rounded, size: 16, color: Color(0xFF0F766E)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          inv.fulfillmentTitle,
                          style: TextStyle(
                            fontSize: isCompact ? 13 : 14,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F766E),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF0D9488)),
                  ),
                  child: Text(
                    'أمر تشغيل #WO-${inv.invoiceNo}',
                    style: const TextStyle(
                      color: Color(0xFF0F766E),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Work Order Info Grid
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: isCompact ? 8 : 10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetaItem('رقم الفاتورة المرجعية:', inv.invoiceNo, isPrimary: true),
                ),
                Expanded(
                  child: _buildMetaItem('الجهة / العميل:', inv.partyName, isPrimary: true),
                ),
                Expanded(
                  child: _buildMetaItem(
                    'تاريخ الإرسال للورشة:',
                    intl.DateFormat('yyyy-MM-dd').format(inv.date),
                  ),
                ),
                Expanded(
                  child: _buildMetaItem(
                    'طريقة التسليم:',
                    inv.isGoodsDelivered ? 'شحن واصل للعنوان' : 'استلام من أرض المصنع',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Factory Fulfillment Table (Repeats line items with physical cutting & execution checklist)
  Widget _buildFulfillmentItemsTable(A4InvoiceData inv) {
    final hasDim = inv.hasDimensions;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF99F6E4), width: 1.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Table(
          columnWidths: hasDim
              ? const {
                  0: FixedColumnWidth(28), // #
                  1: FlexColumnWidth(2.4), // Description
                  2: FlexColumnWidth(1.5), // Specs / Grade
                  3: FlexColumnWidth(1.1), // Length
                  4: FlexColumnWidth(1.1), // Width
                  5: FlexColumnWidth(1.6), // Qty / Area
                  6: FlexColumnWidth(2.4), // Operations / Services formula
                  7: FlexColumnWidth(1.8), // Workshop Checklist
                  8: FlexColumnWidth(1.4), // Cutting Notes
                }
              : const {
                  0: FixedColumnWidth(30), // #
                  1: FlexColumnWidth(2.6), // Description
                  2: FlexColumnWidth(1.6), // Specs / Grade
                  3: FlexColumnWidth(1.7), // Dimensions
                  4: FlexColumnWidth(1.8), // Qty / Area
                  5: FlexColumnWidth(2.8), // Operations / Services formula
                  6: FlexColumnWidth(1.8), // Workshop Checklist
                  7: FlexColumnWidth(1.5), // Cutting Notes
                },
          border: TableBorder.all(
            color: const Color(0xFFCCFBF1),
            width: 1,
          ),
          children: [
            // Table Header: Light mint/teal background with crisp dark teal text
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFCCFBF1)),
              children: hasDim
                  ? [
                      const _TableHeaderCell('#', textColor: Color(0xFF0F766E)),
                      const _TableHeaderCell('البيان والمادة المطلوبة', textColor: Color(0xFF0F766E)),
                      const _TableHeaderCell('المواصفات والنوع', textColor: Color(0xFF0F766E)),
                      const _TableHeaderCell('الطول (سم)', textColor: Color(0xFF0F766E)),
                      const _TableHeaderCell('العرض (سم)', textColor: Color(0xFF0F766E)),
                      _TableHeaderCell(inv.isWorkshopOrder ? 'الكمية (العدد)' : 'الكمية / الأمتار (م²)', textColor: const Color(0xFF0F766E)),
                      const _TableHeaderCell('عمليات التشغيل وحسابها', textColor: Color(0xFF0F766E)),
                      const _TableHeaderCell('حالة التجهيز بالمصنع', textColor: Color(0xFF0F766E)),
                      const _TableHeaderCell('ملاحظات القص والتنفيذ', textColor: Color(0xFF0F766E)),
                    ]
                  : [
                      const _TableHeaderCell('#', textColor: Color(0xFF0F766E)),
                      const _TableHeaderCell('البيان والمادة المطلوبة', textColor: Color(0xFF0F766E)),
                      const _TableHeaderCell('المواصفات والنوع', textColor: Color(0xFF0F766E)),
                      const _TableHeaderCell('الأبعاد والمقاسات (سم)', textColor: Color(0xFF0F766E)),
                      _TableHeaderCell(inv.isWorkshopOrder ? 'الكمية (العدد)' : 'الكمية / الأمتار (م²)', textColor: const Color(0xFF0F766E)),
                      const _TableHeaderCell('عمليات التشغيل وحسابها', textColor: Color(0xFF0F766E)),
                      const _TableHeaderCell('حالة التجهيز بالمصنع', textColor: Color(0xFF0F766E)),
                      const _TableHeaderCell('ملاحظات القص والتنفيذ', textColor: Color(0xFF0F766E)),
                    ],
            ),

            // Repeated Data Rows with physical fulfillment checklist
            ...inv.items.map((it) {
              final isEven = it.index % 2 == 0;
              return TableRow(
                decoration: BoxDecoration(
                  color: isEven ? const Color(0xFFF0FDFA) : Colors.white,
                ),
                children: hasDim
                    ? [
                        _TableCell(it.index.toString(), isCenter: true),
                        _TableCell(it.description, isBold: true),
                        _TableCell(it.gradeAndSpecs),
                        _TableCell(it.lengthDisplay, isCenter: true, isBold: true),
                        _TableCell(it.widthDisplay, isCenter: true, isBold: true),
                        _TableCell(it.quantityText, isCenter: true, isBold: true),
                        _TableCell(it.servicesText, isSmall: true),
                        // Physical Checklist Boxes for Factory Craftsmen
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('☐ تم القص', style: TextStyle(fontSize: 9.5, color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                              Text('☐ تم الفرز والجلي', style: TextStyle(fontSize: 9.5, color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                              Text('☐ جاهز للتسليم', style: TextStyle(fontSize: 9.5, color: Color(0xFF0D9488), fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                        _TableCell('جاهز للتنفيذ', isSmall: true, isCenter: true, color: const Color(0xFF64748B)),
                      ]
                    : [
                        _TableCell(it.index.toString(), isCenter: true),
                        _TableCell(it.description, isBold: true),
                        _TableCell(it.gradeAndSpecs),
                        _TableCell(it.dimensionsText, isCenter: true, isBold: true),
                        _TableCell(it.quantityText, isCenter: true, isBold: true),
                        _TableCell(it.servicesText, isSmall: true),
                        // Physical Checklist Boxes for Factory Craftsmen
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('☐ تم القص', style: TextStyle(fontSize: 9.5, color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                              Text('☐ تم الفرز والجلي', style: TextStyle(fontSize: 9.5, color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                              Text('☐ جاهز للتسليم', style: TextStyle(fontSize: 9.5, color: Color(0xFF0D9488), fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                        _TableCell('جاهز للتنفيذ', isSmall: true, isCenter: true, color: const Color(0xFF64748B)),
                      ],
              );
            }),
          ],
        ),
      ),
    );
  }

  /// System verification line at the bottom of the page (Includes "Sh Ab'ad" and phone 0931691900)
  Widget _buildSystemFooterLine({
    required int pageNumber,
    required int totalPages,
    String? customLabel,
  }) {
    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              customLabel ?? 'برنامج Sh Ab\'ad • هاتف: 0931691900 • مستند معتمد',
              style: const TextStyle(
                fontSize: 9.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            totalPages > 1
                ? 'صفحة $pageNumber من $totalPages • تاريخ الطباعة: ${intl.DateFormat("yyyy-MM-dd HH:mm").format(DateTime.now())}'
                : 'تاريخ الطباعة: ${intl.DateFormat("yyyy-MM-dd HH:mm").format(DateTime.now())}',
            style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _TableHeaderCell extends StatelessWidget {
  final String text;
  final Color? textColor;
  const _TableHeaderCell(this.text, {this.textColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10.0,
          fontWeight: FontWeight.w900,
          color: textColor ?? const Color(0xFF0F172A),
        ),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final bool isCenter;
  final bool isBold;
  final bool isSmall;
  final Color? color;

  const _TableCell(
    this.text, {
    this.isCenter = false,
    this.isBold = false,
    this.isSmall = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
      child: Text(
        text,
        textAlign: isCenter ? TextAlign.center : TextAlign.start,
        style: TextStyle(
          fontSize: isSmall ? 9.0 : 10.0,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          color: color ?? const Color(0xFF0F172A),
        ),
      ),
    );
  }
}
