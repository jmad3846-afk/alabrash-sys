import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';
import '../widgets/currency_selector.dart';

class GlobalOrdersScreen extends StatefulWidget {
  const GlobalOrdersScreen({super.key});

  @override
  State<GlobalOrdersScreen> createState() => _GlobalOrdersScreenState();
}

class _GlobalOrdersScreenState extends State<GlobalOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _ordersReturnsTabController;

  @override
  void initState() {
    super.initState();
    _ordersReturnsTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _ordersReturnsTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final erp = Provider.of<ERPProvider>(context);

    return Scaffold(
      body: Column(
        children: [
          Container(
            color: AppColors.panelSurface,
            child: TabBar(
              controller: _ordersReturnsTabController,
              labelColor: AppColors.accentPrimary,
              unselectedLabelColor: AppColors.brandSecondaryText,
              indicatorColor: AppColors.accentPrimary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              tabs: const [
                Tab(
                  text:
                      '1. الشاشة الشاملة لإدارة الطلبيات (Global Orders Management)',
                ),
                Tab(text: '2. محرك فواتير المرتجع (Returns Engine)'),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: TabBarView(
              controller: _ordersReturnsTabController,
              children: [
                _buildGlobalOrdersTab(erp),
                _buildReturnsEngineTab(erp),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: GLOBAL ORDERS MANAGEMENT
  // -------------------------------------------------------------
  Widget _buildGlobalOrdersTab(ERPProvider erp) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'سجل الطلبيات الشامل وتتبع العربونات والصناديق المعزولة',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontSize: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.chipBgSky,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'إجمالي الدفعات في صندوق الطلبيات المعزول: ${erp.orderCashBox.fmt} \$',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.orderDepositBoxAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: ListView.separated(
                itemCount: erp.workshopOrders.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final ord = erp.workshopOrders[idx];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.orderDepositBoxAccent
                          .withValues(alpha: 0.1),
                      child: const Icon(
                        Icons.shopping_bag_rounded,
                        color: AppColors.orderDepositBoxAccent,
                      ),
                    ),
                    title: Text(
                      '${ord.orderNo} • الزبون: ${ord.clientName}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'الطلب: ${ord.customDimensionsText} • الهاتف: ${ord.clientPhone} • التاريخ: ${intl.DateFormat("yyyy-MM-dd").format(ord.date)}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'السعر: ${ord.agreedPrice}${ord.currencySymbol}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'العربون المعزول: ${ord.depositAmount}${ord.currencySymbol}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.orderDepositBoxAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: RETURNS ENGINE (3 SECTIONS)
  // -------------------------------------------------------------
  Widget _buildReturnsEngineTab(ERPProvider erp) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'سجل ومحرك فواتير المرتجع (Returns Engine)',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontSize: 20),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dangerWaste,
                ),
                onPressed: () => _showAddReturnInvoiceDialog(erp),
                icon: const Icon(Icons.assignment_return_rounded),
                label: const Text('إصدار فاتورة مرتجع جديد'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: ListView.separated(
                itemCount: erp.returnInvoices.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final ret = erp.returnInvoices[idx];
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.chipBgRed,
                      child: Icon(
                        Icons.replay_rounded,
                        color: AppColors.dangerWaste,
                      ),
                    ),
                    title: Text(
                      '${ret.returnNo} • ${ret.returnType}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'الطرف: ${ret.partyName} • الصنف: ${ret.itemDescription} • المعالجة: ${ret.paymentAction}',
                    ),
                    trailing: Text(
                      'المبلغ المسترد: ${ret.refundAmount}${AppCurrency.symbol(ret.currency)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.dangerWaste,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddReturnInvoiceDialog(ERPProvider erp) {
    String returnType = 'مرتجع مشتريات مورد';
    final partyCtrl = TextEditingController(text: 'شركة مقالع الرخام الوطنية');
    final descCtrl = TextEditingController(
      text: 'بلوك كاردينال فيه عيوب تصنيع',
    );
    final qtyCtrl = TextEditingController(text: '1');
    final refundCtrl = TextEditingController(text: '200');
    String paymentAction = 'تخفيض دين';
    String retCurrency = AppCurrency.usd;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Dialog(
          child: Container(
            width: 540,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'إصدار فاتورة مرتجع جديدة',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontSize: 18),
                  ),
                  const Divider(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: returnType,
                    decoration: const InputDecoration(labelText: 'نوع المرتجع'),
                    items: const [
                      DropdownMenuItem(
                        value: 'مرتجع مشتريات مورد',
                        child: Text(
                          '1. مرتجع مشتريات مورد (Supplier Purchase Return)',
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'مرتجع مبيعات مصنع',
                        child: Text(
                          '2. مرتجع مبيعات مصنع (Factory Sales Return)',
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'مرتجع مبيعات معمل',
                        child: Text(
                          '3. مرتجع مبيعات معمل (Workshop Sales Return)',
                        ),
                      ),
                    ],
                    onChanged: (v) => setSt(() => returnType = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: partyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم المورد / الزبون',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'تفاصيل الصنف المرتجع',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'الكمية المرتجعة',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: refundCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'مبلغ الاسترداد / المرتجع (\$)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CurrencySelector(
                    value: retCurrency,
                    dense: true,
                    onChanged: (v) => setSt(() => retCurrency = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: paymentAction,
                    decoration: const InputDecoration(
                      labelText: 'طريقة المعالجة المالية',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'تخفيض دين',
                        child: Text('تخفيض الدين / الذمة المالية'),
                      ),
                      DropdownMenuItem(
                        value: 'استرداد نقدي للصندوق الرئيسي',
                        child: Text('استرداد نقدي مباشر من الصندوق الرئيسي'),
                      ),
                    ],
                    onChanged: (v) => setSt(() => paymentAction = v!),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.dangerWaste,
                    ),
                    onPressed: () {
                      final saved = erp.processReturnInvoice(
                        ReturnInvoiceModel(
                          id: 'ret_${DateTime.now().millisecondsSinceEpoch}',
                          returnNo: 'RET-${erp.returnInvoices.length + 101}',
                          date: DateTime.now(),
                          returnType: returnType,
                          partyName: partyCtrl.text,
                          itemDescription: descCtrl.text,
                          quantity: double.tryParse(qtyCtrl.text) ?? 1.0,
                          refundAmount: double.tryParse(refundCtrl.text) ?? 0.0,
                          paymentAction: paymentAction,
                          currency: retCurrency,
                        ),
                      );
                      if (!saved) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'تعذر حفظ المرتجع: تحقق من المبلغ والرصيد وطريقة التسوية.',
                            ),
                          ),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                    },
                    child: const Text('تأكيد وحفظ فاتورة المرتجع'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
