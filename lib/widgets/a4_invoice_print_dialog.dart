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
  final String quantityText;
  final double unitPrice;
  final String servicesText;
  final double lineTotal;

  const A4InvoiceLineItem({
    required this.index,
    required this.description,
    this.gradeAndSpecs = '—',
    this.dimensionsText = '—',
    required this.quantityText,
    required this.unitPrice,
    this.servicesText = '—',
    required this.lineTotal,
  });
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
  });

  /// Factory adapter for Factory Invoices (Supplier Purchase & Approved Clients POS).
  factory A4InvoiceData.fromFactoryInvoice(FactoryInvoiceModel inv) {
    final isPurchase = inv.invoiceType == 'شراء_مورد';
    final typeTitle = isPurchase
        ? 'فاتورة شراء بلوكات رخام وحجر من مورد'
        : 'فاتورة مبيعات مستودع المصنع (معتمدين)';
    final role = isPurchase ? 'المورد' : 'المعتمد / العميل';

    final items = <A4InvoiceLineItem>[];
    for (int i = 0; i < inv.items.length; i++) {
      final it = inv.items[i];
      final dim = (it.lengthCm > 0 && it.widthCm > 0)
          ? '${it.lengthCm.fmt} × ${it.widthCm.fmt} سم'
          : '—';
      final srvText = it.services.isNotEmpty
          ? it.services.map((s) => '${s.serviceName} (${s.price}\$)').join(' + ')
          : '—';
      final qtyLabel = isPurchase
          ? '${it.quantity.fmt} طن'
          : '${it.calculatedArea.fmt} ${it.heightCm > 5 ? "م³" : "م²"} (${it.quantity.fmt} قطعة)';

      items.add(A4InvoiceLineItem(
        index: i + 1,
        description: it.typeName.isNotEmpty ? it.typeName : it.description,
        gradeAndSpecs: '${it.grade} ${it.isGranite ? "(جرانيت)" : "(رخام)"}',
        dimensionsText: dim,
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
      shippingFee: inv.shippingFee,
      discount: inv.discountAmount,
      grandTotal: inv.grandTotal,
      paidAmount: inv.advancePayment,
      remainingBalance: inv.remainingBalance,
      notes: inv.isGoodsDelivered
          ? 'شحن واصل للعنوان المطلوب'
          : 'الاستلام من أرض المستودع (الزبون يستلم النقل)',
      isGoodsDelivered: inv.isGoodsDelivered,
    );
  }

  /// Factory adapter for Workshop Workspace Invoices.
  factory A4InvoiceData.fromWorkshopInvoice(WorkshopInvoiceModel inv) {
    final items = <A4InvoiceLineItem>[];
    final srvText = inv.services.isNotEmpty
        ? inv.services.map((s) => '${s.serviceName} (${s.price}\$)').join(' + ')
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

    return A4InvoiceData(
      invoiceTypeTitle: 'فاتورة مبيعات وخدمات ورشة المعمل',
      invoiceNo: inv.invoiceNo,
      date: inv.date,
      partyName: inv.clientName,
      partyRole: 'العميل / الزبون',
      partyPhone: '—',
      currency: inv.currency,
      paymentStatus: inv.remainingBalance > 0.01 ? 'مستحق الدفع' : 'مدفوعة بالكامل',
      items: items,
      subtotal: inv.agreedPrice,
      servicesTotal: inv.servicesTotal,
      shippingFee: 0.0,
      discount: inv.salesDiscount,
      grandTotal: inv.grandTotal,
      paidAmount: inv.cashPaidNow + inv.depositDeducted,
      remainingBalance: inv.remainingBalance,
      notes: 'المصدر: ${inv.sourceType} • ${inv.isGranite ? "جرانيت طبيعي" : "رخام طبيعي"}',
      isGoodsDelivered: true,
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
  final GlobalKey _previewContainerKey = GlobalKey();
  bool _isPrinting = false;

  Future<void> _handleDirectPrint() async {
    setState(() => _isPrinting = true);
    try {
      final boundary = _previewContainerKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 2.5);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final pdfDoc = pw.Document();
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

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfDoc.save(),
        name: 'فاتورة_${widget.invoiceData.invoiceNo}.pdf',
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

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 940,
        height: MediaQuery.of(context).size.height * 0.94,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 24,
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
                  Row(
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'معاينة طباعة الفاتورة قياس A4 (Print Preview)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'رقم الفاتورة: ${inv.invoiceNo} • ${inv.partyName}',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          elevation: 2,
                        ),
                        onPressed: _isPrinting ? null : _handleDirectPrint,
                        icon: _isPrinting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.print_rounded, size: 18),
                        label: Text(
                          _isPrinting ? 'جارٍ المعالجة...' : 'طباعة الفاتورة / PDF',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        tooltip: 'إغلاق',
                      ),
                    ],
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
                  child: RepaintBoundary(
                    key: _previewContainerKey,
                    child: _buildA4Paper(context, centerInfo, inv),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Pure A4 Sheet (210mm x 297mm styled white sheet)
  Widget _buildA4Paper(
    BuildContext context,
    CenterInfoModel centerInfo,
    A4InvoiceData inv,
  ) {
    return Container(
      width: 794,
      constraints: const BoxConstraints(minHeight: 1123),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
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
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Accent Ribbon
            Container(
              height: 5,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFFD97706), Color(0xFF2563EB)],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 1. INVOICE HEADER (Center Details & Logo)
            _buildInvoiceHeader(centerInfo),
            const SizedBox(height: 14),

            // Official Invoice Title Banner & Metadata Box
            _buildInvoiceMetaSection(inv),
            const SizedBox(height: 18),

            // 2. INVOICE BODY (Main Structured Table)
            _buildItemsTable(inv),
            const SizedBox(height: 16),

            // 3. FINANCIAL SUMMARY & TOTALS (Bottom Section)
            _buildFinancialSummary(inv),
            const SizedBox(height: 28),

            // 4. SIGNATURES & OFFICIAL SEALS
            _buildSignaturesFooter(centerInfo),
            const SizedBox(height: 18),

            // Bottom System Footer Line
            Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'طُبعت هذه الفاتورة بواسطة نظام الأبرش لإدارة الرخام والجرانيت • مستند مالي معتمد',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                  Text(
                    'تاريخ الطباعة: ${intl.DateFormat("yyyy-MM-dd HH:mm").format(DateTime.now())}',
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

  /// 1. Header with Full Sawmill / Center Details and Logo
  Widget _buildInvoiceHeader(CenterInfoModel center) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Right Side: Sawmill / Center Name & Info
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
                    _buildHeaderBadge(Icons.person_outline_rounded, 'المالك/الإدارة: ${center.ownerName}'),
                  if (center.commercialRegNo.isNotEmpty)
                    _buildHeaderBadge(Icons.receipt_long_rounded, 'س.ت: ${center.commercialRegNo}'),
                  if (center.taxId.isNotEmpty)
                    _buildHeaderBadge(Icons.shield_outlined, 'الرقم الضريبي: ${center.taxId}'),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(Icons.phone_in_talk_rounded, size: 13, color: Color(0xFF2563EB)),
                  const SizedBox(width: 4),
                  Text(
                    'هاتف: ${center.phone1}${center.phone2.isNotEmpty ? " • ${center.phone2}" : ""}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                  if (center.address.isNotEmpty) ...[
                    const SizedBox(width: 14),
                    const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF64748B)),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        center.address,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // Left Side: Center Logo / Emblem
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
            width: 90,
            height: 90,
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
            width: 90,
            height: 90,
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
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.domain_rounded, size: 36, color: Color(0xFF0F172A)),
          SizedBox(height: 4),
          Text(
            'شعار المركز',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  /// Invoice Title Banner & Metadata Information Grid
  Widget _buildInvoiceMetaSection(A4InvoiceData inv) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Banner Title
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  inv.invoiceTypeTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: inv.paymentStatus.contains('مدفوعة')
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    inv.paymentStatus,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Metadata Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isPrimary ? FontWeight.w900 : FontWeight.bold,
            color: isPrimary ? const Color(0xFF0F172A) : const Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  /// 2. INVOICE BODY: Structured Table Layout
  Widget _buildItemsTable(A4InvoiceData inv) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCBD5E1)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Table(
          columnWidths: const {
            0: FixedColumnWidth(36), // #
            1: FlexColumnWidth(3.2), // Description
            2: FlexColumnWidth(1.8), // Specs / Grade
            3: FlexColumnWidth(2.0), // Dimensions
            4: FlexColumnWidth(1.8), // Qty / Area
            5: FlexColumnWidth(1.6), // Unit Price
            6: FlexColumnWidth(2.2), // Services
            7: FlexColumnWidth(2.0), // Total
          },
          border: TableBorder.all(
            color: const Color(0xFFE2E8F0),
            width: 1,
          ),
          children: [
            // Table Header Row
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFF1E293B)),
              children: const [
                _TableHeaderCell('#'),
                _TableHeaderCell('البيان والمادة'),
                _TableHeaderCell('المواصفات والنوع'),
                _TableHeaderCell('الأبعاد (سم)'),
                _TableHeaderCell('الكمية / المساحة'),
                _TableHeaderCell('سعر الوحدة'),
                _TableHeaderCell('الخدمات الملحقة'),
                _TableHeaderCell('الإجمالي'),
              ],
            ),

            // Table Data Rows
            ...inv.items.map((it) {
              final isEven = it.index % 2 == 0;
              return TableRow(
                decoration: BoxDecoration(
                  color: isEven ? const Color(0xFFF8FAFC) : Colors.white,
                ),
                children: [
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

  /// 3. Financial Summary & Totals Box
  Widget _buildFinancialSummary(A4InvoiceData inv) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Terms, Conditions, Notes, Delivery Info
        Expanded(
          flex: 6,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF475569)),
                    SizedBox(width: 6),
                    Text(
                      'شروط وملاحظات الفاتورة:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '• البضاعة المجهزة بموجب مقاسات خاصة لا ترد ولا تستبدل بعد القص أو التفصيل.',
                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                ),
                const Text(
                  '• يرجى معاينة المواد والتأكد من مطابقتها قبل مغادرة المستودع أو التوقيع على الاستلام.',
                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                ),
                if (inv.notes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'ملاحظات إضافية: ${inv.notes}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(width: 20),

        // Right Column: Structured Financial Totals
        Expanded(
          flex: 5,
          child: Container(
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
                    'الخصم المسموح / بتر القروش:',
                    '- ${inv.discount.fmt} ${AppCurrency.symbol(inv.currency)}',
                    color: const Color(0xFF16A34A),
                  ),
                // Grand Total Highlight
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  color: const Color(0xFF0F172A),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'الإجمالي النهائي الصافي:',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        '${inv.grandTotal.fmt} ${AppCurrency.symbol(inv.currency)}',
                        style: const TextStyle(
                          color: Color(0xFFFBBF24),
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
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
                  'المتبقي بذمة العميل:',
                  '${inv.remainingBalance.fmt} ${AppCurrency.symbol(inv.currency)}',
                  isBold: true,
                  color: inv.remainingBalance > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: const Color(0xFF475569),
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
              color: color ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  /// 4. Signatures & Approvals Section
  Widget _buildSignaturesFooter(CenterInfoModel center) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSignatureBox('توقيع المستلم / العميل', 'الاسم: .......................................'),
        _buildSignatureBox('أمين الصندوق والمحاسبة', 'التوقيع: ...................................'),
        _buildSignatureBox('ختم وتوقيع إدارة المركز والمنشار', center.centerName),
      ],
    );
  }

  Widget _buildSignatureBox(String title, String subtitle) {
    return Container(
      width: 210,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36), // Space for physical signature / seal
          Text(
            subtitle,
            style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TableHeaderCell extends StatelessWidget {
  final String text;
  const _TableHeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
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
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Text(
        text,
        textAlign: isCenter ? TextAlign.center : TextAlign.start,
        style: TextStyle(
          fontSize: isSmall ? 9.5 : 11,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: color ?? const Color(0xFF334155),
        ),
      ),
    );
  }
}
