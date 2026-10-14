import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';

class PartnerManagementModal extends StatefulWidget {
  const PartnerManagementModal({super.key});

  @override
  State<PartnerManagementModal> createState() => _PartnerManagementModalState();
}

class _PartnerManagementModalState extends State<PartnerManagementModal> {
  final TextEditingController injectCapitalController = TextEditingController();
  final TextEditingController withdrawAmountController = TextEditingController();
  String selectedPartnerForWithdrawal = 'p1';
  String warningMessage = '';

  @override
  Widget build(BuildContext context) {
    final erp = Provider.of<ERPProvider>(context);

    return Dialog(
      child: Container(
        width: 650,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.chipBgAmber,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.group_rounded, color: AppColors.partnersEquityAccent),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'إدارة حقوق الملكية والشركاء وتوزيع الأرباح',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 24),
              // Partners Readout Grid
              const Text('نسب الشركاء الحالية وتوزيع الأرباح الصافية:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              Row(
                children: erp.partners.map((partner) {
                  double netProfitShare = erp.netOperatingProfit * partner.ratio;
                  double netAvailable = netProfitShare - partner.totalWithdrawn;
                  return Expanded(
                    child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      color: AppColors.chipBgAmber.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: AppColors.partnersEquityAccent, width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(partner.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text('النسبة: ${(partner.ratio * 100).fmt}%', style: const TextStyle(color: AppColors.partnersEquityAccent, fontWeight: FontWeight.bold)),
                            Text('رأس المال: ${partner.injectedCapital.fmt}\$', style: const TextStyle(fontSize: 11)),
                            const Divider(height: 12),
                            Text('حصة الأرباح: ${netProfitShare.fmt}\$', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            Text('المسحوب: ${partner.totalWithdrawn.fmt}\$', style: const TextStyle(fontSize: 11, color: AppColors.dangerWaste)),
                            Text('الصافي المتاح: ${netAvailable.fmt}\$', style: const TextStyle(fontSize: 11, color: AppColors.successGreen, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // ACTION 1: Capital Injection
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.panelBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('إضافة رأس مال جديد وتحديث النسب آلياً:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: injectCapitalController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'مبلغ رأس المال المضاف جديداً (\$)',
                              hintText: 'مثال: 50000',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.partnersEquityAccent),
                          onPressed: () {
                            double amount = double.tryParse(injectCapitalController.text) ?? 0.0;
                            if (amount > 0) {
                              erp.injectNewPartnerCapital(amount);
                              injectCapitalController.clear();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تمت إضافة رأس المال الجديد وتحديث نسب الشركاء آلياً!'), backgroundColor: AppColors.successGreen),
                              );
                            }
                          },
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('حقن رأس المال'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ACTION 2: Profit Withdrawal with Safety Limit Warning
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('سحب أرباح لشريك (مع فحص حدود الأمان للميزانية):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.partnersEquityAccent)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedPartnerForWithdrawal,
                            decoration: const InputDecoration(labelText: 'اختر الشريك'),
                            items: erp.partners.map((p) {
                              return DropdownMenuItem(value: p.id, child: Text(p.name));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => selectedPartnerForWithdrawal = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: withdrawAmountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'مبلغ المسحوبات (\$)'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.dangerWaste),
                          onPressed: () {
                            double amount = double.tryParse(withdrawAmountController.text) ?? 0.0;
                            if (amount > 0) {
                              var outMsg = MutableWrapper('');
                              erp.withdrawPartnerProfit(selectedPartnerForWithdrawal, amount, outMsg);
                              if (outMsg.value.isNotEmpty) {
                                setState(() {
                                  warningMessage = outMsg.value;
                                });
                              } else {
                                setState(() {
                                  warningMessage = '';
                                });
                                withdrawAmountController.clear();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تم تسجيل مسحوبات الأرباح للشريك بنجاح!'), backgroundColor: AppColors.successGreen),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.outbox_rounded),
                          label: const Text('سحب الأرباح'),
                        ),
                      ],
                    ),
                    if (warningMessage.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.chipBgRed,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppColors.dangerWaste, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                warningMessage,
                                style: const TextStyle(color: AppColors.dangerWaste, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandPrimaryText),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('إغلاق الشاشة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

