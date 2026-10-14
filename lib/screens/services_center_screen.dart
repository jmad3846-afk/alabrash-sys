import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';

class ServicesCenterScreen extends StatefulWidget {
  const ServicesCenterScreen({super.key});

  @override
  State<ServicesCenterScreen> createState() => _ServicesCenterScreenState();
}

class _ServicesCenterScreenState extends State<ServicesCenterScreen> {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController rateCtrl = TextEditingController();
  final TextEditingController descCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final erp = Provider.of<ERPProvider>(context);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('مركز إدارة الخدمات (Services Center)', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22)),
                    const SizedBox(height: 4),
                    const Text('تعريف وتسعير الخدمات الملحقة (جلي، شطف حواف، قص زوايا معقدة، ثقب مغاسل، نقل وتوصيل)', style: TextStyle(color: AppColors.brandSecondaryText)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddServiceDialog(erp),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('إضافة خدمة جديدة'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.6,
                ),
                itemCount: erp.services.length,
                itemBuilder: (context, idx) {
                  final s = erp.services[idx];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: AppColors.chipBgBlue, borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.home_repair_service_rounded, color: AppColors.accentPrimary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  s.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(s.description, style: const TextStyle(fontSize: 12, color: AppColors.brandSecondaryText)),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('تعريفة أجرة الخدمة:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              Text(
                                '${s.unitRate.fmt} \$',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.accentPrimary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddServiceDialog(ERPProvider erp) {
    nameCtrl.clear();
    rateCtrl.clear();
    descCtrl.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة خدمة جديدة لمركز الخدمات'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الخدمة')),
            const SizedBox(height: 8),
            TextField(controller: rateCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الأجرة القياسية (\$)')),
            const SizedBox(height: 8),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'وصف طريقة الحساب والتنفيذ')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                erp.addService(ServiceItemModel(
                  id: 'srv_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameCtrl.text,
                  unitRate: double.tryParse(rateCtrl.text) ?? 0.0,
                  description: descCtrl.text,
                ));
                Navigator.pop(ctx);
              }
            },
            child: const Text('حفظ الخدمة'),
          ),
        ],
      ),
    );
  }
}

