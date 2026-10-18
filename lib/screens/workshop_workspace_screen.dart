import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';
import '../widgets/currency_selector.dart';
import '../widgets/thermal_receipt_dialog.dart';
import '../widgets/a4_invoice_print_dialog.dart';
import 'accounting_screens.dart';

class WorkshopWorkspaceScreen extends StatefulWidget {
  const WorkshopWorkspaceScreen({super.key});

  @override
  State<WorkshopWorkspaceScreen> createState() =>
      _WorkshopWorkspaceScreenState();
}

class _WorkshopWorkspaceScreenState extends State<WorkshopWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _workshopTabController;

  @override
  void initState() {
    super.initState();
    _workshopTabController = TabController(length: 9, vsync: this);
  }

  @override
  void dispose() {
    _workshopTabController.dispose();
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
              controller: _workshopTabController,
              isScrollable: true,
              labelColor: AppColors.accentPrimary,
              unselectedLabelColor: AppColors.brandSecondaryText,
              indicatorColor: AppColors.accentPrimary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              tabs: const [
                Tab(text: '1. مواد المعمل (Raw Stock)'),
                Tab(text: '2. مفصل (تفصيلات بسيطة ومعقدة)'),
                Tab(text: '3. زيادة (قطع زايد وخردة)'),
                Tab(text: '4. هدر (طبيعي وغير طبيعي)'),
                Tab(text: '5. طلبيات معمل (Orders)'),
                Tab(text: '6. فاتورة معمل (Workshop Invoices)'),
                Tab(text: '7. المشاريع (Projects)'),
                Tab(text: '8. مرتجعات ومسموحات المبيعات'),
                Tab(text: '9. فواتير المبيعات النقدية'),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: TabBarView(
              controller: _workshopTabController,
              children: [
                _buildTab1Stock(erp),
                _buildTab2Tailoring(erp),
                _buildTab3Scrap(erp),
                _buildTab4Waste(erp),
                _buildTab5Orders(erp),
                _buildTab6Invoices(erp),
                _buildTab7Projects(erp),
                const ReturnsAllowancesScreen(workshopOnly: true),
                _buildTab6Invoices(erp, cashOnly: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // SUB-TAB 1: WORKSHOP STOCK (materials transferred from factory)
  // Two sub-sections: Square Meters (m²) and Cubic Meters (m³).
  // -------------------------------------------------------------
  Widget _buildTab1Stock(ERPProvider erp) {
    final m2 = erp.workshopStock
        .where((w) => w.category == 'متر مربع')
        .toList();
    final m3 = erp.workshopStock
        .where((w) => w.category == 'متر مكعب')
        .toList();
    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'مخزون مواد المعمل المحولة من المصنع بالتكلفة الصافية',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showTransferFactoryToWorkshopDialog(erp),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('تحويل كمية من مستودع المصنع'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary,
                  ),
                  onPressed: () => _showReturnWorkshopToFactoryDialog(erp),
                  icon: const Icon(Icons.keyboard_return_rounded),
                  label: const Text('إرجاع أمتار إلى المصنع'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              color: const Color(0xFFF1F5F9),
              child: const TabBar(
                tabs: [
                  Tab(text: 'مخزون المعمل — متر مربع (م²)'),
                  Tab(text: 'مخزون المعمل — متر مكعب (م³)'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [
                  Column(
                    children: [
                      Expanded(child: _buildWorkshopStockGrid(erp, m2, 'م²')),
                      OpeningStockItemsPanel(
                        items: erp.openingEntry.openingStock,
                        category: 'أمتار المعمل',
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Expanded(child: _buildWorkshopStockGrid(erp, m3, 'م³')),
                      OpeningStockItemsPanel(
                        items: erp.openingEntry.openingStock,
                        category: 'أمتار المعمل',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkshopStockGrid(
    ERPProvider erp,
    List<WorkshopStockModel> items,
    String unit,
  ) {
    if (items.isEmpty) {
      return const Card(
        child: Center(child: Text('لا توجد مواد في هذا القسم بعد.')),
      );
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.35,
      ),
      itemCount: items.length,
      itemBuilder: (context, idx) {
        final item = items[idx];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${item.typeName} ${item.grade} — سماكة ${item.thicknessCm}سم',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.chipBgBlue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        unit,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.accentPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'التكلفة الصافية للمتر: ${item.netCostPerUnit}\$',
                  style: const TextStyle(
                    color: AppColors.brandSecondaryText,
                    fontSize: 12,
                  ),
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('المتاح:', style: TextStyle(fontSize: 13)),
                    Text(
                      '${item.availableQty} $unit',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.scrapBoxAccent,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('سعر البيع:', style: TextStyle(fontSize: 12)),
                    Text(
                      '${item.recommendedSalePrice}\$ / $unit',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.successGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accentPrimary,
                      side: const BorderSide(color: AppColors.accentPrimary),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _showReturnWorkshopToFactoryDialog(
                      erp,
                      preselectedItem: item,
                    ),
                    icon: const Icon(Icons.keyboard_return_rounded, size: 15),
                    label: const Text(
                      'إرجاع للمصنع',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------
  // SUB-TAB 2: TAILORED / CUSTOMIZED (Simple / Complex / Ready)
  // -------------------------------------------------------------
  Widget _buildTab2Tailoring(ERPProvider erp) {
    final ready = [
      ...erp.simpleTailorings,
      ...erp.complexTailorings,
    ].where((t) => t.complexity != 'بسيط' && t.complexity != 'معقد').toList();
    return DefaultTabController(
      length: 3,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: const Color(0xFFF1F5F9),
              child: const TabBar(
                tabs: [
                  Tab(text: 'تفصيل بسيط (Simple)'),
                  Tab(text: 'تفصيل معقد (Complex)'),
                  Tab(text: 'قطع جاهزة (Ready)'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [
                  _buildTailoringList(
                    erp,
                    erp.simpleTailorings
                        .where((t) => t.complexity == 'بسيط')
                        .toList(),
                    title: 'التفصيلات البسيطة (درج، عتبات، نوافذ)',
                    addLabel: '[إضافة تفصيل بسيط]',
                    onAdd: () => _showTailoringBuilderDialog(erp, 'بسيط'),
                    emptyHint: 'لا توجد تفصيلات بسيطة بعد.',
                    openingCategory: 'تفصيل بسيط',
                  ),
                  _buildTailoringList(
                    erp,
                    erp.complexTailorings
                        .where((t) => t.complexity == 'معقد')
                        .toList(),
                    title: 'التفصيلات المعقدة (مغاسل، بروفايل معقد)',
                    addLabel: '[إضافة تفصيل معقد]',
                    accent: AppColors.partnersEquityAccent,
                    onAdd: () => _showTailoringBuilderDialog(erp, 'معقد'),
                    emptyHint: 'لا توجد تفصيلات معقدة بعد.',
                    openingCategory: 'تفصيل معقد',
                  ),
                  _buildTailoringList(
                    erp,
                    ready,
                    title: 'قطع جاهزة (محولة من طلبيات ملغاة)',
                    addLabel: '',
                    onAdd: () {},
                    emptyHint: 'لا توجد قطع جاهزة بعد.',
                    hideAdd: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTailoringList(
    ERPProvider erp,
    List<WorkshopTailoringModel> items, {
    required String title,
    required String addLabel,
    required VoidCallback onAdd,
    required String emptyHint,
    Color? accent,
    bool hideAdd = false,
    String? openingCategory,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: accent ?? AppColors.accentPrimary,
                ),
              ),
            ),
            if (!hideAdd) ...[
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent ?? AppColors.accentPrimary,
                ),
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: Text(addLabel),
              ),
            ],
          ],
        ),
        if (openingCategory != null)
          OpeningStockItemsPanel(
            items: erp.openingEntry.openingStock,
            category: openingCategory,
          ),
        const SizedBox(height: 12),
        Expanded(
          child: items.isEmpty
              ? Card(child: Center(child: Text(emptyHint)))
              : Card(
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final t = items[idx];
                      return ListTile(
                        title: Text(
                          '${t.name} • المتاح ${t.quantity.fmt} ${t.unitSymbol}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'البنود: ${t.lineItems.length} • التكلفة: ${t.totalNetCost.fmt}\$ • ${t.photoPath.isEmpty ? "بلا صورة" : "مرفق صورة"}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'سعر البيع: ${t.sellingPrice.fmt}\$/${t.unitSymbol}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: accent ?? AppColors.successGreen,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.accentPrimary,
                              ),
                              tooltip: 'التفاصيل والتعديل',
                              onPressed: () =>
                                  _showTailoringDetailsModal(erp, t),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // SUB-TAB 3: SCRAP & EXTRA ITEMS (صندوق الزيادات)
  // -------------------------------------------------------------
  Widget _buildTab3Scrap(ERPProvider erp) {
    return Padding(
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
                  const Text(
                    'مخزون القطع الزائدة والخردة (Scrap Box)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'تنبيه محاسبي: جميع مبيعات القطع الزائدة ترحل حصراً وإلزامياً إلى [صندوق الزيادات]',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.scrapBoxAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.scrapBoxAccent,
                ),
                onPressed: () => _showAddScrapItemDialog(erp),
                icon: const Icon(Icons.add_a_photo_rounded),
                label: const Text('[إضافة قطعة زائدة]'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OpeningStockItemsPanel(
            items: erp.openingEntry.openingStock,
            category: 'قطع زائدة وخردة',
          ),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.5,
              ),
              itemCount: erp.scrapItems.length,
              itemBuilder: (context, idx) {
                final sc = erp.scrapItems[idx];
                return Card(
                  color: sc.isSold
                      ? const Color(0xFFF1F5F9)
                      : AppColors.panelSurface,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                sc.description,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: sc.isSold
                                    ? AppColors.chipBgRed
                                    : AppColors.chipBgGreen,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                sc.isSold ? 'تم البيع' : 'متاح للبيع',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: sc.isSold
                                      ? AppColors.dangerWaste
                                      : AppColors.scrapBoxAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'التكلفة التقديرية: ${sc.baseCost}${AppCurrency.symbol(sc.currency)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.brandSecondaryText,
                          ),
                        ),
                        if (sc.photoPath.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.attach_file_rounded, size: 14),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    sc.photoPath,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.brandSecondaryText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'سعر البيع: ${sc.sellingPrice}${AppCurrency.symbol(sc.currency)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.scrapBoxAccent,
                              ),
                            ),
                            if (!sc.isSold)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.scrapBoxAccent,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                onPressed: () {
                                  erp.sellScrapItem(sc);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'تم بيع القطعة وترحيل إيرادها حصراً إلى صندوق الزيادات!',
                                      ),
                                      backgroundColor: AppColors.successGreen,
                                    ),
                                  );
                                },
                                child: const Text('بيع لصندوق الزيادات'),
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
    );
  }

  // -------------------------------------------------------------
  // SUB-TAB 4: WASTE LOG — Natural vs Unnatural (voucher + loss)
  // -------------------------------------------------------------
  Widget _buildTab4Waste(ERPProvider erp) {
    final natural = erp.wasteLogs
        .where((w) => w.wasteType != 'هدر غير طبيعي')
        .toList();
    final unnatural = erp.wasteLogs
        .where((w) => w.wasteType == 'هدر غير طبيعي')
        .toList();
    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'سجل الهدر والكسور',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dangerWaste,
                  ),
                  onPressed: () => _showAddWasteLogDialog(erp),
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: const Text('إضافة قيد هدر / سند إتلاف'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              color: const Color(0xFFF1F5F9),
              child: const TabBar(
                tabs: [
                  Tab(text: 'هدر طبيعي (Natural)'),
                  Tab(text: 'هدر غير طبيعي (Unnatural — خسارة)'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [
                  _buildWasteList(natural, false, 'لا يوجد هدر طبيعي مسجل.'),
                  _buildWasteList(
                    unnatural,
                    true,
                    'لا يوجد هدر غير طبيعي مسجل.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWasteList(
    List<WasteLogModel> logs,
    bool isUnnatural,
    String emptyHint,
  ) {
    if (logs.isEmpty) {
      return Card(child: Center(child: Text(emptyHint)));
    }
    return Card(
      child: ListView.separated(
        itemCount: logs.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, idx) {
          final w = logs[idx];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: isUnnatural
                  ? AppColors.chipBgRed
                  : AppColors.chipBgAmber,
              child: Icon(
                isUnnatural ? Icons.warning_rounded : Icons.opacity_rounded,
                color: isUnnatural
                    ? AppColors.dangerWaste
                    : AppColors.partnersEquityAccent,
              ),
            ),
            title: Text(
              '${w.wasteType} • ${w.itemDescription}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'الكمية: ${w.quantity} • التاريخ: ${intl.DateFormat("yyyy-MM-dd").format(w.date)}${isUnnatural ? " • سند الإتلاف: ${w.destructionVoucherNo}" : ""}',
            ),
            trailing: Text(
              'خسارة: ${w.cost}\$',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isUnnatural
                    ? AppColors.dangerWaste
                    : AppColors.brandPrimaryText,
              ),
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------
  // SUB-TAB 5: WORKSHOP CUSTOM ORDERS (صندوق الطلبيات)
  // -------------------------------------------------------------
  Widget _buildTab5Orders(ERPProvider erp) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'سجل طلبيات المعمل المخصصة (Orders Management)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'قاعدة محاسبية: العرابين والدفعات الأولى تُحفظ في [صندوق الطلبيات] المعزول حتى تكتمل وتُرحل للفاتورة',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.orderDepositBoxAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orderDepositBoxAccent,
                ),
                onPressed: () => _showAddOrderDialog(erp),
                icon: const Icon(Icons.post_add_rounded),
                label: const Text('إضافة طلبية معمل جديدة'),
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
                    leading: CurrencyBadge(currency: ord.currency),
                    title: Text(
                      '${ord.orderNo} • الزبون: ${ord.clientName}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'تفاصيل الطلبية: ${ord.customDimensionsText} • الهاتف: ${ord.clientPhone}${ord.photoPath.isEmpty ? "" : " • مرفق صورة"}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'السعر: ${ord.agreedPrice}${ord.currencySymbol}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'العربون: ${ord.depositAmount}${ord.currencySymbol} (صندوق الطلبيات)',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.orderDepositBoxAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        if (ord.status == 'قيد التنفيذ') ...[
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.successGreen,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                            ),
                            onPressed: () {
                              erp.assignOrderToInvoice(
                                ord,
                                ord.agreedPrice - ord.depositAmount,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'تم ترحيل الطلبية إلى فاتورة المعمل ونقل العربون للصندوق الرئيسي بنجاح!',
                                  ),
                                  backgroundColor: AppColors.successGreen,
                                ),
                              );
                            },
                            child: const Text('ترحيل للفاتورة'),
                          ),
                          const SizedBox(width: 6),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.dangerWaste,
                            ),
                            onPressed: () => _showCancelOrderDialog(erp, ord),
                            child: const Text('إلغاء الطلبية'),
                          ),
                        ] else
                          Chip(
                            label: Text(ord.status),
                            backgroundColor: AppColors.chipBgGreen,
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
  // SUB-TAB 6: WORKSHOP INVOICES
  // -------------------------------------------------------------
  Widget _buildTab6Invoices(ERPProvider erp, {bool cashOnly = false}) {
    final invoices = cashOnly
        ? erp.workshopInvoices
              .where((invoice) => invoice.isCashInvoice)
              .toList()
        : erp.workshopInvoices;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  cashOnly
                      ? 'فواتير مبيعات المعمل النقدية (مسددة بالكامل)'
                      : 'فواتير مبيعات المعمل (Workshop Invoices)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPrimary,
                ),
                onPressed: () =>
                    _showAddWorkshopInvoiceDialog(erp, cashInvoice: cashOnly),
                icon: const Icon(Icons.receipt_long_rounded),
                label: Text(
                  cashOnly ? '[إضافة فاتورة بيع نقدية]' : '[إضافة فاتورة معمل]',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: ListView.separated(
                itemCount: invoices.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final inv = invoices[idx];
                  return ExpansionTile(
                    leading: CurrencyBadge(currency: inv.currency),
                    title: Text(
                      '${inv.invoiceNo} • الزبون: ${inv.clientName}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'المصدر: ${inv.sourceType}${inv.sourceType == 'تفصيل بسيط' || inv.sourceType == 'تفصيل معقد' ? ' • الكمية: ${inv.sourceQuantity.fmt} ${inv.sourceUnitCategory == 'متر مكعب' ? 'م³' : 'م²'}' : ''} • الإجمالي: ${inv.grandTotal.fmt}${inv.currencySymbol} • المدفوع: ${(inv.cashPaidNow + inv.depositDeducted).fmt}${inv.currencySymbol} • المتبقي: ${inv.remainingBalance.fmt}${inv.currencySymbol}${inv.photoPath.isEmpty ? "" : " • مرفق صورة"}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'معاينة طباعة A4 (Print Preview)',
                          icon: const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: Color(0xFF2563EB),
                          ),
                          onPressed: () {
                            A4InvoicePrintDialog.show(
                              context,
                              invoiceData:
                                  A4InvoiceData.fromWorkshopInvoice(inv),
                            );
                          },
                        ),
                        IconButton(
                          tooltip: 'إيصال حراري (Thermal)',
                          icon: const Icon(Icons.print_rounded),
                          onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => ThermalReceiptDialog(
                            title: 'فاتورة مبيعات معمل',
                            invoiceNo: inv.invoiceNo,
                            dateText: intl.DateFormat(
                              'yyyy-MM-dd',
                            ).format(inv.date),
                            partyName: inv.clientName,
                            items: [
                              {
                                'name': inv.itemDescription,
                                'details': inv.sourceType,
                                'qty':
                                    inv.sourceType == 'تفصيل بسيط' ||
                                        inv.sourceType == 'تفصيل معقد'
                                    ? '${inv.sourceQuantity.fmt} ${inv.sourceUnitCategory == 'متر مكعب' ? 'م³' : 'م²'}'
                                    : '1',
                                'total': inv.agreedPrice.fmt,
                              },
                              ...inv.services.map(
                                (s) => {
                                  'name': 'خدمة: ${s.serviceName}',
                                  'details': s.notes,
                                  'qty': '1',
                                  'total': s.price.fmt,
                                },
                              ),
                            ],
                            subtotal: inv.agreedPrice + inv.servicesTotal,
                            shippingFee: 0.0,
                            advancePayment:
                                inv.cashPaidNow + inv.depositDeducted,
                            grandTotal: inv.grandTotal,
                            remainingBalance: inv.remainingBalance,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                    children: [
                      ...inv.services.map(
                        (s) => ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.home_repair_service_rounded,
                            size: 18,
                            color: AppColors.accentPrimary,
                          ),
                          title: Text(s.serviceName),
                          subtitle: Text(s.notes.isEmpty ? '—' : s.notes),
                          trailing: Text(
                            '${s.price}\$',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      if (inv.photoPath.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.attach_file_rounded, size: 16),
                              const SizedBox(width: 6),
                              Expanded(child: Text(inv.photoPath)),
                            ],
                          ),
                        ),
                    ],
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
  // SUB-TAB 7: WORKSHOP PROJECTS (Pending / Completed-Paid)
  // -------------------------------------------------------------
  Widget _buildTab7Projects(ERPProvider erp) {
    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'مشاريع المعمل (Workshop Projects)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orderDepositBoxAccent,
                  ),
                  onPressed: () => _showProjectDialog(erp),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة مشروع'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              color: const Color(0xFFF1F5F9),
              child: const TabBar(
                tabs: [
                  Tab(text: 'بانتظار الدفع (Pending Payment)'),
                  Tab(text: 'مكتملة / مدفوعة (Completed)'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [
                  _buildProjectList(
                    erp,
                    erp.pendingProjects,
                    'لا توجد مشاريع بانتظار الدفع.',
                  ),
                  _buildProjectList(
                    erp,
                    erp.completedProjects,
                    'لا توجد مشاريع مكتملة بعد.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectList(
    ERPProvider erp,
    List<WorkshopProjectModel> projects,
    String emptyHint,
  ) {
    if (projects.isEmpty) {
      return Card(child: Center(child: Text(emptyHint)));
    }
    return Card(
      child: ListView.separated(
        itemCount: projects.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, idx) {
          final p = projects[idx];
          final invs = erp.workshopInvoices
              .where((i) => i.projectId == p.id)
              .toList();
          final due = erp.projectDue(p.id);
          final collected =
              invs.fold<double>(0.0, (s, i) => s + i.grandTotal) - due;
          return ExpansionTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.chipBgSky,
              child: Icon(
                Icons.domain_rounded,
                color: AppColors.orderDepositBoxAccent,
              ),
            ),
            title: Text(
              'المشروع ${p.name}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'الزبون: ${p.clientName} • الفواتير: ${invs.length} • المحصل: ${collected.fmt}\$ • المتبقي: ${due.fmt}\$',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.receipt_long_rounded,
                    color: AppColors.successGreen,
                  ),
                  tooltip: 'إصدار فاتورة معمل لهذا المشروع',
                  onPressed: () => _showAddWorkshopInvoiceDialog(
                    erp,
                    presetProjectId: p.id,
                    presetClientName: p.clientName,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: AppColors.accentPrimary,
                  ),
                  tooltip: 'تعديل المشروع',
                  onPressed: () => _showProjectDialog(erp, existing: p),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.dangerWaste,
                  ),
                  tooltip: 'حذف المشروع',
                  onPressed: () => showDialog(
                    context: context,
                    builder: (dctx) => AlertDialog(
                      title: const Text('حذف المشروع'),
                      content: Text(
                        'حذف المشروع "${p.name}"؟ (تبقى فواتيره مسجلة دون مشروع)',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dctx),
                          child: const Text('تراجع'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.dangerWaste,
                          ),
                          onPressed: () {
                            for (final inv in erp.workshopInvoices.where(
                              (i) => i.projectId == p.id,
                            )) {
                              final at = erp.workshopInvoices.indexWhere(
                                (x) => x.id == inv.id,
                              );
                              if (at >= 0) {
                                final old = erp.workshopInvoices[at];
                                erp.workshopInvoices[at] = WorkshopInvoiceModel(
                                  id: old.id,
                                  invoiceNo: old.invoiceNo,
                                  date: old.date,
                                  clientName: old.clientName,
                                  sourceType: old.sourceType,
                                  sourceId: old.sourceId,
                                  projectId: '',
                                  itemDescription: old.itemDescription,
                                  agreedPrice: old.agreedPrice,
                                  depositDeducted: old.depositDeducted,
                                  sourceQuantity: old.sourceQuantity,
                                  sourceUnitCategory: old.sourceUnitCategory,
                                  cashPaidNow: old.cashPaidNow,
                                  isCashInvoice: old.isCashInvoice,
                                  netCost: old.netCost,
                                  salesDiscount: old.salesDiscount,
                                  adjustmentsAmount: old.adjustmentsAmount,
                                  services: old.services,
                                  photoPath: old.photoPath,
                                  isGranite: old.isGranite,
                                  currency: old.currency,
                                );
                              }
                            }
                            erp.deleteProject(p.id);
                            Navigator.pop(dctx);
                          },
                          child: const Text('حذف'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            children: [
              if (p.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(children: [Expanded(child: Text(p.description))]),
                ),
              ...invs.map(
                (inv) => ListTile(
                  dense: true,
                  title: Text(
                    '${inv.invoiceNo} — ${inv.grandTotal.fmt}${inv.currencySymbol}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    '${inv.itemDescription} • المدفوع: ${(inv.cashPaidNow + inv.depositDeducted).fmt}${inv.currencySymbol} • المتبقي: ${inv.remainingBalance.fmt}${inv.currencySymbol}',
                  ),
                ),
              ),
              if (invs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'لا توجد فواتير لهذا المشروع بعد. أصدر فاتورة من زر الإيصال أعلاه.',
                    style: TextStyle(color: AppColors.brandSecondaryText),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showProjectDialog(
    ERPProvider erp, {
    WorkshopProjectModel? existing,
  }) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final clientCtrl = TextEditingController(text: existing?.clientName ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final photoCtrl = TextEditingController(text: existing?.photoPath ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'إضافة مشروع جديد' : 'تعديل المشروع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'اسم المشروع'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: clientCtrl,
              decoration: const InputDecoration(labelText: 'اسم الزبون'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'الهاتف'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'وصف المشروع'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: photoCtrl,
              decoration: const InputDecoration(
                labelText: 'صورة (مسار — اختياري)',
                prefixIcon: Icon(Icons.attach_file_rounded),
                isDense: true,
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
              if (nameCtrl.text.isEmpty) return;
              if (existing == null) {
                erp.addProject(
                  WorkshopProjectModel(
                    id: 'prj_${DateTime.now().millisecondsSinceEpoch}',
                    name: nameCtrl.text,
                    clientName: clientCtrl.text,
                    phone: phoneCtrl.text,
                    description: descCtrl.text,
                    photoPath: photoCtrl.text.trim(),
                  ),
                );
              } else {
                existing.name = nameCtrl.text;
                existing.clientName = clientCtrl.text;
                existing.phone = phoneCtrl.text;
                existing.description = descCtrl.text;
                existing.photoPath = photoCtrl.text.trim();
                erp.refresh();
              }
              Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  // DIALOG HELPERS
  /// Tailoring details: every line item with Length, Width, Quantity and
  /// Piece Price, plus per-line inventory editing.
  void _showTailoringDetailsModal(ERPProvider erp, WorkshopTailoringModel t) {
    final sellingCtrl = TextEditingController(text: t.sellingPrice.fmt);
    final Map<String, TextEditingController> qtyCtrls = {
      for (final li in t.lineItems)
        li.id: TextEditingController(text: li.quantity.fmt),
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Dialog(
          child: Container(
            width: 640,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'تفاصيل: ${t.name}',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontSize: 18),
                  ),
                  const Divider(height: 20),
                  Text('المادة: ${t.rawMaterialDescription}'),
                  Text('التكلفة الكلية: ${t.totalNetCost.fmt}\$'),
                  if (t.photoPath.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.attach_file_rounded, size: 16),
                          const SizedBox(width: 6),
                          Expanded(child: Text(t.photoPath)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'الكمية المتاحة: ${t.quantity.fmt} ${t.unitSymbol} • سعر البيع: ${t.sellingPrice.fmt}\$/${t.unitSymbol} • استهلاك المواد: ${t.lineItems.where((line) => line.category == 'متر مربع').fold<double>(0, (sum, line) => sum + line.area).fmt} م² + ${t.lineItems.where((line) => line.category == 'متر مكعب').fold<double>(0, (sum, line) => sum + line.area).fmt} م³',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'بنود المواد والخدمات:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (t.lineItems.isEmpty)
                    Text(
                      'الأبعاد: ${t.lengthCm}x${t.widthCm}${t.unitCategory == 'متر مكعب' ? 'x${t.heightCm}' : ''} سم • ${t.measurementCount.fmt} × ${t.measurementPerCount.fmt} ${t.unitSymbol}',
                    ),
                  ...t.lineItems.map(
                    (li) => Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${li.typeName} ${li.grade} (${li.source == 'scrap' ? 'خردة' : li.category})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: AppColors.dangerWaste,
                                  ),
                                  tooltip: 'حذف البند وإرجاع مخزونه',
                                  onPressed: () {
                                    if (li.source == 'materials') {
                                      erp.restoreWorkshopStock(
                                        li.stockId,
                                        li.area,
                                      );
                                    } else {
                                      final m = erp.scrapItems
                                          .where((s) => s.id == li.stockId)
                                          .toList();
                                      if (m.isNotEmpty) {
                                        m.first.isSold = false;
                                      }
                                    }
                                    t.lineItems.remove(li);
                                    qtyCtrls.remove(li.id);
                                    erp.refresh();
                                    setSt(() {});
                                  },
                                ),
                              ],
                            ),
                            Text(
                              'الطول: ${li.lengthCm} • العرض: ${li.widthCm}${li.category == 'متر مكعب' ? ' • الارتفاع: ${li.heightCm}' : ''} • الكمية: ${li.quantity}',
                            ),
                            Text(
                              'سعر البند: ${li.lineTotal.fmt}\$',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.successGreen,
                              ),
                            ),
                            if (li.services.isNotEmpty)
                              Text(
                                'الخدمات: ${li.services.map((s) => '${s.serviceName} ${s.price}\$').join('، ')}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            if (li.source == 'materials') ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: qtyCtrls[li.id],
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText:
                                            'تعديل استهلاك البند (م²/م³)',
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () {
                                      final nv =
                                          double.tryParse(
                                            qtyCtrls[li.id]!.text,
                                          ) ??
                                          li.quantity;
                                      if (nv <= 0) return;
                                      final oldQty = li.quantity;
                                      final oldArea = li.area;
                                      li.quantity = nv;
                                      final delta = li.area - oldArea;
                                      if (delta > 0) {
                                        final ok = erp.deductWorkshopStock(
                                          li.stockId,
                                          delta,
                                        );
                                        if (!ok) {
                                          li.quantity = oldQty;
                                          qtyCtrls[li.id]!.text = oldQty.fmt;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'لا يوجد مخزون كافٍ لهذه الزيادة.',
                                              ),
                                              backgroundColor:
                                                  AppColors.dangerWaste,
                                            ),
                                          );
                                          return;
                                        }
                                      } else if (delta < 0) {
                                        erp.restoreWorkshopStock(
                                          li.stockId,
                                          -delta,
                                        );
                                      }
                                      erp.refresh();
                                      setSt(() {});
                                    },
                                    child: const Text('تطبيق'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sellingCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'سعر البيع للمتر (\$)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('إغلاق'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            t.sellingPrice =
                                double.tryParse(sellingCtrl.text) ??
                                t.sellingPrice;
                            erp.refresh();
                            Navigator.pop(ctx);
                          },
                          child: const Text('حفظ التعديلات'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showTransferFactoryToWorkshopDialog(ERPProvider erp) {
    if (erp.factoryWarehouse.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('مستودع المصنع فارغ. انقل ناتج قص أولاً.'),
          backgroundColor: AppColors.dangerWaste,
        ),
      );
      return;
    }
    String? selectedWhId = erp.factoryWarehouse.first.id;
    final qtyCtrl = TextEditingController(text: '10');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('تحويل كمية من مستودع المصنع إلى المعمل'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedWhId,
                isExpanded: true,
                items: erp.factoryWarehouse
                    .map(
                      (w) => DropdownMenuItem(
                        value: w.id,
                        child: Text(
                          '${w.typeName} ${w.grade} ${w.thicknessCm}سم (${w.category}) - المتاح: ${w.availableQty}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setSt(() => selectedWhId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'الكمية المراد نقلها',
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
                if (selectedWhId == null) return;
                final matches = erp.factoryWarehouse
                    .where((w) => w.id == selectedWhId)
                    .toList();
                if (matches.isEmpty) return;
                final wh = matches.first;
                double q = double.tryParse(qtyCtrl.text) ?? 0.0;
                if (q <= 0 || q > wh.availableQty + 0.0001) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('أدخل كمية ضمن المتاح في مستودع المصنع.'),
                      backgroundColor: AppColors.dangerWaste,
                    ),
                  );
                  return;
                }
                erp.transferFactoryToWorkshop(wh, q);
                Navigator.pop(ctx);
              },
              child: const Text('تأكيد التحويل'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReturnWorkshopToFactoryDialog(
    ERPProvider erp, {
    WorkshopStockModel? preselectedItem,
  }) {
    final availableItems =
        erp.workshopStock.where((w) => w.availableQty > 0).toList();
    if (availableItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد أمتار متوفرة في المعمل للإرجاع إلى المصنع.'),
          backgroundColor: AppColors.dangerWaste,
        ),
      );
      return;
    }

    String? selectedWsId =
        preselectedItem != null && preselectedItem.availableQty > 0
            ? preselectedItem.id
            : availableItems.first.id;
    final qtyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final matches =
              availableItems.where((w) => w.id == selectedWsId).toList();
          final WorkshopStockModel ws =
              matches.isNotEmpty ? matches.first : availableItems.first;
          final unit = ws.category == 'متر مكعب' ? 'م³' : 'م²';

          return AlertDialog(
            title: Row(
              children: const [
                Icon(
                  Icons.keyboard_return_rounded,
                  color: AppColors.accentPrimary,
                ),
                SizedBox(width: 8),
                Text('إرجاع أمتار من المعمل إلى المصنع'),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'اختر مادة من مخزون المعمل لتسليمها/إرجاعها إلى مستودع المصنع:',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.brandSecondaryText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedWsId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'مادة المعمل'),
                    items: availableItems
                        .map(
                          (w) => DropdownMenuItem(
                            value: w.id,
                            child: Text(
                              '${w.typeName} ${w.grade} ${w.thicknessCm}سم (${w.category}) — المتاح: ${w.availableQty.fmt}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setSt(() {
                      selectedWsId = v;
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: qtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'الكمية المراد إرجاعها ($unit)',
                            helperText:
                                'المتاح حالياً: ${ws.availableQty.fmt} $unit',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          qtyCtrl.text = ws.availableQty.fmt;
                        },
                        child: const Text('كامل المتاح'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPrimary,
                ),
                onPressed: () {
                  final qty = double.tryParse(qtyCtrl.text) ?? 0.0;
                  if (qty <= 0 || qty > ws.availableQty + 0.0001) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('يرجى إدخال كمية صحيحة وضمن المتاح.'),
                        backgroundColor: AppColors.dangerWaste,
                      ),
                    );
                    return;
                  }
                  final ok = erp.transferWorkshopToFactory(ws, qty);
                  Navigator.pop(ctx);
                  if (ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'تم إرجاع ${qty.fmt} $unit من (${ws.typeName} ${ws.grade}) إلى مستودع المصنع بنجاح.',
                        ),
                        backgroundColor: AppColors.successGreen,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text('تأكيد الإرجاع للمصنع'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Unified tailoring builder. Simple uses Materials lines only;
  /// Complex uses Materials + Scrap lines.
  void _showTailoringBuilderDialog(ERPProvider erp, String complexity) {
    final bool allowScrap = complexity == 'معقد';
    final nameCtrl = TextEditingController();
    String? formError;

    String lineSource = 'materials';
    String? selectedStockId;
    String stockSearch = '';
    String? selectedScrapId;
    String scrapSearch = '';
    final lenCtrl = TextEditingController();
    final widCtrl = TextEditingController();
    final heiCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final sellMeterCtrl = TextEditingController();
    final laborCtrl = TextEditingController();
    String? selectedServiceId;
    String serviceSearch = '';
    final servicePriceCtrl = TextEditingController();
    final serviceNotesCtrl = TextEditingController();
    final List<ServiceAttachment> draftServices = [];
    final List<TailoringLineItem> draftLines = [];
    String productUnit = complexity == 'معقد' ? 'متر مكعب' : 'متر مربع';

    double lineArea(
      WorkshopStockModel? ws,
      double l,
      double w,
      double h,
      double q,
    ) {
      if (ws == null || q <= 0) return 0.0;
      if (ws.category == 'متر مكعب') {
        if (l <= 0 || w <= 0 || h <= 0) return 0.0;
        return (l / 100.0) * (w / 100.0) * (h / 100.0) * q;
      }
      if (l <= 0 || w <= 0) return 0.0;
      return (l / 100.0) * (w / 100.0) * q;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          WorkshopStockModel? ws;
          if (selectedStockId != null) {
            final m = erp.workshopStock
                .where((w) => w.id == selectedStockId)
                .toList();
            ws = m.isEmpty ? null : m.first;
          }
          final bool wsCube = ws?.category == 'متر مكعب';
          final stockFiltered = erp.workshopStock
              .where(
                (w) =>
                    stockSearch.isEmpty ||
                    '${w.typeName} ${w.grade}'.contains(stockSearch),
              )
              .toList();
          final stockValue = stockFiltered.any((w) => w.id == selectedStockId)
              ? selectedStockId
              : null;
          final scrapFiltered = erp.scrapItems
              .where(
                (s) =>
                    !s.isSold &&
                    (scrapSearch.isEmpty ||
                        s.description.contains(scrapSearch)),
              )
              .toList();
          final scrapValue = scrapFiltered.any((s) => s.id == selectedScrapId)
              ? selectedScrapId
              : null;
          ScrapItemModel? sc;
          if (selectedScrapId != null) {
            final m = erp.scrapItems
                .where((s) => s.id == selectedScrapId)
                .toList();
            sc = m.isEmpty ? null : m.first;
          }
          final servicesFiltered = erp.services
              .where(
                (s) => serviceSearch.isEmpty || s.name.contains(serviceSearch),
              )
              .toList();
          final double l = double.tryParse(lenCtrl.text) ?? 0.0;
          final double w = double.tryParse(widCtrl.text) ?? 0.0;
          final double h = double.tryParse(heiCtrl.text) ?? 0.0;
          final double q = double.tryParse(qtyCtrl.text) ?? 0.0;
          final double outputMeasure = draftLines
              .where((line) => line.source == 'materials')
              .fold<double>(0, (sum, line) => sum + line.area);
          final double area = lineSource == 'materials'
              ? lineArea(ws, l, w, h, q)
              : q;

          double draftedFor(String id) => draftLines
              .where((e) => e.stockId == id)
              .fold(0.0, (s, e) => s + e.area);

          return Dialog(
            child: Container(
              width: 760,
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      complexity == 'بسيط'
                          ? 'إضافة تفصيل بسيط جديد'
                          : 'إضافة تفصيل معقد جديد',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontSize: 18),
                    ),
                    const Divider(height: 20),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اسم التفصيل',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const SizedBox(height: 16),
                    const Text(
                      'بنود المواد (أضف كل بند بزر +):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (allowScrap) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setSt(() {
                                lineSource = 'materials';
                                selectedScrapId = null;
                              }),
                              child: Row(
                                children: [
                                  Radio<String>(
                                    value: 'materials',
                                    groupValue: lineSource,
                                    onChanged: (v) =>
                                        setSt(() => lineSource = v!),
                                  ),
                                  const Text('من المواد'),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setSt(() {
                                lineSource = 'scrap';
                                selectedStockId = null;
                              }),
                              child: Row(
                                children: [
                                  Radio<String>(
                                    value: 'scrap',
                                    groupValue: lineSource,
                                    onChanged: (v) =>
                                        setSt(() => lineSource = v!),
                                  ),
                                  const Text('من الزيادة/الخردة'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (lineSource == 'materials') ...[
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'بحث مادة المعمل...',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                        ),
                        onChanged: (v) => setSt(() => stockSearch = v.trim()),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: stockValue,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'نوع الأمتار المستخدمة',
                        ),
                        items: stockFiltered
                            .map(
                              (s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(
                                  '${s.typeName} ${s.grade} ${s.thicknessCm}سم (${s.category}) — المتاح: ${s.availableQty}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setSt(() => selectedStockId = v),
                      ),
                    ] else ...[
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'بحث قطعة زائدة...',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                        ),
                        onChanged: (v) => setSt(() => scrapSearch = v.trim()),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: scrapValue,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'قطعة الزيادة المستخدمة',
                        ),
                        items: scrapFiltered
                            .map(
                              (s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(
                                  '${s.description} — بيع ${s.sellingPrice}\$',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setSt(() => selectedScrapId = v),
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (lineSource == 'materials' && ws != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: lenCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'الطول (سم)',
                                isDense: true,
                              ),
                              onChanged: (_) => setSt(() => formError = null),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: widCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'العرض (سم)',
                                isDense: true,
                              ),
                              onChanged: (_) => setSt(() => formError = null),
                            ),
                          ),
                          if (wsCube) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: heiCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'الارتفاع (سم)',
                                  isDense: true,
                                ),
                                onChanged: (_) => setSt(() => formError = null),
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: qtyCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'الكمية',
                                isDense: true,
                              ),
                              onChanged: (_) => setSt(() => formError = null),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.chipBgBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'التكلفة الصافية للمتر: ${ws.netCostPerUnit}\$ • سعر البيع المقترح: ${ws.recommendedSalePrice}\$ • مساحة البند: ${area.fmt}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    if (lineSource == 'materials' && ws != null) ...[
                      const SizedBox(height: 6),
                      Builder(
                        builder: (context) {
                          final selectedStock = ws!;
                          final alreadyAllocated = draftedFor(selectedStock.id);
                          final remaining =
                              selectedStock.availableQty - alreadyAllocated;
                          final exceedsStock = area > remaining + 0.0001;
                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: exceedsStock
                                  ? AppColors.dangerWaste.withValues(
                                      alpha: 0.10,
                                    )
                                  : AppColors.chipBgBlue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'استهلاك المادة المحددة: ${area.fmt} ${selectedStock.category == 'متر مكعب' ? 'م³' : 'م²'} • سبق تخصيصه: ${alreadyAllocated.fmt} • المتاح: ${selectedStock.availableQty.fmt} • المتبقي بعد هذا البند: ${(remaining - area).fmt}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.accentPrimary,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    if (lineSource == 'scrap' && sc != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: qtyCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'عدد وحدات الخردة',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.chipBgBlue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'التكلفة: ${sc.baseCost}\$ • البيع: ${sc.sellingPrice}\$',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accentPrimary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: sellMeterCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'سعر البيع للمتر (\$)',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: laborCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'أجر المتر (\$)',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.panelBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'خدمات ملحقة بهذا البند:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'بحث خدمة...',
                              prefixIcon: Icon(Icons.search),
                              isDense: true,
                            ),
                            onChanged: (v) =>
                                setSt(() => serviceSearch = v.trim()),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue:
                                servicesFiltered.any(
                                  (s) => s.id == selectedServiceId,
                                )
                                ? selectedServiceId
                                : null,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'الخدمة',
                              isDense: true,
                            ),
                            items: servicesFiltered
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s.id,
                                    child: Text('${s.name} (${s.unitRate}\$)'),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setSt(() => selectedServiceId = v),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: servicePriceCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'سعر الخدمة (\$)',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: serviceNotesCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'وصف الخدمة',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  if (selectedServiceId == null) {
                                    return;
                                  }
                                  final price =
                                      double.tryParse(servicePriceCtrl.text) ??
                                      0.0;
                                  if (price <= 0) return;
                                  final srv = erp.services.firstWhere(
                                    (s) => s.id == selectedServiceId,
                                  );
                                  setSt(() {
                                    draftServices.add(
                                      ServiceAttachment(
                                        serviceName: srv.name,
                                        price: price,
                                        notes: serviceNotesCtrl.text,
                                      ),
                                    );
                                    selectedServiceId = null;
                                    servicePriceCtrl.clear();
                                    serviceNotesCtrl.clear();
                                  });
                                },
                                child: const Text('إرفاق +'),
                              ),
                            ],
                          ),
                          if (draftServices.isNotEmpty)
                            ...draftServices.asMap().entries.map(
                              (e) => Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '• ${e.value.serviceName}: ${e.value.price}\$',
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: AppColors.dangerWaste,
                                    ),
                                    onPressed: () => setSt(
                                      () => draftServices.removeAt(e.key),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (lineSource == 'materials') {
                            final stock = ws;
                            if (stock == null) {
                              setSt(() => formError = 'اختر المادة أولاً.');
                              return;
                            }
                            if (area <= 0) {
                              setSt(
                                () => formError = 'أدخل أبعاداً وكمية صحيحة.',
                              );
                              return;
                            }
                            final available =
                                stock.availableQty - draftedFor(stock.id);
                            if (area > available + 0.0001) {
                              setSt(
                                () => formError =
                                    'الكمية تتجاوز المتاح (${available.fmt}).',
                              );
                              return;
                            }
                            final existingMaterialLines = draftLines
                                .where((line) => line.source == 'materials')
                                .toList();
                            if (existingMaterialLines.isNotEmpty &&
                                existingMaterialLines.first.category !=
                                    stock.category) {
                              setSt(
                                () => formError =
                                    'يجب أن تكون وحدة قياس مواد التفصيل متوافقة.',
                              );
                              return;
                            }
                            final sell =
                                double.tryParse(sellMeterCtrl.text) ??
                                stock.recommendedSalePrice;
                            final labor =
                                double.tryParse(laborCtrl.text) ?? 0.0;
                            setSt(() {
                              formError = null;
                              if (existingMaterialLines.isEmpty) {
                                productUnit = stock.category;
                              }
                              draftLines.add(
                                TailoringLineItem(
                                  id: 'tl_${DateTime.now().millisecondsSinceEpoch}_${draftLines.length}',
                                  source: 'materials',
                                  stockId: stock.id,
                                  typeName: stock.typeName,
                                  grade: stock.grade,
                                  thicknessCm: stock.thicknessCm,
                                  category: stock.category,
                                  lengthCm: l,
                                  widthCm: w,
                                  heightCm: wsCube ? h : 0.0,
                                  quantity: q,
                                  netCostPerMeter: stock.netCostPerUnit,
                                  sellingPricePerMeter: sell,
                                  laborPerMeter: labor,
                                  services: List.of(draftServices),
                                ),
                              );
                              draftServices.clear();
                              selectedStockId = null;
                              lenCtrl.clear();
                              widCtrl.clear();
                              heiCtrl.clear();
                              qtyCtrl.clear();
                              sellMeterCtrl.clear();
                              laborCtrl.clear();
                            });
                          } else {
                            final captured = sc;
                            if (captured == null) {
                              setSt(
                                () => formError = 'اختر قطعة الزيادة أولاً.',
                              );
                              return;
                            }
                            if (q <= 0) {
                              setSt(() => formError = 'أدخل كمية صحيحة.');
                              return;
                            }
                            final sell =
                                double.tryParse(sellMeterCtrl.text) ??
                                captured.sellingPrice;
                            final labor =
                                double.tryParse(laborCtrl.text) ?? 0.0;
                            setSt(() {
                              formError = null;
                              draftLines.add(
                                TailoringLineItem(
                                  id: 'tl_${DateTime.now().millisecondsSinceEpoch}_${draftLines.length}',
                                  source: 'scrap',
                                  stockId: captured.id,
                                  typeName: captured.description,
                                  grade: '',
                                  thicknessCm: 0.0,
                                  category: 'متر مربع',
                                  quantity: q,
                                  netCostPerMeter: captured.baseCost,
                                  sellingPricePerMeter: sell,
                                  laborPerMeter: labor,
                                  services: List.of(draftServices),
                                ),
                              );
                              draftServices.clear();
                              selectedScrapId = null;
                              qtyCtrl.clear();
                              sellMeterCtrl.clear();
                              laborCtrl.clear();
                            });
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة بند المواد +'),
                      ),
                    ),
                    if (formError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        formError!,
                        style: const TextStyle(
                          color: AppColors.dangerWaste,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    ...draftLines.asMap().entries.map((e) {
                      final li = e.value;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          dense: true,
                          title: Text(
                            '${li.typeName} ${li.grade} (${li.source == 'scrap' ? 'خردة' : li.category})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            'الاستهلاك: ${li.area.fmt} ${li.category == 'متر مكعب' ? 'م³' : 'م²'} • أجر/متر: ${li.laborPerMeter}\$ • خدمات: ${li.servicesTotal.fmt}\$',
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.dangerWaste,
                            ),
                            onPressed: () =>
                                setSt(() => draftLines.removeAt(e.key)),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: complexity == 'بسيط'
                            ? AppColors.accentPrimary
                            : AppColors.partnersEquityAccent,
                      ),
                      onPressed: () {
                        if (nameCtrl.text.isEmpty) {
                          setSt(() => formError = 'أدخل اسم التفصيل.');
                          return;
                        }
                        if (outputMeasure <= 0) {
                          setSt(
                            () => formError =
                                'أضف بند مواد بأبعاد وكمية صحيحة لحساب المتر المربع أو المكعب.',
                          );
                          return;
                        }
                        if (draftLines.isEmpty) {
                          setSt(
                            () =>
                                formError = 'أضف بنداً واحداً على الأقل بزر +.',
                          );
                          return;
                        }
                        final selling =
                            draftLines.fold<double>(
                              0.0,
                              (sum, line) => sum + line.lineTotal,
                            ) /
                            outputMeasure;
                        // Commit stock: deduct materials, consume scrap.
                        for (final li in draftLines) {
                          if (li.source == 'materials') {
                            final ok = erp.deductWorkshopStock(
                              li.stockId,
                              li.area,
                            );
                            if (!ok) {
                              setSt(
                                () => formError =
                                    'نقص في مخزون ${li.typeName}. راجع الكميات.',
                              );
                              return;
                            }
                          } else {
                            final m = erp.scrapItems
                                .where((s) => s.id == li.stockId)
                                .toList();
                            if (m.isNotEmpty) {
                              m.first.isSold = true;
                            }
                          }
                        }
                        final isGranite = draftLines.any(
                          (li) => li.typeName.contains('غرانيت'),
                        );
                        final model = WorkshopTailoringModel(
                          id: '${complexity == 'بسيط' ? 'st' : 'ct'}_${DateTime.now().millisecondsSinceEpoch}',
                          name: nameCtrl.text,
                          complexity: complexity,
                          rawMaterialDescription: draftLines
                              .map((li) => '${li.typeName} ${li.grade}')
                              .join(' + '),
                          lengthCm: 0,
                          widthCm: 0,
                          heightCm: 0,
                          unitCategory: productUnit,
                          measurementCount: 1,
                          quantity: outputMeasure,
                          materialNetCost: 0,
                          laborCostPerMeter: 0.0,
                          attachedServices: const [],
                          lineItems: List.of(draftLines),
                          photoPath: '',
                          sellingPrice: selling,
                          isGranite: isGranite,
                        );
                        if (complexity == 'بسيط') {
                          erp.simpleTailorings.add(model);
                        } else {
                          erp.complexTailorings.add(model);
                        }
                        erp.refresh();
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'تم حفظ التفصيل بكمية ${outputMeasure.fmt} ${productUnit == 'متر مكعب' ? 'م³' : 'م²'} وخصم استهلاك المواد من المخزون.',
                            ),
                            backgroundColor: AppColors.successGreen,
                          ),
                        );
                      },
                      child: const Text('حفظ التفصيل بالمتر'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddScrapItemDialog(ERPProvider erp) {
    final descCtrl = TextEditingController();
    final costCtrl = TextEditingController(text: '');
    final priceCtrl = TextEditingController(text: '45');
    final photoCtrl = TextEditingController();
    final List<_SurplusCostDraft> drafts = [];
    String? formError;
    String scrapCurrency = AppCurrency.usd;

    double parseCost() => double.tryParse(costCtrl.text.trim()) ?? 0.0;
    double allocatedSum() {
      double s = 0.0;
      for (final d in drafts) {
        s += double.tryParse(d.amountCtrl.text.trim()) ?? 0.0;
      }
      return s;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final baseCost = parseCost();
          final allocated = allocatedSum();
          final remaining = baseCost - allocated;
          return Dialog(
            child: Container(
              width: 600,
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'إضافة قطعة زائدة لخردة المعمل',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'السعر الأولي 0/فارغ = هامش ربح 100%. أي سعر أولي > 0 يجب توزيعه على أشخاص/مصاريف تُسجَّل في مالية الزيادات وتُدفع من صندوق الزيادات.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.brandSecondaryText,
                      ),
                    ),
                    const Divider(height: 20),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'وصف ومقاس القطعة الزائدة',
                      ),
                    ),
                    const SizedBox(height: 8),
                    CurrencySelector(
                      value: scrapCurrency,
                      dense: true,
                      onChanged: (v) => setSt(() => scrapCurrency = v),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: costCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText:
                                  'السعر الأولي / التكلفة (${AppCurrency.symbol(scrapCurrency)}) — فارغ = 0',
                            ),
                            onChanged: (_) => setSt(() => formError = null),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: priceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText:
                                  'سعر البيع المعروض (${AppCurrency.symbol(scrapCurrency)})',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: photoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'صورة القطعة (مسار — اختياري)',
                        prefixIcon: Icon(Icons.attach_file_rounded),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (baseCost <= 0)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.chipBgGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'هامش ربح 100%: لا توجد تكاليف لهذه القطعة ولن يُطلب أي تفصيل.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.scrapBoxAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (baseCost > 0) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.chipBgAmber,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.partnersEquityAccent,
                          ),
                        ),
                        child: Text(
                          'وزّع السعر الأولي (${baseCost.fmt}\$) على أجور/مصاريف. الموزع: ${allocated.fmt}\$ • المتبقي: ${remaining.fmt}\$',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...drafts.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final d = entry.value;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        initialValue: d.kind,
                                        decoration: const InputDecoration(
                                          labelText: 'النوع',
                                          isDense: true,
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'worker',
                                            child: Text('أجرة عامل/شخص'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'expense',
                                            child: Text(
                                              'مصروف (مواد/كهرباء/ماء...)',
                                            ),
                                          ),
                                        ],
                                        onChanged: (v) =>
                                            setSt(() => d.kind = v!),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'حذف البند',
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: AppColors.dangerWaste,
                                      ),
                                      onPressed: () =>
                                          setSt(() => drafts.removeAt(idx)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (d.kind == 'worker' &&
                                    erp.staffList.isNotEmpty)
                                  DropdownButtonFormField<String>(
                                    initialValue: d.staffId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'ربط بعامل مسجل (اختياري)',
                                      isDense: true,
                                    ),
                                    items: [
                                      const DropdownMenuItem(
                                        value: null,
                                        child: Text('— شخص خارجي —'),
                                      ),
                                      ...erp.staffList.map(
                                        (s) => DropdownMenuItem(
                                          value: s.id,
                                          child: Text(s.name),
                                        ),
                                      ),
                                    ],
                                    onChanged: (v) => setSt(() {
                                      d.staffId = v;
                                      if (v != null &&
                                          d.nameCtrl.text.trim().isEmpty) {
                                        d.nameCtrl.text = erp.staffList
                                            .firstWhere((e) => e.id == v)
                                            .name;
                                      }
                                    }),
                                  ),
                                if (d.kind == 'worker' &&
                                    erp.staffList.isNotEmpty)
                                  const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: TextField(
                                        controller: d.nameCtrl,
                                        decoration: InputDecoration(
                                          labelText: d.kind == 'worker'
                                              ? 'اسم الشخص'
                                              : 'بيان المصروف',
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: TextField(
                                        controller: d.amountCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'المبلغ (\$)',
                                          isDense: true,
                                        ),
                                        onChanged: (_) => setSt(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => setSt(
                                () => drafts.add(
                                  _SurplusCostDraft(kind: 'worker'),
                                ),
                              ),
                              icon: const Icon(
                                Icons.person_add_rounded,
                                size: 18,
                              ),
                              label: const Text('إضافة شخص/عامل'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => setSt(
                                () => drafts.add(
                                  _SurplusCostDraft(kind: 'expense'),
                                ),
                              ),
                              icon: const Icon(
                                Icons.receipt_long_rounded,
                                size: 18,
                              ),
                              label: const Text('إضافة مصروف'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'تُدفع هذه البنود لاحقاً من صندوق الزيادات (رصيده: ${erp.surplusFundBalance.fmt}\$) عبر مالية الزيادات.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.brandSecondaryText,
                        ),
                      ),
                    ],
                    if (formError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        formError!,
                        style: const TextStyle(
                          color: AppColors.dangerWaste,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('إلغاء'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.scrapBoxAccent,
                          ),
                          onPressed: () {
                            final desc = descCtrl.text.trim();
                            if (desc.isEmpty) {
                              setSt(
                                () => formError = 'أدخل وصف القطعة الزائدة.',
                              );
                              return;
                            }
                            if (baseCost < 0) {
                              setSt(
                                () => formError =
                                    'السعر الأولي لا يمكن أن يكون سالباً.',
                              );
                              return;
                            }
                            if (baseCost > 0.01) {
                              if (drafts.isEmpty) {
                                setSt(
                                  () => formError =
                                      'يوجد سعر أولي (${baseCost.fmt}\$) — أضف شخصاً أو مصروفاً واحداً على الأقل يفسّر هذا المبلغ.',
                                );
                                return;
                              }
                              if (remaining.abs() > 0.01) {
                                setSt(
                                  () => formError =
                                      'مجموع البنود (${allocated.fmt}\$) يجب أن يساوي السعر الأولي (${baseCost.fmt}\$).',
                                );
                                return;
                              }
                              for (final d in drafts) {
                                final amt =
                                    double.tryParse(d.amountCtrl.text.trim()) ??
                                    0.0;
                                if (d.nameCtrl.text.trim().isEmpty ||
                                    amt <= 0) {
                                  setSt(
                                    () => formError =
                                        'أكمل اسم ومبلغ كل بند (مبلغ > 0).',
                                  );
                                  return;
                                }
                              }
                            }
                            final itemId =
                                'sc_${DateTime.now().millisecondsSinceEpoch}';
                            final item = ScrapItemModel(
                              id: itemId,
                              description: desc,
                              baseCost: baseCost,
                              sellingPrice:
                                  double.tryParse(priceCtrl.text.trim()) ?? 0.0,
                              photoPath: photoCtrl.text.trim(),
                              currency: scrapCurrency,
                            );
                            if (baseCost <= 0.01) {
                              // 100% margin — no ledger rows.
                              erp.addScrapItem(item);
                            } else {
                              erp.addScrapItemWithCosts(
                                item,
                                drafts
                                    .map(
                                      (d) => SurplusCostModel(
                                        id: 'sxc_${DateTime.now().millisecondsSinceEpoch}_${drafts.indexOf(d)}',
                                        surplusItemId: itemId,
                                        surplusDescription: desc,
                                        kind: d.kind,
                                        beneficiaryName: d.nameCtrl.text.trim(),
                                        staffId: d.staffId,
                                        amountDue:
                                            double.tryParse(
                                              d.amountCtrl.text.trim(),
                                            ) ??
                                            0.0,
                                      ),
                                    )
                                    .toList(),
                              );
                            }
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'تمت إضافة القطعة الزائدة مع تفصيل التكلفة.',
                                ),
                                backgroundColor: AppColors.successGreen,
                              ),
                            );
                          },
                          child: const Text('إضافة للزيادات'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddWasteLogDialog(ERPProvider erp) {
    String type = 'هدر طبيعي';
    final descCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final costCtrl = TextEditingController(text: '50');
    final vouchCtrl = TextEditingController();
    String? formError;
    String wasteCurrency = AppCurrency.usd;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('إضافة قيد هدر جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: type,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: 'هدر طبيعي',
                    child: Text('هدر طبيعي'),
                  ),
                  DropdownMenuItem(
                    value: 'هدر غير طبيعي',
                    child: Text('هدر غير طبيعي (يتطلب سند إتلاف)'),
                  ),
                ],
                onChanged: (v) => setSt(() => type = v!),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'وصف سبب الهدر'),
              ),
              const SizedBox(height: 8),
              CurrencySelector(
                value: wasteCurrency,
                dense: true,
                onChanged: (v) => setSt(() => wasteCurrency = v),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'الكمية المهدرة',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: costCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText:
                            'التكلفة الإجمالية (${AppCurrency.symbol(wasteCurrency)})',
                      ),
                    ),
                  ),
                ],
              ),
              if (type == 'هدر غير طبيعي') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: vouchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'رقم سند الإتلاف الرسمي (إلزامي — يُحتسب خسارة)',
                  ),
                ),
              ],
              if (formError != null) ...[
                const SizedBox(height: 8),
                Text(
                  formError!,
                  style: const TextStyle(
                    color: AppColors.dangerWaste,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (type == 'هدر غير طبيعي' && vouchCtrl.text.trim().isEmpty) {
                  setSt(
                    () => formError =
                        'الهدر غير الطبيعي يتطلب رقم سند إتلاف ويُحتسب خسارة.',
                  );
                  return;
                }
                erp.addWasteLog(
                  WasteLogModel(
                    id: 'wl_${DateTime.now().millisecondsSinceEpoch}',
                    date: DateTime.now(),
                    wasteType: type,
                    itemDescription: descCtrl.text,
                    quantity: double.tryParse(qtyCtrl.text) ?? 1.0,
                    cost: double.tryParse(costCtrl.text) ?? 0.0,
                    destructionVoucherNo: vouchCtrl.text,
                    currency: wasteCurrency,
                  ),
                );
                Navigator.pop(ctx);
              },
              child: const Text('تسجيل الهدر'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddOrderDialog(ERPProvider erp) {
    final nameCtrl = TextEditingController(text: 'المهندس كريم السعيد');
    final phoneCtrl = TextEditingController(text: '0933998877');
    final textCtrl = TextEditingController(
      text: 'مغسلتين غرانيت روزا مع شطف حواف دبل وتفريغ ثقوب',
    );
    final priceCtrl = TextEditingController(text: '650');
    final depositCtrl = TextEditingController(text: '250');
    final photoCtrl = TextEditingController();
    String orderCurrency = AppCurrency.usd;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Dialog(
          child: Container(
            width: 520,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'إضافة طلبية معمل جديدة (عربون في صندوق الطلبيات)',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'الفاتورة الناتجة عن هذه الطلبية ترث عملتها مباشرة.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.brandSecondaryText,
                    ),
                  ),
                  const Divider(height: 20),
                  CurrencySelector(
                    value: orderCurrency,
                    dense: true,
                    onChanged: (v) => setSt(() => orderCurrency = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'اسم الزبون'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: textCtrl,
                    decoration: const InputDecoration(
                      labelText: 'وصف المقاسات والطلبية المخصصة',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText:
                                'السعر الاتفاقي النهائي (${AppCurrency.symbol(orderCurrency)})',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: depositCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText:
                                'مبلغ العربون / الدفعة الأولى (${AppCurrency.symbol(orderCurrency)})',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: photoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'صورة الطلبية (مسار — اختياري)',
                      prefixIcon: Icon(Icons.attach_file_rounded),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'العربون غير قابل للاسترداد إلا في حالات خاصة.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.brandSecondaryText,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orderDepositBoxAccent,
                    ),
                    onPressed: () {
                      erp.createWorkshopOrder(
                        WorkshopOrderModel(
                          id: 'wo_${DateTime.now().millisecondsSinceEpoch}',
                          orderNo: 'ORD-${erp.workshopOrders.length + 101}',
                          date: DateTime.now(),
                          clientName: nameCtrl.text,
                          clientPhone: phoneCtrl.text,
                          customDimensionsText: textCtrl.text,
                          agreedPrice: double.tryParse(priceCtrl.text) ?? 0.0,
                          depositAmount:
                              double.tryParse(depositCtrl.text) ?? 0.0,
                          photoPath: photoCtrl.text.trim(),
                          currency: orderCurrency,
                        ),
                      );
                      Navigator.pop(ctx);
                    },
                    child: const Text('تأكيد الطلبية وإيداع العربون'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Cancel rules: deposit is non-refundable (kept as profit) except in
  /// special cases (refunded). A kept-deposit order can be converted into a
  /// ready tailored piece.
  void _showCancelOrderDialog(ERPProvider erp, WorkshopOrderModel ord) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الطلبية'),
        content: const Text(
          'العربون غير قابل للاسترداد ويُحتسب ربحاً، إلا في الحالات الخاصة حيث يُرد للزبون.\nاختر طريقة الإلغاء:',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('تراجع'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerWaste,
            ),
            onPressed: () {
              erp.cancelWorkshopOrder(ord, false);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'تم إلغاء الطلبية وتثبيت العربون كأرباح محتفظ بها!',
                  ),
                ),
              );
            },
            child: const Text('إلغاء مع الاحتفاظ بالعربون'),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.dangerWaste,
            ),
            onPressed: () {
              erp.cancelWorkshopOrder(ord, true);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم إلغاء الطلبية ورد العربون (حالة خاصة).'),
                ),
              );
            },
            child: const Text('إلغاء مع رد العربون (خاص)'),
          ),
          TextButton.icon(
            onPressed: () {
              erp.cancelWorkshopOrder(ord, false);
              erp.convertCancelledOrderToTailoring(ord);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'تم تحويل القطعة الجاهزة إلى التفصيلات وتثبيت العربون ربحاً.',
                  ),
                  backgroundColor: AppColors.successGreen,
                ),
              );
            },
            icon: const Icon(Icons.handyman_outlined),
            label: const Text('إلغاء + تحويل لقطعة مفصلة جاهزة'),
          ),
        ],
      ),
    );
  }

  /// Workshop invoice builder — assignment happens from the invoice side.
  /// Sources: order / simple / complex / scrap / raw materials, each with
  /// services. Assigning an order copies all its fields (incl. image) into
  /// editable invoice fields.
  void _showAddWorkshopInvoiceDialog(
    ERPProvider erp, {
    String? presetProjectId,
    String? presetClientName,
    bool cashInvoice = false,
  }) {
    String sourceType = 'طلبية معمل';
    String? selectedRecordId;
    String recordSearch = '';
    final clientCtrl = TextEditingController(text: presetClientName ?? '');
    final descCtrl = TextEditingController();
    final agreedCtrl = TextEditingController();
    final tailoringQtyCtrl = TextEditingController(text: '1');
    final salesDiscountCtrl = TextEditingController(text: '0');
    final depositCtrl = TextEditingController();
    final cashCtrl = TextEditingController();
    final netCtrl = TextEditingController();
    final photoCtrl = TextEditingController();
    String? formError;

    // Raw-material source fields.
    String? selectedRawId;
    String rawSearch = '';
    final lenCtrl = TextEditingController();
    final widCtrl = TextEditingController();
    final heiCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    // Services attached to this invoice.
    String? selectedServiceId;
    String serviceSearch = '';
    final servicePriceCtrl = TextEditingController();
    final serviceNotesCtrl = TextEditingController();
    final List<ServiceAttachment> draftServices = [];
    String invCurrency = AppCurrency.usd;

    List<Map<String, String>> records() {
      switch (sourceType) {
        case 'طلبية معمل':
          return erp.workshopOrders
              .where((o) => o.status == 'قيد التنفيذ')
              .map(
                (o) => {'id': o.id, 'label': '${o.orderNo} • ${o.clientName}'},
              )
              .toList();
        case 'تفصيل بسيط':
          return erp.simpleTailorings
              .where((t) => t.quantity > 0)
              .map(
                (t) => {
                  'id': t.id,
                  'label':
                      '${t.name} • المتاح ${t.quantity.fmt} ${t.unitSymbol}',
                },
              )
              .toList();
        case 'تفصيل معقد':
          return erp.complexTailorings
              .where((t) => t.quantity > 0)
              .map(
                (t) => {
                  'id': t.id,
                  'label':
                      '${t.name} • المتاح ${t.quantity.fmt} ${t.unitSymbol}',
                },
              )
              .toList();
        case 'قطع زائدة':
          return erp.scrapItems
              .where((s) => !s.isSold)
              .map((s) => {'id': s.id, 'label': s.description})
              .toList();
        default:
          return [];
      }
    }

    void prefillFromRecord(void Function(void Function()) setSt) {
      if (selectedRecordId == null) return;
      if (sourceType == 'طلبية معمل') {
        final m = erp.workshopOrders
            .where((o) => o.id == selectedRecordId)
            .toList();
        if (m.isEmpty) return;
        final o = m.first;
        invCurrency = o.currency;
        clientCtrl.text = o.clientName;
        descCtrl.text = o.customDimensionsText;
        agreedCtrl.text = o.agreedPrice.fmt;
        depositCtrl.text = o.depositAmount.fmt;
        cashCtrl.text = (o.agreedPrice - o.depositAmount)
            .clamp(0.0, double.infinity)
            .fmt;
        netCtrl.text = (o.agreedPrice * 0.60).fmt;
        photoCtrl.text = o.photoPath;
      } else if (sourceType == 'تفصيل بسيط' || sourceType == 'تفصيل معقد') {
        final all = [...erp.simpleTailorings, ...erp.complexTailorings];
        final m = all.where((t) => t.id == selectedRecordId).toList();
        if (m.isEmpty) return;
        final t = m.first;
        descCtrl.text = t.name;
        agreedCtrl.text = t.sellingPrice.fmt;
        tailoringQtyCtrl.text = (t.quantity < 1 ? t.quantity : 1).fmt;
        depositCtrl.text = '0';
        cashCtrl.text =
            (t.sellingPrice * (double.tryParse(tailoringQtyCtrl.text) ?? 0))
                .fmt;
        netCtrl.text =
            (t.quantity > 0
                    ? t.totalNetCost /
                          t.quantity *
                          (double.tryParse(tailoringQtyCtrl.text) ?? 0)
                    : 0)
                .fmt;
        photoCtrl.text = t.photoPath;
      } else if (sourceType == 'قطع زائدة') {
        final m = erp.scrapItems
            .where((s) => s.id == selectedRecordId)
            .toList();
        if (m.isEmpty) return;
        final s = m.first;
        invCurrency = s.currency;
        descCtrl.text = s.description;
        agreedCtrl.text = s.sellingPrice.fmt;
        depositCtrl.text = '0';
        cashCtrl.text = s.sellingPrice.fmt;
        netCtrl.text = s.baseCost.fmt;
        photoCtrl.text = s.photoPath;
      }
      setSt(() {});
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final recs = records()
              .where(
                (r) =>
                    recordSearch.isEmpty || r['label']!.contains(recordSearch),
              )
              .toList();
          final recValue = recs.any((r) => r['id'] == selectedRecordId)
              ? selectedRecordId
              : null;

          WorkshopStockModel? raw;
          if (selectedRawId != null) {
            final m = erp.workshopStock
                .where((w) => w.id == selectedRawId)
                .toList();
            raw = m.isEmpty ? null : m.first;
          }
          final rawFiltered = erp.workshopStock
              .where(
                (w) =>
                    rawSearch.isEmpty ||
                    '${w.typeName} ${w.grade}'.contains(rawSearch),
              )
              .toList();
          final rawValue = rawFiltered.any((w) => w.id == selectedRawId)
              ? selectedRawId
              : null;
          final bool rawCube = raw?.category == 'متر مكعب';
          final double rl = double.tryParse(lenCtrl.text) ?? 0.0;
          final double rw = double.tryParse(widCtrl.text) ?? 0.0;
          final double rh = double.tryParse(heiCtrl.text) ?? 0.0;
          final double rq = double.tryParse(qtyCtrl.text) ?? 0.0;
          final double rp = double.tryParse(priceCtrl.text) ?? 0.0;
          double rawArea = 0.0;
          if (raw != null && rl > 0 && rw > 0 && rq > 0) {
            rawArea = rawCube && rh > 0
                ? (rl / 100.0) * (rw / 100.0) * (rh / 100.0) * rq
                : (rl / 100.0) * (rw / 100.0) * rq;
          }

          final servicesFiltered = erp.services
              .where(
                (s) => serviceSearch.isEmpty || s.name.contains(serviceSearch),
              )
              .toList();
          final serviceValue =
              servicesFiltered.any((s) => s.id == selectedServiceId)
              ? selectedServiceId
              : null;
          final double servicesTotal = draftServices.fold(
            0.0,
            (s, e) => s + e.price,
          );
          final double agreed = double.tryParse(agreedCtrl.text) ?? 0.0;
          final bool tailoredSource =
              sourceType == 'تفصيل بسيط' || sourceType == 'تفصيل معقد';
          final double tailoringQuantity =
              double.tryParse(tailoringQtyCtrl.text) ?? 0.0;
          final double agreedTotal = tailoredSource
              ? agreed * tailoringQuantity
              : agreed;
          final tailoredItems = sourceType == 'تفصيل بسيط'
              ? erp.simpleTailorings
              : erp.complexTailorings;
          final tailoredMatches = tailoredSource
              ? tailoredItems
                    .where((item) => item.id == selectedRecordId)
                    .toList()
              : <WorkshopTailoringModel>[];
          final selectedTailoring = tailoredMatches.isEmpty
              ? null
              : tailoredMatches.first;
          final double salesDiscount =
              double.tryParse(salesDiscountCtrl.text) ?? 0.0;

          return Dialog(
            child: Container(
              width: 720,
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'إنشاء فاتورة معمل',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontSize: 18),
                    ),
                    if (presetProjectId != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.chipBgSky,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.orderDepositBoxAccent,
                          ),
                        ),
                        child: Text(
                          'فاتورة مشروع — ستُرحل تحت المشروع المحدد.',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.orderDepositBoxAccent,
                          ),
                        ),
                      ),
                    ],
                    const Divider(height: 20),
                    const Text(
                      '1. مصدر الفاتورة:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: sourceType,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'طلبية معمل',
                          child: Text('إسناد طلبية'),
                        ),
                        DropdownMenuItem(
                          value: 'تفصيل بسيط',
                          child: Text('شراء تفصيل بسيط'),
                        ),
                        DropdownMenuItem(
                          value: 'تفصيل معقد',
                          child: Text('شراء تفصيل معقد'),
                        ),
                        DropdownMenuItem(
                          value: 'قطع زائدة',
                          child: Text('بيع قطعة زائدة'),
                        ),
                        DropdownMenuItem(
                          value: 'مواد خام',
                          child: Text('بيع مواد خام'),
                        ),
                      ],
                      onChanged: (v) => setSt(() {
                        sourceType = v!;
                        selectedRecordId = null;
                        selectedRawId = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    if (sourceType == 'مواد خام') ...[
                      const Text(
                        'اختر المادة الخام من المعمل:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'بحث مادة...',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                        ),
                        onChanged: (v) => setSt(() => rawSearch = v.trim()),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: rawValue,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'المادة'),
                        items: rawFiltered
                            .map(
                              (w) => DropdownMenuItem(
                                value: w.id,
                                child: Text(
                                  '${w.typeName} ${w.grade} — المتاح: ${w.availableQty}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setSt(() => selectedRawId = v),
                      ),
                      if (raw != null) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: salesDiscountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'خصم المبيعات المسموح (اختياري)',
                          ),
                          onChanged: (_) => setSt(() {}),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: lenCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'الطول (سم)',
                                  isDense: true,
                                ),
                                onChanged: (_) => setSt(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: widCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'العرض (سم)',
                                  isDense: true,
                                ),
                                onChanged: (_) => setSt(() {}),
                              ),
                            ),
                            if (rawCube) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: heiCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'الارتفاع (سم)',
                                    isDense: true,
                                  ),
                                  onChanged: (_) => setSt(() {}),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: qtyCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'الكمية',
                                  isDense: true,
                                ),
                                onChanged: (_) => setSt(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: priceCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'سعر الوحدة (\$)',
                                  isDense: true,
                                ),
                                onChanged: (_) => setSt(() {
                                  agreedCtrl.text = (rawArea * rp).fmt;
                                  netCtrl.text = raw != null
                                      ? (rawArea * raw.netCostPerUnit).fmt
                                      : netCtrl.text;
                                }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'الكمية المحسوبة: ${rawArea.fmt} • المتاح: ${raw.availableQty}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ] else ...[
                      const Text(
                        'اختر السجل للإسناد (تُنسخ حقوله قابلة للتحرير):',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'بحث...',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                        ),
                        onChanged: (v) => setSt(() => recordSearch = v.trim()),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: recValue,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'السجل'),
                        items: recs
                            .map(
                              (r) => DropdownMenuItem(
                                value: r['id'],
                                child: Text(r['label']!),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setSt(() {
                          selectedRecordId = v;
                          prefillFromRecord(setSt);
                        }),
                      ),
                      if ((sourceType == 'تفصيل بسيط' ||
                              sourceType == 'تفصيل معقد') &&
                          selectedTailoring != null) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: tailoringQtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText:
                                'الكمية المراد بيعها (${selectedTailoring.unitSymbol})',
                            helperText:
                                'المتاح: ${selectedTailoring.quantity.fmt}',
                          ),
                          onChanged: (_) => setSt(() {
                            final item = selectedTailoring;
                            final requested =
                                double.tryParse(tailoringQtyCtrl.text) ?? 0;
                            final total = item.sellingPrice * requested;
                            agreedCtrl.text = item.sellingPrice.fmt;
                            cashCtrl.text = total.fmt;
                            netCtrl.text =
                                (item.quantity > 0
                                        ? item.totalNetCost /
                                              item.quantity *
                                              requested
                                        : 0)
                                    .fmt;
                          }),
                        ),
                      ],
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      '2. حقول الفاتورة (قابلة للتحرير):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if ((sourceType == 'طلبية معمل' ||
                            sourceType == 'قطع زائدة') &&
                        selectedRecordId != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.panelBorder),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              'عملة الفاتورة (من السجل): ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            CurrencyBadge(currency: invCurrency),
                            const SizedBox(width: 6),
                            Text(
                              invCurrency == AppCurrency.syp
                                  ? 'ليرة سورية — تُرحل لصندوق الليرة'
                                  : 'دولار — تُرحل لصندوق الدولار',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: CurrencySelector(
                          value: invCurrency,
                          dense: true,
                          onChanged: (v) => setSt(() => invCurrency = v),
                        ),
                      ),
                    TextField(
                      controller: clientCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اسم الزبون',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'وصف الصنف / البيانات',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: agreedCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: tailoredSource
                                  ? 'سعر البيع للمتر (${selectedTailoring?.unitSymbol ?? 'م²'})'
                                  : 'السعر المتفق (\$)',
                              isDense: true,
                            ),
                            onChanged: (_) => setSt(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: netCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'التكلفة الصافية (\$)',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (cashInvoice)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          sourceType == 'طلبية معمل'
                              ? 'فاتورة نقدية: يُحوّل عربون الطلبية إلى الصندوق الرئيسي ويُحصّل المتبقي نقداً؛ تسوى الفاتورة بالكامل.'
                              : 'فاتورة نقدية: يُحصّل كامل الإجمالي نقداً في الصندوق.',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentPrimary,
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: depositCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'العربون المخصوم (\$)',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: cashCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'النقد المدفوع الآن (\$)',
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: photoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'صورة (مسار — اختياري)',
                        prefixIcon: Icon(Icons.attach_file_rounded),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.panelBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'خدمات مرفقة بالفاتورة:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'بحث خدمة...',
                              prefixIcon: Icon(Icons.search),
                              isDense: true,
                            ),
                            onChanged: (v) =>
                                setSt(() => serviceSearch = v.trim()),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: serviceValue,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'الخدمة',
                              isDense: true,
                            ),
                            items: servicesFiltered
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s.id,
                                    child: Text('${s.name} (${s.unitRate}\$)'),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setSt(() => selectedServiceId = v),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: servicePriceCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'سعر الخدمة (\$)',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: serviceNotesCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'وصف الخدمة',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  if (selectedServiceId == null) {
                                    return;
                                  }
                                  final price =
                                      double.tryParse(servicePriceCtrl.text) ??
                                      0.0;
                                  if (price <= 0) return;
                                  final srv = erp.services.firstWhere(
                                    (s) => s.id == selectedServiceId,
                                  );
                                  setSt(() {
                                    draftServices.add(
                                      ServiceAttachment(
                                        serviceName: srv.name,
                                        price: price,
                                        notes: serviceNotesCtrl.text,
                                      ),
                                    );
                                    selectedServiceId = null;
                                    servicePriceCtrl.clear();
                                    serviceNotesCtrl.clear();
                                  });
                                },
                                child: const Text('إرفاق +'),
                              ),
                            ],
                          ),
                          if (draftServices.isNotEmpty)
                            ...draftServices.asMap().entries.map(
                              (e) => Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '• ${e.value.serviceName}: ${e.value.price}\$',
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: AppColors.dangerWaste,
                                    ),
                                    onPressed: () => setSt(
                                      () => draftServices.removeAt(e.key),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (formError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        formError!,
                        style: const TextStyle(
                          color: AppColors.dangerWaste,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.panelBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: salesDiscountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'خصم المبيعات المسموح (اختياري)',
                              isDense: true,
                            ),
                            onChanged: (_) => setSt(() {}),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'الإجمالي بعد الخصم:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.brandSecondaryText,
                                    ),
                                  ),
                                  Text(
                                    '${(agreedTotal + servicesTotal - salesDiscount).fmt} ${AppCurrency.symbol(invCurrency)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: AppColors.accentPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4F46E5),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                ),
                                onPressed: () {
                                  // Truncate decimals (Ignore cents)
                                  final directAgreed =
                                      double.tryParse(agreedCtrl.text) ?? 0.0;
                                  if (!tailoredSource &&
                                      sourceType != 'مواد خام' &&
                                      (directAgreed -
                                                  directAgreed
                                                      .truncateToDouble())
                                              .abs() >
                                          0.0001) {
                                    agreedCtrl.text =
                                        directAgreed.truncateToDouble().fmt;
                                    if (cashInvoice) {
                                      cashCtrl.text = agreedCtrl.text;
                                    }
                                  } else {
                                    final currentNet = (agreedTotal +
                                            servicesTotal -
                                            salesDiscount)
                                        .clamp(0.0, double.infinity);
                                    final truncated =
                                        currentNet.truncateToDouble();
                                    final diff = currentNet - truncated;
                                    if (diff > 0.0001) {
                                      final newDisc = salesDiscount + diff;
                                      salesDiscountCtrl.text = newDisc.fmt;
                                      if (cashInvoice) {
                                        cashCtrl.text = truncated.fmt;
                                      }
                                    }
                                  }
                                  setSt(() {});
                                },
                                icon: const Icon(
                                  Icons.content_cut_rounded,
                                  size: 16,
                                ),
                                label: const Text(
                                  'تجاهل القروش (Ignore Cents)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentPrimary,
                      ),
                      onPressed: () {
                        if (sourceType != 'مواد خام' &&
                            selectedRecordId == null) {
                          setSt(
                            () => formError = 'اختر السجل المراد إسناده أولاً.',
                          );
                          return;
                        }
                        if (clientCtrl.text.isEmpty ||
                            agreedTotal <= 0 ||
                            (tailoredSource &&
                                (selectedTailoring == null ||
                                    tailoringQuantity <= 0 ||
                                    tailoringQuantity >
                                        selectedTailoring.quantity + 0.0001))) {
                          setSt(
                            () => formError = tailoredSource
                                ? 'تحقق من سعر المتر والكمية المتاحة للبيع.'
                                : 'أدخل اسم الزبون وسعراً صحيحاً.',
                          );
                          return;
                        }
                        if (salesDiscount < 0 ||
                            salesDiscount > agreedTotal + servicesTotal) {
                          setSt(
                            () => formError =
                                'قيمة خصم المبيعات يجب أن تكون بين صفر وإجمالي الفاتورة.',
                          );
                          return;
                        }
                        final invoiceTotal =
                            (agreedTotal + servicesTotal - salesDiscount).clamp(
                              0.0,
                              double.infinity,
                            );
                        final enteredDeposit =
                            double.tryParse(depositCtrl.text) ?? 0.0;
                        final deposit = cashInvoice
                            ? sourceType == 'طلبية معمل'
                                  ? enteredDeposit
                                  : 0.0
                            : enteredDeposit;
                        final cash = cashInvoice
                            ? (invoiceTotal - deposit).clamp(
                                0.0,
                                double.infinity,
                              )
                            : (double.tryParse(cashCtrl.text) ?? 0.0);
                        final net = double.tryParse(netCtrl.text) ?? 0.0;
                        if (deposit < 0 ||
                            cash < 0 ||
                            deposit + cash >
                                agreedTotal +
                                    servicesTotal -
                                    salesDiscount +
                                    0.01) {
                          setSt(
                            () => formError =
                                'إجمالي العربون والنقد لا يمكن أن يتجاوز قيمة الفاتورة بعد الخصم.',
                          );
                          return;
                        }
                        String deductId = '';
                        double deductQty = 0.0;
                        String itemDesc = descCtrl.text;
                        bool granite = false;
                        if (sourceType == 'مواد خام') {
                          if (raw == null || rawArea <= 0) {
                            setSt(
                              () => formError =
                                  'اختر المادة وأدخل أبعاداً صحيحة.',
                            );
                            return;
                          }
                          if (rawArea > raw.availableQty + 0.0001) {
                            setSt(() => formError = 'الكمية تتجاوز المتاح.');
                            return;
                          }
                          deductId = raw.id;
                          deductQty = rawArea;
                          itemDesc =
                              '${raw.typeName} ${raw.grade} ${raw.thicknessCm}سم';
                          granite = raw.isGranite;
                        }
                        final created = erp.createWorkshopInvoice(
                          WorkshopInvoiceModel(
                            id: 'wi_${DateTime.now().millisecondsSinceEpoch}',
                            invoiceNo:
                                'WRK-INV-${erp.workshopInvoices.length + 101}',
                            date: DateTime.now(),
                            clientName: clientCtrl.text,
                            sourceType: sourceType,
                            sourceId: sourceType == 'مواد خام'
                                ? (selectedRawId ?? '')
                                : (selectedRecordId ?? ''),
                            projectId: presetProjectId ?? '',
                            itemDescription: itemDesc,
                            sourceQuantity: tailoredSource
                                ? tailoringQuantity
                                : 1,
                            sourceUnitCategory:
                                selectedTailoring?.unitCategory ?? 'متر مربع',
                            agreedPrice: agreedTotal,
                            depositDeducted: deposit,
                            cashPaidNow: cash,
                            netCost: net,
                            salesDiscount: salesDiscount,
                            services: List.of(draftServices),
                            photoPath: photoCtrl.text.trim(),
                            isGranite: granite,
                            isCashInvoice: cashInvoice,
                            currency: invCurrency,
                          ),
                          deductStockId: deductId,
                          deductQty: deductQty,
                        );
                        if (!created) {
                          setSt(
                            () => formError = cashInvoice
                                ? 'تعذر اعتماد الفاتورة النقدية؛ تحقق من المخزون أو رصيد عربون الطلبية.'
                                : 'المخزون غير كافٍ لإصدار هذه الفاتورة.',
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              cashInvoice
                                  ? 'تم إصدار فاتورة البيع النقدية وتحصيلها بالكامل.'
                                  : sourceType == 'قطع زائدة'
                                  ? 'تم بيع القطعة وترحيل المبلغ إلى صندوق الزيادات.'
                                  : 'تم إصدار فاتورة المعمل بنجاح.',
                            ),
                            backgroundColor: AppColors.successGreen,
                          ),
                        );
                      },
                      child: const Text('إصدار وحفظ الفاتورة'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Draft row for the surplus initial-price breakdown dialog.
class _SurplusCostDraft {
  String kind; // 'worker' | 'expense'
  String? staffId;
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController amountCtrl = TextEditingController();

  _SurplusCostDraft({required this.kind});
}
