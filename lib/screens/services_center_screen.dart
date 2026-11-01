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

  final TextEditingController _priceController = TextEditingController();
  final _priceFormKey = GlobalKey<FormState>();
  String? _editingServiceId;

  @override
  void dispose() {
    nameCtrl.dispose();
    rateCtrl.dispose();
    descCtrl.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _savePrice(ERPProvider erp, String serviceId) {
    if (!_priceFormKey.currentState!.validate()) return;
    final price = double.parse(_priceController.text.trim());
    if (erp.updateServicePrice(serviceId, price)) {
      setState(() => _editingServiceId = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تحديث سعر الخدمة.')));
    }
  }

  Widget _buildPriceEditor(ERPProvider erp, ServiceItemModel service) {
    if (_editingServiceId != service.id) {
      return Row(
        children: [
          Expanded(
            child: Text(
              AppCurrency.single(service.unitRate, AppCurrency.usd),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.accentPrimary,
              ),
            ),
          ),
          IconButton(
            tooltip: 'تعديل سعر الخدمة',
            onPressed: () => setState(() {
              _editingServiceId = service.id;
              _priceController.text = service.unitRate.toString();
            }),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      );
    }
    return Form(
      key: _priceFormKey,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              controller: _priceController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'سعر الخدمة',
                suffixText: AppCurrency.symbol(AppCurrency.usd),
                isDense: true,
              ),
              validator: (text) {
                final price = double.tryParse(text?.trim() ?? '');
                return price == null || !price.isFinite || price < 0
                    ? 'أدخل سعراً صالحاً غير سالب'
                    : null;
              },
              onFieldSubmitted: (_) => _savePrice(erp, service.id),
            ),
          ),
          IconButton(
            tooltip: 'حفظ السعر',
            onPressed: () => _savePrice(erp, service.id),
            icon: const Icon(Icons.check_rounded),
          ),
          IconButton(
            tooltip: 'إلغاء التعديل',
            onPressed: () => setState(() => _editingServiceId = null),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مركز إدارة الخدمات (Services Center)',
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'تعريف وتسعير الخدمات الملحقة (جلي، شطف حواف، قص زوايا معقدة، ثقب مغاسل، نقل وتوصيل)',
                        style: TextStyle(color: AppColors.brandSecondaryText),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
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
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 420,
                  mainAxisExtent: 270,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
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
                                decoration: BoxDecoration(
                                  color: AppColors.chipBgBlue,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.home_repair_service_rounded,
                                  color: AppColors.accentPrimary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  s.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            s.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.brandSecondaryText,
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'تعريفة أجرة الخدمة:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          _buildPriceEditor(erp, s),
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
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'اسم الخدمة'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: rateCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'الأجرة القياسية (\$)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'وصف طريقة الحساب والتنفيذ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                erp.addService(
                  ServiceItemModel(
                    id: 'srv_${DateTime.now().millisecondsSinceEpoch}',
                    name: nameCtrl.text,
                    unitRate: double.tryParse(rateCtrl.text) ?? 0.0,
                    description: descCtrl.text,
                  ),
                );
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
