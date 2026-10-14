import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/models/models.dart';

class ThermalReceiptDialog extends StatelessWidget {
  final String title;
  final String invoiceNo;
  final String dateText;
  final String partyName;
  final List<Map<String, dynamic>> items;
  final double subtotal;
  final double shippingFee;
  final double advancePayment;
  final double grandTotal;
  final double remainingBalance;

  const ThermalReceiptDialog({
    super.key,
    required this.title,
    required this.invoiceNo,
    required this.dateText,
    required this.partyName,
    required this.items,
    required this.subtotal,
    required this.shippingFee,
    required this.advancePayment,
    required this.grandTotal,
    required this.remainingBalance,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.print_rounded, color: AppColors.accentPrimary, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'معاينة طباعة الإيصال الحراري (Esc/POS)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 16,
                            color: AppColors.brandPrimaryText,
                          ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Divider(height: 24),
            // Thermal Receipt Preview Container (Simulating 80mm paper roll)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB), // Receipt paper look
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCD34D), width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 4)),
                ],
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  // Receipt Header
                  const Text(
                    'معمل ومصنع الرخام والغرانيت',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                  const Text(
                    'نظام إدارة الإنتاج والمالية المتكامل',
                    style: TextStyle(fontSize: 11, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '------------------------------------------------',
                    style: TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('رقم الفاتورة: $invoiceNo', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      Text('التاريخ: $dateText', style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                  Row(
                    children: [
                      Text('العميل / الجهة: $partyName', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const Text(
                    '------------------------------------------------',
                    style: TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                  // Table Header
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(flex: 3, child: Text('الصنف / المقاس', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      Expanded(flex: 1, child: Text('الكمية', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      Expanded(flex: 2, child: Text('المجموع', textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ...items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                '${item["name"]} (${item["details"] ?? ""})',
                                style: const TextStyle(fontSize: 11, color: Colors.black87),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                '${item["qty"]}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${item["total"]}\$',
                                textAlign: TextAlign.end,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const Text(
                    '------------------------------------------------',
                    style: TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                  // Totals
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('المجموع الفرعي:', style: TextStyle(fontSize: 11)),
                      Text('${subtotal.fmt}\$', style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                  if (shippingFee > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('رسوم النولون / التوصيل:', style: TextStyle(fontSize: 11)),
                        Text('${shippingFee.fmt}\$', style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('إجمالي الفاتورة:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('${grandTotal.fmt}\$', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accentPrimary)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('المدفوع (الدفعة الأولى):', style: TextStyle(fontSize: 11, color: AppColors.scrapBoxAccent)),
                      Text('${advancePayment.fmt}\$', style: TextStyle(fontSize: 11, color: AppColors.scrapBoxAccent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('المتبقي الذمة:', style: TextStyle(fontSize: 11, color: AppColors.dangerWaste)),
                      Text('${remainingBalance.fmt}\$', style: TextStyle(fontSize: 11, color: AppColors.dangerWaste, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'شكراً لتعاملكم معنا • يرجى الاحتفاظ بالفاتورة',
                    style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('إغلاق المعاينة'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentPrimary),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم إرسال أمر الطباعة إلى طابعة الفواتير الحرارية ESC/POS بنجاح!'),
                          backgroundColor: AppColors.successGreen,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.print),
                    label: const Text('إرسال للطابعة الان'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

