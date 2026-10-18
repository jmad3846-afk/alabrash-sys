import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';
import '../widgets/currency_selector.dart';
import '../widgets/thermal_receipt_dialog.dart';
import '../widgets/a4_invoice_print_dialog.dart';
import '../widgets/app_image_attachment.dart';
import 'accounting_screens.dart';

class _TailoringStockOption {
  final String id;
  final String source; // 'factory' or 'workshop'
  final String typeName;
  final String grade;
  final double thicknessCm;
  final String category; // 'متر مربع' or 'متر مكعب'
  final double availableQty;
  final double netCostPerUnit;
  final double recommendedSalePrice;
  final bool isGranite;

  _TailoringStockOption({
    required this.id,
    required this.source,
    required this.typeName,
    required this.grade,
    required this.thicknessCm,
    required this.category,
    required this.availableQty,
    required this.netCostPerUnit,
    required this.recommendedSalePrice,
    this.isGranite = false,
  });

  String get displayName => source == 'factory'
      ? '$typeName $grade ${thicknessCm}سم ($category - مواد المعمل) — المتاح: ${availableQty.fmt}'
      : '$typeName $grade ${thicknessCm}سم ($category) — المتاح: ${availableQty.fmt}';
}

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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 4,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              if (t.photoPath.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    end: 12,
                                  ),
                                  child: AppImageThumbnail(
                                    imagePath: t.photoPath,
                                    title: 'صورة تفصيل ${t.name}',
                                  ),
                                ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '${t.name} • المتاح ${t.quantity.fmt} ${t.unitSymbol}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 16,
                                      runSpacing: 4,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF0FDF4),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: const Color(0xFF86EFAC),
                                            ),
                                          ),
                                          child: Text(
                                            'تكلفة المتر بعد الخدمات: ${t.costPerMeterAfterServices.fmt} \$ / ${t.unitSymbol}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF166534),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.chipBgBlue,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: AppColors.panelBorder,
                                            ),
                                          ),
                                          child: Text(
                                            'سعر بيع المتر: ${t.sellingPrice.fmt} \$ / ${t.unitSymbol}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  accent ??
                                                  AppColors.successGreen,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                vertical: 2,
                                              ),
                                          child: Text(
                                            'البنود: ${t.lineItems.length} • الإجمالي: ${t.totalNetCost.fmt}\$',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color:
                                                  AppColors
                                                      .brandSecondaryText,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accentPrimary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                ),
                                onPressed: () =>
                                    _showAddTailoringInventoryDialog(erp, t),
                                icon: const Icon(
                                  Icons.add_box_outlined,
                                  size: 16,
                                ),
                                label: const Text(
                                  'إضافة مخزون',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 4),
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
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                AppImageThumbnail(
                                  imagePath: sc.photoPath,
                                  width: 36,
                                  height: 36,
                                  title:
                                      'صورة القطعة الزائدة (${sc.description})',
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => showAppImageViewer(
                                      context,
                                      imagePath: sc.photoPath,
                                      title:
                                          'صورة القطعة الزائدة (${sc.description})',
                                    ),
                                    child: const Text(
                                      'معاينة صورة القطعة',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.accentPrimary,
                                      ),
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
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CurrencyBadge(currency: ord.currency),
                        if (ord.photoPath.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          AppImageThumbnail(
                            imagePath: ord.photoPath,
                            width: 38,
                            height: 38,
                            title: 'صورة طلبية ${ord.orderNo}',
                          ),
                        ],
                      ],
                    ),
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
                      'المصدر: ${inv.sourceType}${inv.items.length > 1 ? ' (${inv.items.length} أصناف)' : (inv.sourceType == 'تفصيل بسيط' || inv.sourceType == 'تفصيل معقد' ? ' • الكمية: ${inv.sourceQuantity.fmt} ${inv.sourceUnitCategory == 'متر مكعب' ? 'م³' : 'م²'}' : '')} • الإجمالي: ${inv.grandTotal.fmt}${inv.currencySymbol} • المدفوع: ${(inv.cashPaidNow + inv.depositDeducted).fmt}${inv.currencySymbol} • المتبقي: ${inv.remainingBalance.fmt}${inv.currencySymbol}${inv.photoPath.isEmpty ? "" : " • مرفق صورة"}',
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
                            title: inv.isCashInvoice ? 'فاتورة بيع نقدية معمل' : 'فاتورة مبيعات معمل',
                            invoiceNo: inv.invoiceNo,
                            dateText: intl.DateFormat(
                              'yyyy-MM-dd',
                            ).format(inv.date),
                            partyName: inv.clientName,
                            items: inv.items.isNotEmpty
                                ? [
                                    ...inv.items.expand(
                                      (item) => [
                                        {
                                          'name': item.description,
                                          'details': item.sourceType,
                                          'qty':
                                              '${item.quantity.fmt} ${item.unitCategory == 'متر مكعب' ? 'م³' : item.unitCategory == 'متر مربع' ? 'م²' : 'وحدة'}',
                                          'total': item.agreedPrice.fmt,
                                        },
                                        ...item.services.map(
                                          (s) => {
                                            'name': '  • خدمة: ${s.serviceName}',
                                            'details': s.notes,
                                            'qty': '1',
                                            'total': s.price.fmt,
                                          },
                                        ),
                                      ],
                                    ),
                                  ]
                                : [
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
                            subtotal: inv.itemsSubtotal + inv.servicesTotal,
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
                      if (inv.items.isNotEmpty)
                        ...inv.items.map(
                          (item) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.panelBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.chipBgSky,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.sourceType,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.orderDepositBoxAccent,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item.description,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                    Text(
                                      '${item.quantity.fmt} ${item.unitCategory} • ${item.agreedPrice.fmt}${inv.currencySymbol}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                                if (item.services.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  const Text(
                                    'الخدمات المخصصة لهذا البند:',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.brandSecondaryText),
                                  ),
                                  const SizedBox(height: 4),
                                  ...item.services.map(
                                    (s) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.build_circle_outlined, size: 14, color: AppColors.accentPrimary),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              '${s.serviceName} ${s.notes.isNotEmpty ? '(${s.notes})' : ''}',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          Text(
                                            '${s.price.fmt}${inv.currencySymbol}',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      else ...[
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
                      ],
                      if (inv.photoPath.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: AppImagePreviewCard(
                            imagePath: inv.photoPath,
                            title: 'صورة الفاتورة المرفقة (${inv.invoiceNo})',
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
            leading: p.photoPath.isNotEmpty
                ? AppImageThumbnail(
                    imagePath: p.photoPath,
                    width: 40,
                    height: 40,
                    title: 'مخطط / صورة المشروع (${p.name})',
                  )
                : const CircleAvatar(
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
              if (p.photoPath.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: AppImagePreviewCard(
                    imagePath: p.photoPath,
                    title: 'مخطط / صورة المشروع (${p.name})',
                  ),
                ),
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
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(existing == null ? 'إضافة مشروع جديد' : 'تعديل المشروع'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
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
                  const SizedBox(height: 12),
                  AppImageAttachmentPicker(
                    initialPath: photoCtrl.text,
                    label: 'صورة / مخطط المشروع',
                    onImageChanged: (p) => setSt(() => photoCtrl.text = p),
                  ),
                ],
              ),
            ),
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
                  const Divider(height: 8),
                  Text('المادة: ${t.rawMaterialDescription}'),
                  Text('التكلفة الكلية: ${t.totalNetCost.fmt}\$'),
                  if (t.photoPath.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: AppImagePreviewCard(
                        imagePath: t.photoPath,
                        title: 'صورة التفصيل المرفقة (${t.name})',
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
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showAddTailoringInventoryDialog(erp, t);
                    },
                    icon: const Icon(Icons.add_box_outlined, size: 16),
                    label: const Text('إضافة مخزون للتفصيل من صفحة مواد المصنع'),
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

  void _showAddTailoringInventoryDialog(
    ERPProvider erp,
    WorkshopTailoringModel t,
  ) {
    if (t.lineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد بنود لهذا التفصيل لإضافة مخزون إليها.'),
          backgroundColor: AppColors.dangerWaste,
        ),
      );
      return;
    }

    String selectedLineId = t.lineItems.first.id;
    final addQtyCtrl = TextEditingController(text: '1');
    final sellingPriceCtrl = TextEditingController(text: t.sellingPrice.fmt);
    String? formError;
    String? selectedWhId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final li = t.lineItems.firstWhere(
            (item) => item.id == selectedLineId,
            orElse: () => t.lineItems.first,
          );

          // Find best matching material in erp.factoryWarehouse
          final matchingWarehouseItems = erp.factoryWarehouse.where((w) {
            if (li.stockId.isNotEmpty && w.id == li.stockId) return true;
            if (w.typeName == li.typeName) {
              if (li.grade.isNotEmpty && w.grade != li.grade) return false;
              if (li.thicknessCm > 0 &&
                  (w.thicknessCm - li.thicknessCm).abs() > 0.01) {
                return false;
              }
              return true;
            }
            return false;
          }).toList();

          final bestMatch = matchingWarehouseItems.isNotEmpty
              ? matchingWarehouseItems.first
              : (erp.factoryWarehouse.any((w) => w.typeName == li.typeName)
                  ? erp.factoryWarehouse.firstWhere(
                      (w) => w.typeName == li.typeName,
                    )
                  : (erp.factoryWarehouse.isNotEmpty
                      ? erp.factoryWarehouse.first
                      : null));

          selectedWhId ??= bestMatch?.id;
          final currentWh = erp.factoryWarehouse.firstWhere(
            (w) => w.id == selectedWhId,
            orElse: () =>
                bestMatch ??
                (erp.factoryWarehouse.isNotEmpty
                    ? erp.factoryWarehouse.first
                    : FactoryWarehouseModel(
                        id: '',
                        typeName: li.typeName,
                        grade: li.grade,
                        thicknessCm: li.thicknessCm,
                        category: li.category,
                        availableQty: 0.0,
                        netCostPerUnit: li.netCostPerMeter,
                        recommendedSalePrice: li.sellingPricePerMeter,
                      )),
          );

          final double addedQtyPieces = double.tryParse(addQtyCtrl.text) ?? 0.0;
          final bool isCube = li.category == 'متر مكعب' || li.heightCm > 5;
          final double pieceArea = isCube
              ? ((li.lengthCm / 100.0) *
                  (li.widthCm / 100.0) *
                  (li.heightCm / 100.0))
              : ((li.lengthCm / 100.0) * (li.widthCm / 100.0));
          final double deltaArea = pieceArea * addedQtyPieces;
          final double currentMeterPrice = currentWh.netCostPerUnit;
          final double addedValue = deltaArea * currentMeterPrice;

          final double newTotalTailoringArea = t.quantity + deltaArea;
          final double newTotalTailoringNetCost = t.totalNetCost + addedValue;
          final double newCostPerMeterAfterServices =
              newTotalTailoringArea > 0
                  ? (newTotalTailoringNetCost / newTotalTailoringArea)
                  : 0.0;

          return AlertDialog(
            title: Row(
              children: [
                const Icon(
                  Icons.add_shopping_cart_rounded,
                  color: AppColors.accentPrimary,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text('إضافة مخزون لتفصيل: ${t.name}')),
              ],
            ),
            content: SizedBox(
              width: 580,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Line item selector
                    const Text(
                      'اختر بند التفصيل المراد زيادة كميته:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedLineId,
                      isExpanded: true,
                      decoration: const InputDecoration(isDense: true),
                      items: t.lineItems.map((item) {
                        return DropdownMenuItem<String>(
                          value: item.id,
                          child: Text(
                            '${item.typeName} ${item.grade} (${item.lengthCm}×${item.widthCm}سم) — حالياً: ${item.quantity.fmt} قطع (${item.area.fmt} ${item.category})',
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setSt(() {
                            selectedLineId = v;
                            selectedWhId = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Dimensions and quantity addition
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
                          Text(
                            'أبعاد البند: الطول ${li.lengthCm} سم • العرض ${li.widthCm} سم ${isCube ? "• الارتفاع ${li.heightCm} سم" : ""} • مساحة القطعة: ${pieceArea.fmt} ${isCube ? "م³" : "م²"}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: addQtyCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'الكمية المراد زيادتها (عدد القطع)',
                                    isDense: true,
                                    prefixIcon: Icon(
                                      Icons.exposure_plus_1,
                                      size: 18,
                                    ),
                                  ),
                                  onChanged: (_) =>
                                      setSt(() => formError = null),
                                ),
                              ),
                              const SizedBox(width: 10),
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
                                    'الأمتار المحسوبة: ${deltaArea.fmt} ${li.category}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.accentPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Selected material from Factory Materials Section
                    const Text(
                      'المادة المسحوبة من شاشة المواد (صفحة المصنع):',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (erp.factoryWarehouse.isEmpty)
                      const Text(
                        'لا توجد مواد مسجلة في مستودع المصنع.',
                        style: TextStyle(color: AppColors.dangerWaste),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: selectedWhId,
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true),
                        items: erp.factoryWarehouse.map((w) {
                          return DropdownMenuItem<String>(
                            value: w.id,
                            child: Text(
                              '${w.typeName} ${w.grade} ${w.thicknessCm}سم — متاح: ${w.availableQty.fmt} ${w.category} — سعر المتر: ${w.netCostPerUnit.fmt}\$',
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setSt(() => selectedWhId = v),
                      ),
                    const SizedBox(height: 10),

                    // Added Value & Calculations Panel
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('سعر متر المادة الحالي من شاشة المواد:'),
                              Text(
                                '${currentMeterPrice.fmt} \$ / ${li.category}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('القيمة المضافة المحسوبة (الأمتار × سعر المتر):'),
                              Text(
                                '${addedValue.fmt} \$',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accentPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('المخزون المتاح في مواد المصنع:'),
                              Text(
                                '${currentWh.availableQty.fmt} ${li.category}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: currentWh.availableQty >= deltaArea
                                      ? AppColors.successGreen
                                      : AppColors.dangerWaste,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 12),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('صافي تكلفة المتر للتفصيل بعد الإضافة:'),
                              Text(
                                '${newCostPerMeterAfterServices.fmt} \$ / ${t.unitSymbol}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF166534),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Edit selling price field
                    TextField(
                      controller: sellingPriceCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'تعديل سعر بيع المتر للتفصيل (\$)',
                        isDense: true,
                        prefixIcon: Icon(Icons.price_change_outlined, size: 18),
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
                  ],
                ),
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
                  if (addedQtyPieces <= 0) {
                    setSt(
                      () => formError = 'أدخل كمية قطع صحيحة أكبر من الصفر.',
                    );
                    return;
                  }
                  if (deltaArea <= 0) {
                    setSt(
                      () => formError = 'الأبعاد أو الكمية المحسوبة غير صالحة.',
                    );
                    return;
                  }
                  if (currentWh.availableQty + 0.0001 < deltaArea) {
                    setSt(
                      () => formError =
                          'الكمية المحسوبة (${deltaArea.fmt} ${li.category}) تتجاوز المتاح في مواد المصنع (${currentWh.availableQty.fmt}).',
                    );
                    return;
                  }

                  final newSell =
                      double.tryParse(sellingPriceCtrl.text) ?? t.sellingPrice;
                  if (newSell < 0) {
                    setSt(() => formError = 'أدخل سعر بيع صحيح.');
                    return;
                  }

                  // 1. Deduct from Factory Warehouse
                  currentWh.availableQty =
                      (currentWh.availableQty - deltaArea).clamp(
                        0.0,
                        double.infinity,
                      );

                  // 2. Update line item pieces and weighted average cost
                  final double oldLineArea = li.area;
                  final double oldLineCost = oldLineArea * li.netCostPerMeter;
                  li.quantity += addedQtyPieces;
                  final double newLineArea = li.area;
                  final double newLineCost = oldLineCost + addedValue;
                  li.netCostPerMeter =
                      newLineArea > 0
                          ? (newLineCost / newLineArea)
                          : li.netCostPerMeter;
                  if (newSell > 0) {
                    li.sellingPricePerMeter = newSell;
                  }

                  // 3. Update tailoring quantity and selling price
                  t.quantity += deltaArea;
                  t.sellingPrice = newSell;

                  erp.saveToDisk();
                  erp.notifyListeners();
                  Navigator.pop(ctx);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تمت إضافة ${addedQtyPieces.fmt} قطع (${deltaArea.fmt} ${t.unitSymbol}) إلى التفصيل، وخصم ${deltaArea.fmt} من صفحة مواد المصنع بنجاح.',
                      ),
                      backgroundColor: AppColors.successGreen,
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('تأكيد وإضافة المخزون'),
              ),
            ],
          );
        },
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

  /// Unified tailoring builder.
  /// Simple uses Materials lines (meter selling price at end after services).
  /// Complex uses Factory Materials lines, auto service calculation, net meter
  /// price after services, aggregated net price, and manual total selling price.
  void _showTailoringBuilderDialog(ERPProvider erp, String complexity) {
    const bool allowScrap = false;
    final nameCtrl = TextEditingController();
    String? formError;
    String photoPath = '';

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
    final complexTotalSellingPriceCtrl = TextEditingController();
    String? selectedServiceId;
    String serviceSearch = '';
    final servicePriceCtrl = TextEditingController();
    final serviceNotesCtrl = TextEditingController();
    final List<ServiceAttachment> draftServices = [];
    final List<TailoringLineItem> draftLines = [];
    String productUnit = complexity == 'معقد' ? 'متر مكعب' : 'متر مربع';

    double lineArea(
      _TailoringStockOption? ws,
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
          final List<_TailoringStockOption> allStockOptions = [
            ...erp.factoryWarehouse.map(
              (w) => _TailoringStockOption(
                id: w.id,
                source: 'factory',
                typeName: w.typeName,
                grade: w.grade,
                thicknessCm: w.thicknessCm,
                category: w.category,
                availableQty: w.availableQty,
                netCostPerUnit: w.netCostPerUnit,
                recommendedSalePrice: w.recommendedSalePrice,
                isGranite: w.isGranite,
              ),
            ),
            ...erp.workshopStock.map(
              (w) => _TailoringStockOption(
                id: w.id,
                source: 'workshop',
                typeName: w.typeName,
                grade: w.grade,
                thicknessCm: w.thicknessCm,
                category: w.category,
                availableQty: w.availableQty,
                netCostPerUnit: w.netCostPerUnit,
                recommendedSalePrice: w.recommendedSalePrice,
                isGranite: w.isGranite,
              ),
            ),
          ];

          _TailoringStockOption? ws;
          if (selectedStockId != null) {
            final m = allStockOptions
                .where((w) => w.id == selectedStockId)
                .toList();
            ws = m.isEmpty ? null : m.first;
          }
          final bool wsCube = ws?.category == 'متر مكعب';
          final stockFiltered = allStockOptions
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

          void autoCalcServicePrice() {
            if (selectedServiceId == null) return;
            final srvMatches = erp.services
                .where((s) => s.id == selectedServiceId)
                .toList();
            if (srvMatches.isEmpty) return;
            final srv = srvMatches.first;
            final double curLen = double.tryParse(lenCtrl.text) ?? 0.0;
            final double curQty = double.tryParse(qtyCtrl.text) ?? 0.0;
            if (curLen > 0 && curQty > 0) {
              final double calc = (curLen / 100.0) * curQty * srv.unitRate;
              servicePriceCtrl.text = calc.toStringAsFixed(2);
            } else if (curQty > 0) {
              servicePriceCtrl.text = (curQty * srv.unitRate).toStringAsFixed(2);
            } else {
              servicePriceCtrl.text = srv.unitRate.toStringAsFixed(2);
            }
          }

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AppImageAttachmentPicker(
                      initialPath: photoPath,
                      label: 'إرفاق صورة للنموذج (اختياري)',
                      onImageChanged: (p) => setSt(() => photoPath = p),
                    ),
                    const SizedBox(height: 6),
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
                          labelText: 'نوع الأمتار المستخدمة (مواد المعمل)',
                        ),
                        items: stockFiltered
                            .map(
                              (s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(
                                  s.displayName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          setSt(() {
                            selectedStockId = v;
                            autoCalcServicePrice();
                          });
                        },
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
                              onChanged: (_) {
                                setSt(() {
                                  formError = null;
                                  autoCalcServicePrice();
                                });
                              },
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
                              onChanged: (_) {
                                setSt(() {
                                  formError = null;
                                  autoCalcServicePrice();
                                });
                              },
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
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
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
                          const SizedBox(height: 6),
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'بحث خدمة...',
                              prefixIcon: Icon(Icons.search),
                              isDense: true,
                            ),
                            onChanged: (v) =>
                                setSt(() => serviceSearch = v.trim()),
                          ),
                          const SizedBox(height: 6),
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
                            onChanged: (v) {
                              setSt(() {
                                selectedServiceId = v;
                                autoCalcServicePrice();
                              });
                            },
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: servicePriceCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'إجمالي سعر الخدمة (\$)',
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
                    if (complexity == 'معقد') ...[
                      const SizedBox(height: 6),
                      // Line item meter price after services banner for Complex Tailoring
                      Builder(
                        builder: (context) {
                          final double lineMatCost = lineSource == 'materials'
                              ? (area * (ws?.netCostPerUnit ?? 0.0))
                              : (area * (sc?.baseCost ?? 0.0));
                          final double lineSrvCost = draftServices.fold(
                            0.0,
                            (s, sv) => s + sv.price,
                          );
                          final double lineTotalNetCost = lineMatCost + lineSrvCost;
                          final double postTailoringMeterCost = area > 0
                              ? (lineTotalNetCost / area)
                              : (ws?.netCostPerUnit ?? sc?.baseCost ?? 0.0);

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calculate_outlined,
                                      size: 16,
                                      color: Color(0xFF15803D),
                                    ),
                                    const SizedBox(width: 6),
                                    const Expanded(
                                      child: Text(
                                        'سعر المتر بعد الخدمات لهذا البند:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Color(0xFF166534),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${postTailoringMeterCost.fmt} \$ / ${wsCube ? "م³" : "م²"}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Color(0xFF166534),
                                      ),
                                    ),
                                  ],
                                ),
                                if (area > 0) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'سعر المتر الأصلي للمادة: ${(ws?.netCostPerUnit ?? sc?.baseCost ?? 0.0).fmt}\$ + تكلفة الخدمات للمتر: ${(area > 0 ? lineSrvCost / area : 0.0).fmt}\$ (مساحة البند: ${area.fmt} ${wsCube ? "م³" : "م²"})',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF15803D),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                    if (complexity == 'بسيط') ...[
                      const SizedBox(height: 6),
                      // Net meter cost calculation post-tailoring (including services) for simple tailoring
                      Builder(
                        builder: (context) {
                          final double lineMatCost = lineSource == 'materials'
                              ? (area * (ws?.netCostPerUnit ?? 0.0))
                              : (area * (sc?.baseCost ?? 0.0));
                          final double lineSrvCost = draftServices.fold(
                            0.0,
                            (s, sv) => s + sv.price,
                          );
                          final double lineTotalNetCost = lineMatCost + lineSrvCost;
                          final double postTailoringMeterCost = area > 0
                              ? (lineTotalNetCost / area)
                              : (ws?.netCostPerUnit ?? sc?.baseCost ?? 0.0);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF86EFAC)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.calculate_outlined,
                                          size: 16,
                                          color: Color(0xFF15803D),
                                        ),
                                        const SizedBox(width: 6),
                                        const Expanded(
                                          child: Text(
                                            'صافي تكلفة المتر بعد الخدمات (تكلفة المتر بعد التفصيل):',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: Color(0xFF166534),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${postTailoringMeterCost.fmt} \$ / ${wsCube ? "م³" : "م²"}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Color(0xFF166534),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (area > 0) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'تكلفة المادة: ${lineMatCost.fmt}\$ + خدمات: ${lineSrvCost.fmt}\$ = ${lineTotalNetCost.fmt}\$ (المساحة: ${area.fmt} ${wsCube ? "م³" : "م²"})',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF15803D),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Meter selling price placed at the end of the line item after services
                              TextField(
                                controller: sellMeterCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  labelText: 'سعر البيع للمتر (\$)',
                                  hintText: postTailoringMeterCost > 0
                                      ? 'المقترح: ${(postTailoringMeterCost * 1.3).fmt}'
                                      : null,
                                  isDense: true,
                                  prefixIcon: const Icon(
                                    Icons.sell_outlined,
                                    size: 18,
                                  ),
                                ),
                                onChanged: (_) => setSt(() {}),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 10),

                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final double lineMatCost = lineSource == 'materials'
                              ? (area * (ws?.netCostPerUnit ?? 0.0))
                              : (area * (sc?.baseCost ?? 0.0));
                          final double lineSrvCost = draftServices.fold(
                            0.0,
                            (s, sv) => s + sv.price,
                          );
                          final double lineTotalNetCost =
                              lineMatCost + lineSrvCost;
                          final double postTailoringMeterCost = area > 0
                              ? (lineTotalNetCost / area)
                              : (ws?.netCostPerUnit ?? sc?.baseCost ?? 0.0);

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
                            final sell = complexity == 'بسيط'
                                ? (double.tryParse(sellMeterCtrl.text) ??
                                    (postTailoringMeterCost > 0
                                        ? postTailoringMeterCost * 1.30
                                        : stock.recommendedSalePrice))
                                : (postTailoringMeterCost > 0
                                    ? postTailoringMeterCost * 1.30
                                    : stock.recommendedSalePrice);
                            final labor = 0.0;
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
                            '${li.typeName} ${li.grade} (${li.lengthCm > 0 && li.widthCm > 0 ? "${li.lengthCm.fmt}×${li.widthCm.fmt}سم • ${li.quantity.toInt()} قطعة" : (li.source == 'scrap' ? 'خردة' : li.category)})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            'الاستهلاك: ${li.area.fmt} ${li.category == 'متر مكعب' ? 'م³' : 'م²'} • سعر المتر بعد الخدمات: ${li.netCostPerMeterAfterServices.fmt}\$ • خدمات: ${li.servicesTotal.fmt}\$',
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
                    if (complexity == 'معقد') ...[
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final double totalNetComplexCost = draftLines.fold(
                            0.0,
                            (sum, line) =>
                                sum + line.materialCost + line.servicesTotal,
                          );
                          final double totalComplexArea = draftLines.fold(
                            0.0,
                            (sum, line) => sum + line.area,
                          );
                          final double avgNetPerMeter = totalComplexArea > 0
                              ? (totalNetComplexCost / totalComplexArea)
                              : 0.0;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.panelBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.summarize_outlined,
                                      size: 18,
                                      color: AppColors.brandPrimaryText,
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'صافي سعر التفصيل المعقد بعد الخدمات:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppColors.brandPrimaryText,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${totalNetComplexCost.fmt} \$',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.partnersEquityAccent,
                                      ),
                                    ),
                                  ],
                                ),
                                if (totalComplexArea > 0) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'إجمالي المساحة: ${totalComplexArea.fmt} ${productUnit == "متر مكعب" ? "م³" : "م²"} • متوسط تكلفة المتر الصافية: ${avgNetPerMeter.fmt} \$',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.brandSecondaryText,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: complexTotalSellingPriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'إجمالي سعر البيع للتفصيل المعقد (\$)',
                          hintText: draftLines.isNotEmpty
                              ? 'المقترح: ${(draftLines.fold(0.0, (s, l) => s + l.materialCost + l.servicesTotal) * 1.3).fmt}'
                              : null,
                          isDense: true,
                          prefixIcon: const Icon(Icons.sell_outlined),
                        ),
                        onChanged: (_) => setSt(() {}),
                      ),
                    ],
                    const SizedBox(height: 8),
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

                        final double totalNetComplexCost = draftLines.fold(
                          0.0,
                          (sum, line) =>
                              sum + line.materialCost + line.servicesTotal,
                        );

                        double selling = 0.0;
                        if (complexity == 'معقد') {
                          final enteredSelling = double.tryParse(
                                complexTotalSellingPriceCtrl.text.trim(),
                              ) ??
                              0.0;
                          if (enteredSelling > 0) {
                            selling = outputMeasure > 0
                                ? (enteredSelling / outputMeasure)
                                : enteredSelling;
                          } else if (totalNetComplexCost > 0) {
                            selling = outputMeasure > 0
                                ? (totalNetComplexCost * 1.3 / outputMeasure)
                                : 0.0;
                          } else {
                            selling = draftLines.fold<double>(
                                  0.0,
                                  (sum, line) => sum + line.lineTotal,
                                ) /
                                (outputMeasure > 0 ? outputMeasure : 1.0);
                          }
                          for (final li in draftLines) {
                            if (li.sellingPricePerMeter <= 0) {
                              li.sellingPricePerMeter = selling;
                            }
                          }
                        } else {
                          selling = draftLines.fold<double>(
                                0.0,
                                (sum, line) =>
                                    sum +
                                    (line.area * line.sellingPricePerMeter),
                              ) /
                              (outputMeasure > 0 ? outputMeasure : 1.0);
                        }

                        // Commit stock: deduct materials from factory warehouse or workshop stock.
                        for (final li in draftLines) {
                          if (erp.factoryWarehouse.any((w) => w.id == li.stockId)) {
                            final ok = erp.deductFactoryWarehouseStock(
                              li.stockId,
                              li.area,
                            );
                            if (!ok) {
                              setSt(
                                () => formError =
                                    'نقص في مخزون مواد المعمل لـ ${li.typeName}. راجع الكميات.',
                              );
                              return;
                            }
                          } else if (erp.workshopStock.any((w) => w.id == li.stockId)) {
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
                          photoPath: photoPath,
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
                    const SizedBox(height: 12),
                    AppImageAttachmentPicker(
                      initialPath: photoCtrl.text,
                      label: 'صورة القطعة الزائدة',
                      onImageChanged: (p) => setSt(() => photoCtrl.text = p),
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
                  const SizedBox(height: 12),
                  AppImageAttachmentPicker(
                    initialPath: photoCtrl.text,
                    label: 'صورة الطلبية / المخطط',
                    onImageChanged: (p) => setSt(() => photoCtrl.text = p),
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
  /// Workshop invoice builder supporting multiple sources, multiple line items,
  /// dedicated services per item, and a 2-column layout (Left: Input fields, Right: Selected items).
  /// Applies to Cash Sales Invoices, Project Invoices, and standard Workshop Invoices.
  void _showAddWorkshopInvoiceDialog(
    ERPProvider erp, {
    String? presetProjectId,
    String? presetClientName,
    bool cashInvoice = false,
  }) {
    String invCurrency = AppCurrency.usd;
    final clientCtrl = TextEditingController(text: presetClientName ?? '');
    final salesDiscountCtrl = TextEditingController(text: '0');
    final depositCtrl = TextEditingController(text: '0');
    final cashCtrl = TextEditingController(text: '0');
    final photoCtrl = TextEditingController();
    String? formError;
    String? itemError;

    // The list of line items added to this invoice
    final List<WorkshopInvoiceItem> draftItems = [];

    // Current item being configured
    String itemSourceType = 'طلبية معمل';
    String? selectedRecordId;
    String recordSearch = '';
    final itemDescCtrl = TextEditingController();
    final itemQtyCtrl = TextEditingController(text: '1');
    final itemUnitPriceCtrl = TextEditingController(text: '0');
    final itemAgreedCtrl = TextEditingController(text: '0');
    final itemNetCtrl = TextEditingController(text: '0');
    String itemUnitCat = 'متر مربع';
    double itemDepositAmount = 0.0;
    bool itemIsGranite = false;
    String itemPhoto = '';

    // Raw material specific inputs
    String? selectedRawId;
    String rawSearch = '';
    final rawLenCtrl = TextEditingController();
    final rawWidCtrl = TextEditingController();
    final rawHeiCtrl = TextEditingController();
    final rawQtyCtrl = TextEditingController(text: '1');
    final rawPriceCtrl = TextEditingController();

    // Dedicated services for the current item
    final List<ServiceAttachment> currentItemServices = [];
    String? selectedServiceId;
    String serviceSearch = '';
    final servicePriceCtrl = TextEditingController();
    final serviceNotesCtrl = TextEditingController();

    double getAvailableStockForRaw(WorkshopStockModel w) {
      final used = draftItems
          .where((i) => i.sourceType == 'مواد خام' && i.sourceId == w.id)
          .fold<double>(0.0, (s, i) => s + i.quantity);
      return (w.availableQty - used).clamp(0.0, double.infinity);
    }

    double getAvailableForTailoring(WorkshopTailoringModel t) {
      final used = draftItems
          .where(
            (i) =>
                (i.sourceType == 'تفصيل بسيط' ||
                    i.sourceType == 'تفصيل معقد') &&
                i.sourceId == t.id,
          )
          .fold<double>(0.0, (s, i) => s + i.quantity);
      return (t.quantity - used).clamp(0.0, double.infinity);
    }

    void recomputeInvoiceFinancials() {
      final itemsTotal = draftItems.fold<double>(
        0.0,
        (s, i) => s + i.agreedPrice,
      );
      final servicesTotal = draftItems.fold<double>(
        0.0,
        (s, i) => s + i.servicesTotal,
      );
      final totalOrderDeposits = draftItems.fold<double>(
        0.0,
        (s, i) => s + i.depositAmount,
      );
      depositCtrl.text = totalOrderDeposits.fmt;

      final disc = double.tryParse(salesDiscountCtrl.text) ?? 0.0;
      final grandTotal = (itemsTotal + servicesTotal - disc).clamp(
        0.0,
        double.infinity,
      );

      if (cashInvoice) {
        cashCtrl.text = (grandTotal - totalOrderDeposits)
            .clamp(0.0, double.infinity)
            .fmt;
      } else {
        if (cashCtrl.text.isEmpty || cashCtrl.text == '0') {
          cashCtrl.text = (grandTotal - totalOrderDeposits)
              .clamp(0.0, double.infinity)
              .fmt;
        }
      }
    }

    void prefillFromRecord(void Function(void Function()) setSt) {
      if (itemSourceType == 'طلبية معمل') {
        if (selectedRecordId == null) return;
        final m = erp.workshopOrders
            .where((o) => o.id == selectedRecordId)
            .toList();
        if (m.isEmpty) return;
        final o = m.first;
        if (clientCtrl.text.trim().isEmpty) {
          clientCtrl.text = o.clientName;
        }
        invCurrency = o.currency;
        itemDescCtrl.text = o.customDimensionsText;
        itemUnitPriceCtrl.text = o.agreedPrice.fmt;
        itemAgreedCtrl.text = o.agreedPrice.fmt;
        itemQtyCtrl.text = '1';
        itemUnitCat = 'مقطوعية';
        itemDepositAmount = o.depositAmount;
        itemNetCtrl.text = (o.agreedPrice * 0.60).fmt;
        itemPhoto = o.photoPath;
        itemIsGranite = false;
      } else if (itemSourceType == 'تفصيل بسيط' ||
          itemSourceType == 'تفصيل معقد') {
        if (selectedRecordId == null) return;
        final all = [...erp.simpleTailorings, ...erp.complexTailorings];
        final m = all.where((t) => t.id == selectedRecordId).toList();
        if (m.isEmpty) return;
        final t = m.first;
        itemDescCtrl.text = t.name;
        itemUnitPriceCtrl.text = t.sellingPrice.fmt;
        final avail = getAvailableForTailoring(t);
        itemQtyCtrl.text = (avail < 1 ? avail : 1).fmt;
        final q = double.tryParse(itemQtyCtrl.text) ?? 1;
        itemAgreedCtrl.text = (t.sellingPrice * q).fmt;
        itemUnitCat = t.unitCategory;
        itemNetCtrl.text = (t.quantity > 0
                ? (t.totalNetCost / t.quantity * q)
                : 0)
            .fmt;
        itemDepositAmount = 0.0;
        itemPhoto = t.photoPath;
        itemIsGranite = t.isGranite;
      } else if (itemSourceType == 'قطع زائدة') {
        if (selectedRecordId == null) return;
        final m = erp.scrapItems
            .where((s) => s.id == selectedRecordId)
            .toList();
        if (m.isEmpty) return;
        final s = m.first;
        invCurrency = s.currency;
        itemDescCtrl.text = s.description;
        itemUnitPriceCtrl.text = s.sellingPrice.fmt;
        itemAgreedCtrl.text = s.sellingPrice.fmt;
        itemQtyCtrl.text = '1';
        itemUnitCat = 'قطعة';
        itemDepositAmount = 0.0;
        itemNetCtrl.text = s.baseCost.fmt;
        itemPhoto = s.photoPath;
        itemIsGranite = false;
      }
      setSt(() {});
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final dialogWidth = MediaQuery.of(ctx).size.width.clamp(900.0, 1280.0);
          final dialogHeight = MediaQuery.of(ctx).size.height * 0.90;

          // Record options for current selected source type (filtered by available in draft)
          List<Map<String, String>> recordsList() {
            switch (itemSourceType) {
              case 'طلبية معمل':
                return erp.workshopOrders
                    .where(
                      (o) =>
                          o.status == 'قيد التنفيذ' &&
                          !draftItems.any(
                            (i) =>
                                i.sourceType == 'طلبية معمل' &&
                                i.sourceId == o.id,
                          ),
                    )
                    .map(
                      (o) => {
                        'id': o.id,
                        'label':
                            '${o.orderNo} • ${o.clientName} (${o.agreedPrice.fmt}\$)',
                      },
                    )
                    .toList();
              case 'تفصيل بسيط':
                return erp.simpleTailorings
                    .where((t) => getAvailableForTailoring(t) > 0)
                    .map(
                      (t) => {
                        'id': t.id,
                        'label':
                            '${t.name} • المتاح ${getAvailableForTailoring(t).fmt} ${t.unitSymbol}',
                      },
                    )
                    .toList();
              case 'تفصيل معقد':
                return erp.complexTailorings
                    .where((t) => getAvailableForTailoring(t) > 0)
                    .map(
                      (t) => {
                        'id': t.id,
                        'label':
                            '${t.name} • المتاح ${getAvailableForTailoring(t).fmt} ${t.unitSymbol}',
                      },
                    )
                    .toList();
              case 'قطع زائدة':
                return erp.scrapItems
                    .where(
                      (s) =>
                          !s.isSold &&
                          !draftItems.any(
                            (i) =>
                                i.sourceType == 'قطع زائدة' &&
                                i.sourceId == s.id,
                          ),
                    )
                    .map(
                      (s) => {
                        'id': s.id,
                        'label': '${s.description} (${s.sellingPrice.fmt}\$)',
                      },
                    )
                    .toList();
              default:
                return [];
            }
          }

          final recs = recordsList()
              .where(
                (r) =>
                    recordSearch.isEmpty || r['label']!.contains(recordSearch),
              )
              .toList();
          final recValue = recs.any((r) => r['id'] == selectedRecordId)
              ? selectedRecordId
              : null;

          // Raw stock items
          final rawFiltered = erp.workshopStock
              .where((w) => getAvailableStockForRaw(w) > 0)
              .where(
                (w) =>
                    rawSearch.isEmpty ||
                    '${w.typeName} ${w.grade}'.contains(rawSearch),
              )
              .toList();
          final rawValue = rawFiltered.any((w) => w.id == selectedRawId)
              ? selectedRawId
              : null;

          WorkshopStockModel? selectedRaw;
          if (rawValue != null) {
            final m = erp.workshopStock.where((w) => w.id == rawValue).toList();
            if (m.isNotEmpty) selectedRaw = m.first;
          }

          final bool rawCube = selectedRaw?.category == 'متر مكعب';
          final double rl = double.tryParse(rawLenCtrl.text) ?? 0.0;
          final double rw = double.tryParse(rawWidCtrl.text) ?? 0.0;
          final double rh = double.tryParse(rawHeiCtrl.text) ?? 0.0;
          final double rq = double.tryParse(rawQtyCtrl.text) ?? 0.0;
          final double rp = double.tryParse(rawPriceCtrl.text) ?? 0.0;
          double rawArea = 0.0;
          if (selectedRaw != null && rl > 0 && rw > 0 && rq > 0) {
            rawArea = rawCube && rh > 0
                ? (rl / 100.0) * (rw / 100.0) * (rh / 100.0) * rq
                : (rl / 100.0) * (rw / 100.0) * rq;
          }

          // Services filtered
          final servicesFiltered = erp.services
              .where(
                (s) => serviceSearch.isEmpty || s.name.contains(serviceSearch),
              )
              .toList();
          final serviceValue =
              servicesFiltered.any((s) => s.id == selectedServiceId)
                  ? selectedServiceId
                  : null;

          // Totals calculation
          final double itemsTotal = draftItems.fold(
            0.0,
            (s, i) => s + i.agreedPrice,
          );
          final double servicesTotal = draftItems.fold(
            0.0,
            (s, i) => s + i.servicesTotal,
          );
          final double salesDiscount =
              double.tryParse(salesDiscountCtrl.text) ?? 0.0;
          final double grandTotal =
              (itemsTotal + servicesTotal - salesDiscount).clamp(
            0.0,
            double.infinity,
          );
          final double totalDeposits = draftItems.fold(
            0.0,
            (s, i) => s + i.depositAmount,
          );
          final double cashPaid = double.tryParse(cashCtrl.text) ?? 0.0;
          final double remaining = grandTotal - totalDeposits - cashPaid;

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: dialogWidth,
              height: dialogHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // Top Header Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          cashInvoice
                              ? Icons.point_of_sale_rounded
                              : (presetProjectId != null
                                  ? Icons.domain_rounded
                                  : Icons.receipt_long_rounded),
                          color: AppColors.accentPrimary,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                cashInvoice
                                    ? 'فاتورة بيع نقدية (مسددة بالكامل)'
                                    : (presetProjectId != null
                                        ? 'فاتورة مشروع معمل: ${presetClientName ?? ""}'
                                        : 'إنشاء فاتورة معمل'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (presetProjectId != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.chipBgSky,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'فاتورة مشروع',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.orderDepositBoxAccent,
                                    ),
                                  ),
                                ),
                              if (cashInvoice) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'مبيعات نقدية',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.successGreen,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${draftItems.length} أصناف مضافة',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'إغلاق',
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // TWO-COLUMN MAIN BODY:
                  // Left side = The invoice input fields
                  // Right side = The selected line items / records for this invoice
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.ltr, // forces child[0] to be PHYSICAL LEFT and child[1] to be PHYSICAL RIGHT!
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ==========================================
                          // LEFT COLUMN: THE INVOICE INPUT FIELDS
                          // ==========================================
                          Expanded(
                            flex: 5,
                            child: Directionality(
                              textDirection: TextDirection.rtl, // RTL content inside left column
                              child: Container(
                                color: Colors.white,
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Section 1: Client & Invoice Settings
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.person_outline_rounded,
                                                  size: 18,
                                                  color: AppColors.accentPrimary,
                                                ),
                                                const SizedBox(width: 6),
                                                const Text(
                                                  'بيانات الفاتورة والعميل',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                const Spacer(),
                                                SizedBox(
                                                  width: 180,
                                                  child: CurrencySelector(
                                                    value: invCurrency,
                                                    dense: true,
                                                    onChanged: (v) => setSt(() => invCurrency = v),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            TextField(
                                              controller: clientCtrl,
                                              decoration: const InputDecoration(
                                                labelText: 'اسم الزبون / العميل',
                                                isDense: true,
                                                prefixIcon: Icon(Icons.badge_outlined, size: 18),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 16),

                                      // Section 2: Add Line Item to Invoice
                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x0A000000),
                                              blurRadius: 4,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.add_shopping_cart_rounded,
                                                  size: 18,
                                                  color: Color(0xFF2563EB),
                                                ),
                                                const SizedBox(width: 6),
                                                const Text(
                                                  'إضافة بند / صنف جديد للفاتورة',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),

                                            // 1. Source Type Selector
                                            const Text(
                                              'مصدر الصنف (Source):',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.brandSecondaryText,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            DropdownButtonFormField<String>(
                                              value: itemSourceType,
                                              isExpanded: true,
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              ),
                                              items: const [
                                                DropdownMenuItem(
                                                  value: 'طلبية معمل',
                                                  child: Text('طلبية معمل (Order)'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'تفصيل بسيط',
                                                  child: Text('شراء تفصيل بسيط (Simple Tailoring)'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'تفصيل معقد',
                                                  child: Text('شراء تفصيل معقد (Complex Tailoring)'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'قطع زائدة',
                                                  child: Text('بيع قطعة زائدة وخردة (Scrap Item)'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'مواد خام',
                                                  child: Text('بيع مواد خام من المعمل (Raw Material)'),
                                                ),
                                              ],
                                              onChanged: (v) => setSt(() {
                                                itemSourceType = v!;
                                                selectedRecordId = null;
                                                selectedRawId = null;
                                                recordSearch = '';
                                                rawSearch = '';
                                                itemDescCtrl.clear();
                                                itemQtyCtrl.text = '1';
                                                itemUnitPriceCtrl.text = '0';
                                                itemAgreedCtrl.text = '0';
                                                itemNetCtrl.text = '0';
                                                rawLenCtrl.clear();
                                                rawWidCtrl.clear();
                                                rawHeiCtrl.clear();
                                                rawQtyCtrl.text = '1';
                                                rawPriceCtrl.clear();
                                                itemDepositAmount = 0.0;
                                                itemError = null;
                                              }),
                                            ),

                                            const SizedBox(height: 10),

                                            // 2. Record / Material Selection
                                            if (itemSourceType == 'مواد خام') ...[
                                              TextField(
                                                decoration: const InputDecoration(
                                                  labelText: 'بحث مادة خام...',
                                                  prefixIcon: Icon(Icons.search, size: 16),
                                                  isDense: true,
                                                ),
                                                onChanged: (v) => setSt(() => rawSearch = v.trim()),
                                              ),
                                              const SizedBox(height: 8),
                                              DropdownButtonFormField<String>(
                                                value: rawValue,
                                                isExpanded: true,
                                                decoration: const InputDecoration(
                                                  labelText: 'اختر المادة الخام من المعمل',
                                                  isDense: true,
                                                ),
                                                items: rawFiltered
                                                    .map(
                                                      (w) => DropdownMenuItem(
                                                        value: w.id,
                                                        child: Text(
                                                          '${w.typeName} ${w.grade} — المتاح: ${getAvailableStockForRaw(w).fmt} ${w.category == "متر مكعب" ? "م³" : "م²"}',
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                                onChanged: (v) => setSt(() {
                                                  selectedRawId = v;
                                                  if (selectedRaw != null) {
                                                    itemDescCtrl.text =
                                                        '${selectedRaw.typeName} ${selectedRaw.grade} ${selectedRaw.thicknessCm}سم';
                                                    itemUnitCat = selectedRaw.category;
                                                    itemIsGranite = selectedRaw.isGranite;
                                                    rawPriceCtrl.text = selectedRaw.recommendedSalePrice > 0
                                                        ? selectedRaw.recommendedSalePrice.fmt
                                                        : (selectedRaw.netCostPerUnit * 1.3).fmt;
                                                  }
                                                }),
                                              ),
                                              if (selectedRaw != null) ...[
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: TextField(
                                                        controller: rawLenCtrl,
                                                        keyboardType: TextInputType.number,
                                                        decoration: const InputDecoration(
                                                          labelText: 'الطول (سم)',
                                                          isDense: true,
                                                        ),
                                                        onChanged: (_) => setSt(() {
                                                          final p = double.tryParse(rawPriceCtrl.text) ?? 0;
                                                          itemAgreedCtrl.text = (rawArea * p).fmt;
                                                          itemNetCtrl.text = (rawArea * selectedRaw!.netCostPerUnit).fmt;
                                                        }),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: TextField(
                                                        controller: rawWidCtrl,
                                                        keyboardType: TextInputType.number,
                                                        decoration: const InputDecoration(
                                                          labelText: 'العرض (سم)',
                                                          isDense: true,
                                                        ),
                                                        onChanged: (_) => setSt(() {
                                                          final p = double.tryParse(rawPriceCtrl.text) ?? 0;
                                                          itemAgreedCtrl.text = (rawArea * p).fmt;
                                                          itemNetCtrl.text = (rawArea * selectedRaw!.netCostPerUnit).fmt;
                                                        }),
                                                      ),
                                                    ),
                                                    if (rawCube) ...[
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: TextField(
                                                          controller: rawHeiCtrl,
                                                          keyboardType: TextInputType.number,
                                                          decoration: const InputDecoration(
                                                            labelText: 'الارتفاع (سم)',
                                                            isDense: true,
                                                          ),
                                                          onChanged: (_) => setSt(() {
                                                            final p = double.tryParse(rawPriceCtrl.text) ?? 0;
                                                            itemAgreedCtrl.text = (rawArea * p).fmt;
                                                            itemNetCtrl.text = (rawArea * selectedRaw!.netCostPerUnit).fmt;
                                                          }),
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
                                                        controller: rawQtyCtrl,
                                                        keyboardType: TextInputType.number,
                                                        decoration: const InputDecoration(
                                                          labelText: 'العدد / القطع',
                                                          isDense: true,
                                                        ),
                                                        onChanged: (_) => setSt(() {
                                                          final p = double.tryParse(rawPriceCtrl.text) ?? 0;
                                                          itemAgreedCtrl.text = (rawArea * p).fmt;
                                                          itemNetCtrl.text = (rawArea * selectedRaw!.netCostPerUnit).fmt;
                                                        }),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: TextField(
                                                        controller: rawPriceCtrl,
                                                        keyboardType: TextInputType.number,
                                                        decoration: const InputDecoration(
                                                          labelText: 'سعر الوحدة (\$)',
                                                          isDense: true,
                                                        ),
                                                        onChanged: (_) => setSt(() {
                                                          final p = double.tryParse(rawPriceCtrl.text) ?? 0;
                                                          itemAgreedCtrl.text = (rawArea * p).fmt;
                                                          itemNetCtrl.text = (rawArea * selectedRaw!.netCostPerUnit).fmt;
                                                        }),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'الكمية المحسوبة: ${rawArea.fmt} ${selectedRaw.category == "متر مكعب" ? "م³" : "م²"} • المتاح: ${getAvailableStockForRaw(selectedRaw).fmt}',
                                                  style: const TextStyle(fontSize: 11, color: AppColors.accentPrimary),
                                                ),
                                              ],
                                            ] else ...[
                                              TextField(
                                                decoration: const InputDecoration(
                                                  labelText: 'بحث في السجلات المتاحة...',
                                                  prefixIcon: Icon(Icons.search, size: 16),
                                                  isDense: true,
                                                ),
                                                onChanged: (v) => setSt(() => recordSearch = v.trim()),
                                              ),
                                              const SizedBox(height: 8),
                                              DropdownButtonFormField<String>(
                                                value: recValue,
                                                isExpanded: true,
                                                decoration: const InputDecoration(
                                                  labelText: 'اختر السجل المراد إضافته',
                                                  isDense: true,
                                                ),
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
                                            ],

                                            const SizedBox(height: 10),

                                            // Item Description and Prices
                                            TextField(
                                              controller: itemDescCtrl,
                                              decoration: const InputDecoration(
                                                labelText: 'وصف البند / الصنف',
                                                isDense: true,
                                              ),
                                            ),
                                            const SizedBox(height: 8),

                                            if (itemSourceType == 'تفصيل بسيط' ||
                                                itemSourceType == 'تفصيل معقد') ...[
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: TextField(
                                                      controller: itemQtyCtrl,
                                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                      decoration: InputDecoration(
                                                        labelText: 'الكمية المطلوبة ($itemUnitCat)',
                                                        isDense: true,
                                                      ),
                                                      onChanged: (_) => setSt(() {
                                                        final q = double.tryParse(itemQtyCtrl.text) ?? 0;
                                                        final up = double.tryParse(itemUnitPriceCtrl.text) ?? 0;
                                                        itemAgreedCtrl.text = (q * up).fmt;
                                                      }),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: TextField(
                                                      controller: itemUnitPriceCtrl,
                                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                      decoration: const InputDecoration(
                                                        labelText: 'سعر الوحدة (\$)',
                                                        isDense: true,
                                                      ),
                                                      onChanged: (_) => setSt(() {
                                                        final q = double.tryParse(itemQtyCtrl.text) ?? 0;
                                                        final up = double.tryParse(itemUnitPriceCtrl.text) ?? 0;
                                                        itemAgreedCtrl.text = (q * up).fmt;
                                                      }),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                            ],

                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextField(
                                                    controller: itemAgreedCtrl,
                                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                    decoration: const InputDecoration(
                                                      labelText: 'المبلغ المتفق للبند (\$)',
                                                      isDense: true,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: TextField(
                                                    controller: itemNetCtrl,
                                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                    decoration: const InputDecoration(
                                                      labelText: 'التكلفة الصافية (\$)',
                                                      isDense: true,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),

                                            const SizedBox(height: 12),

                                            // 3. DEDICATED SERVICES FOR THIS ITEM
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFFCBD5E1)),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.handyman_outlined,
                                                        size: 16,
                                                        color: AppColors.accentPrimary,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      const Expanded(
                                                        child: Text(
                                                          'خدمات مخصصة لهذا الصنف:',
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 12,
                                                            color: Color(0xFF0F172A),
                                                          ),
                                                        ),
                                                      ),
                                                      Text(
                                                        'إجمالي خدمات الصنف: ${currentItemServices.fold<double>(0.0, (s, e) => s + e.price).fmt}\$',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                          color: Color(0xFF2563EB),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  DropdownButtonFormField<String>(
                                                    value: serviceValue,
                                                    isExpanded: true,
                                                    decoration: const InputDecoration(
                                                      labelText: 'اختر الخدمة',
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
                                                    onChanged: (v) => setSt(() {
                                                      selectedServiceId = v;
                                                      if (v != null) {
                                                        final srv = erp.services.firstWhere((s) => s.id == v);
                                                        servicePriceCtrl.text = srv.unitRate.fmt;
                                                      }
                                                    }),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: TextField(
                                                          controller: servicePriceCtrl,
                                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                          decoration: const InputDecoration(
                                                            labelText: 'سعر الخدمة (\$)',
                                                            isDense: true,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Expanded(
                                                        flex: 2,
                                                        child: TextField(
                                                          controller: serviceNotesCtrl,
                                                          decoration: const InputDecoration(
                                                            labelText: 'ملاحظات الخدمة (اختياري)',
                                                            isDense: true,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      ElevatedButton.icon(
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: const Color(0xFF2563EB),
                                                          foregroundColor: Colors.white,
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                        ),
                                                        onPressed: () {
                                                          if (selectedServiceId == null) return;
                                                          final price = double.tryParse(servicePriceCtrl.text) ?? 0.0;
                                                          if (price <= 0) return;
                                                          final srv = erp.services.firstWhere((s) => s.id == selectedServiceId);
                                                          setSt(() {
                                                            currentItemServices.add(
                                                              ServiceAttachment(
                                                                serviceName: srv.name,
                                                                price: price,
                                                                notes: serviceNotesCtrl.text.trim(),
                                                              ),
                                                            );
                                                            selectedServiceId = null;
                                                            servicePriceCtrl.clear();
                                                            serviceNotesCtrl.clear();
                                                          });
                                                        },
                                                        icon: const Icon(Icons.add, size: 14),
                                                        label: const Text('إرفاق', style: TextStyle(fontSize: 12)),
                                                      ),
                                                    ],
                                                  ),
                                                  if (currentItemServices.isNotEmpty) ...[
                                                    const SizedBox(height: 8),
                                                    Wrap(
                                                      spacing: 6,
                                                      runSpacing: 4,
                                                      children: currentItemServices.asMap().entries.map((e) {
                                                        return Chip(
                                                          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                                                          visualDensity: VisualDensity.compact,
                                                          backgroundColor: Colors.white,
                                                          label: Text(
                                                            '${e.value.serviceName}: ${e.value.price}\$',
                                                            style: const TextStyle(fontSize: 11),
                                                          ),
                                                          deleteIcon: const Icon(Icons.close, size: 14),
                                                          onDeleted: () => setSt(() => currentItemServices.removeAt(e.key)),
                                                        );
                                                      }).toList(),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),

                                            if (itemError != null) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                itemError!,
                                                style: const TextStyle(
                                                  color: AppColors.dangerWaste,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],

                                            const SizedBox(height: 12),

                                            // BUTTON: ADD THIS ITEM TO INVOICE
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF0F766E),
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                                onPressed: () {
                                                  // Validate addition of item
                                                  double itemQty = 1.0;
                                                  double itemAgreed = 0.0;
                                                  double itemNet = 0.0;
                                                  double itemUnitPrice = 0.0;
                                                  String itemDesc = itemDescCtrl.text.trim();

                                                  if (itemSourceType == 'مواد خام') {
                                                    if (selectedRaw == null || rawArea <= 0) {
                                                      setSt(() => itemError = 'يرجى اختيار المادة وتحديد الأبعاد.');
                                                      return;
                                                    }
                                                    if (rawArea > getAvailableStockForRaw(selectedRaw) + 0.0001) {
                                                      setSt(() => itemError = 'الكمية المطلوبة تتجاوز الرصيد المتاح.');
                                                      return;
                                                    }
                                                    itemQty = rawArea;
                                                    itemUnitPrice = rp;
                                                    itemAgreed = rawArea * rp;
                                                    itemNet = rawArea * selectedRaw.netCostPerUnit;
                                                    if (itemDesc.isEmpty) {
                                                      itemDesc = '${selectedRaw.typeName} ${selectedRaw.grade} ${selectedRaw.thicknessCm}سم';
                                                    }
                                                  } else {
                                                    if (selectedRecordId == null) {
                                                      setSt(() => itemError = 'يرجى اختيار السجل المراد إضافته.');
                                                      return;
                                                    }
                                                    itemQty = double.tryParse(itemQtyCtrl.text) ?? 1.0;
                                                    itemUnitPrice = double.tryParse(itemUnitPriceCtrl.text) ?? 0.0;
                                                    itemAgreed = double.tryParse(itemAgreedCtrl.text) ?? 0.0;
                                                    itemNet = double.tryParse(itemNetCtrl.text) ?? 0.0;

                                                    if (itemSourceType == 'تفصيل بسيط' ||
                                                        itemSourceType == 'تفصيل معقد') {
                                                      final all = [...erp.simpleTailorings, ...erp.complexTailorings];
                                                      final t = all.firstWhere((x) => x.id == selectedRecordId);
                                                      final avail = getAvailableForTailoring(t);
                                                      if (itemQty <= 0 || itemQty > avail + 0.0001) {
                                                        setSt(() => itemError = 'الكمية المطلوبة غير صحيحة أو تتجاوز المتاح.');
                                                        return;
                                                      }
                                                    }
                                                    if (itemDesc.isEmpty) {
                                                      setSt(() => itemError = 'يرجى إدخال وصف الصنف.');
                                                      return;
                                                    }
                                                  }

                                                  final newItem = WorkshopInvoiceItem(
                                                    id: 'wii_${DateTime.now().microsecondsSinceEpoch}',
                                                    sourceType: itemSourceType,
                                                    sourceId: itemSourceType == 'مواد خام'
                                                        ? selectedRawId!
                                                        : selectedRecordId!,
                                                    description: itemDesc,
                                                    quantity: itemQty,
                                                    unitCategory: itemUnitCat,
                                                    unitPrice: itemUnitPrice,
                                                    agreedPrice: itemAgreed,
                                                    netCost: itemNet,
                                                    depositAmount: itemDepositAmount,
                                                    isGranite: itemIsGranite,
                                                    services: List.of(currentItemServices),
                                                    photoPath: itemPhoto,
                                                    lengthCm: rl,
                                                    widthCm: rw,
                                                    heightCm: rh,
                                                  );

                                                  setSt(() {
                                                    draftItems.add(newItem);
                                                    // Reset item form
                                                    selectedRecordId = null;
                                                    selectedRawId = null;
                                                    recordSearch = '';
                                                    rawSearch = '';
                                                    currentItemServices.clear();
                                                    itemDescCtrl.clear();
                                                    itemQtyCtrl.text = '1';
                                                    itemUnitPriceCtrl.text = '0';
                                                    itemAgreedCtrl.text = '0';
                                                    itemNetCtrl.text = '0';
                                                    rawLenCtrl.clear();
                                                    rawWidCtrl.clear();
                                                    rawHeiCtrl.clear();
                                                    rawPriceCtrl.clear();
                                                    itemDepositAmount = 0.0;
                                                    itemError = null;
                                                    formError = null;
                                                    recomputeInvoiceFinancials();
                                                  });
                                                },
                                                icon: const Icon(Icons.add_task_rounded, size: 18),
                                                label: const Text(
                                                  '+ إضافة هذا الصنف إلى الفاتورة',
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 16),

                                      // Section 3: Discounts & Payments Settings
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.payments_outlined, size: 18, color: AppColors.accentPrimary),
                                                const SizedBox(width: 6),
                                                const Text(
                                                  'الخصم والدفعات النقدية للفاتورة',
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextField(
                                                    controller: salesDiscountCtrl,
                                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                    decoration: const InputDecoration(
                                                      labelText: 'خصم المبيعات المسموح',
                                                      isDense: true,
                                                    ),
                                                    onChanged: (_) => setSt(() => recomputeInvoiceFinancials()),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF4F46E5),
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                  ),
                                                  onPressed: () {
                                                    final currentNet = (itemsTotal + servicesTotal - salesDiscount)
                                                        .clamp(0.0, double.infinity);
                                                    final truncated = currentNet.truncateToDouble();
                                                    final diff = currentNet - truncated;
                                                    if (diff > 0.0001) {
                                                      salesDiscountCtrl.text = (salesDiscount + diff).fmt;
                                                      recomputeInvoiceFinancials();
                                                      setSt(() {});
                                                    }
                                                  },
                                                  icon: const Icon(Icons.content_cut_rounded, size: 14),
                                                  label: const Text('تجاهل القروش', style: TextStyle(fontSize: 11)),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            if (cashInvoice) ...[
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFDCFCE7),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'فاتورة نقدية: تُسدد بالكامل نقداً فور الإصدار بعد خصم عربون الطلبيات إن وجد.',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.successGreen,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                            ] else ...[
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: TextField(
                                                      controller: depositCtrl,
                                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                      decoration: const InputDecoration(
                                                        labelText: 'العربون المخصوم (\$)',
                                                        isDense: true,
                                                        helperText: 'مجموع عربون الطلبيات المرفقة',
                                                      ),
                                                      onChanged: (_) => setSt(() {}),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: TextField(
                                                      controller: cashCtrl,
                                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                      decoration: const InputDecoration(
                                                        labelText: 'النقد المدفوع الآن (\$)',
                                                        isDense: true,
                                                      ),
                                                      onChanged: (_) => setSt(() {}),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                            const SizedBox(height: 12),
                                            AppImageAttachmentPicker(
                                              initialPath: photoCtrl.text,
                                              label: 'صورة الفاتورة / الوصل',
                                              onImageChanged: (p) =>
                                                  setSt(() => photoCtrl.text = p),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // ELEGANT VERTICAL DIVIDER
                          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFCBD5E1)),

                          // ==========================================
                          // RIGHT COLUMN: THE SELECTED LINE ITEMS & SUMMARY
                          // ==========================================
                          Expanded(
                            flex: 6,
                            child: Directionality(
                              textDirection: TextDirection.rtl, // RTL content inside right column
                              child: Container(
                                color: const Color(0xFFF8FAFC),
                                child: Column(
                                  children: [
                                    // Header of right side
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.list_alt_rounded, size: 20, color: AppColors.accentPrimary),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'الأصناف والبنود المحددة لهذه الفاتورة',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            '${draftItems.length} بند',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.brandSecondaryText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // List of selected items
                                    Expanded(
                                      child: draftItems.isEmpty
                                          ? Center(
                                              child: Padding(
                                                padding: const EdgeInsets.all(24),
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.receipt_long_outlined,
                                                      size: 64,
                                                      color: Colors.grey.shade400,
                                                    ),
                                                    const SizedBox(height: 12),
                                                    const Text(
                                                      'لم يتم إضافة أي صنف للفاتورة بعد',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 16,
                                                        color: Color(0xFF475569),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    const Text(
                                                      'اختر المصدر والسجل من القائمة يساراً وأضف الأصناف والخدمات المخصصة لها لتظهر هنا.',
                                                      textAlign: TextAlign.center,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: AppColors.brandSecondaryText,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                          : ListView.separated(
                                              padding: const EdgeInsets.all(16),
                                              itemCount: draftItems.length,
                                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                                              itemBuilder: (context, idx) {
                                                final item = draftItems[idx];
                                                Color chipColor = AppColors.chipBgSky;
                                                Color textColor = AppColors.orderDepositBoxAccent;
                                                if (item.sourceType == 'مواد خام') {
                                                  chipColor = const Color(0xFFD1FAE5);
                                                  textColor = const Color(0xFF065F46);
                                                } else if (item.sourceType == 'قطع زائدة') {
                                                  chipColor = const Color(0xFFFEF3C7);
                                                  textColor = const Color(0xFF92400E);
                                                } else if (item.sourceType == 'طلبية معمل') {
                                                  chipColor = const Color(0xFFEDE9FE);
                                                  textColor = const Color(0xFF5B21B6);
                                                }

                                                return Card(
                                                  elevation: 1,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                                                  ),
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(12),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        // Item header
                                                        Row(
                                                          children: [
                                                            CircleAvatar(
                                                              radius: 12,
                                                              backgroundColor: const Color(0xFFE2E8F0),
                                                              child: Text(
                                                                '${idx + 1}',
                                                                style: const TextStyle(
                                                                  fontSize: 11,
                                                                  fontWeight: FontWeight.bold,
                                                                  color: Color(0xFF334155),
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(width: 8),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                              decoration: BoxDecoration(
                                                                color: chipColor,
                                                                borderRadius: BorderRadius.circular(6),
                                                              ),
                                                              child: Text(
                                                                item.sourceType,
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  fontWeight: FontWeight.bold,
                                                                  color: textColor,
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(width: 8),
                                                            Expanded(
                                                              child: Text(
                                                                item.description,
                                                                style: const TextStyle(
                                                                  fontWeight: FontWeight.bold,
                                                                  fontSize: 14,
                                                                ),
                                                              ),
                                                            ),
                                                            IconButton(
                                                              icon: const Icon(
                                                                Icons.delete_outline_rounded,
                                                                size: 20,
                                                                color: AppColors.dangerWaste,
                                                              ),
                                                              tooltip: 'حذف هذا الصنف',
                                                              onPressed: () {
                                                                setSt(() {
                                                                  draftItems.removeAt(idx);
                                                                  recomputeInvoiceFinancials();
                                                                });
                                                              },
                                                            ),
                                                          ],
                                                        ),

                                                        const SizedBox(height: 6),

                                                        // Item specs
                                                        Row(
                                                          children: [
                                                            Text(
                                                              'الكمية: ${item.quantity.fmt} ${item.unitCategory}',
                                                              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                                            ),
                                                            if (item.unitPrice > 0) ...[
                                                              const SizedBox(width: 12),
                                                              Text(
                                                                'سعر الوحدة: ${item.unitPrice.fmt}\$',
                                                                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                                              ),
                                                            ],
                                                            const Spacer(),
                                                            Text(
                                                              'قيمة الصنف: ${item.agreedPrice.fmt} ${AppCurrency.symbol(invCurrency)}',
                                                              style: const TextStyle(
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 13,
                                                                color: Color(0xFF0F172A),
                                                              ),
                                                            ),
                                                          ],
                                                        ),

                                                        if (item.depositAmount > 0) ...[
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            'العربون المرفق مع الطلبية: ${item.depositAmount.fmt}\$',
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.bold,
                                                              color: Color(0xFF4F46E5),
                                                            ),
                                                          ),
                                                        ],

                                                        // Dedicated services sub-box
                                                        if (item.services.isNotEmpty) ...[
                                                          const SizedBox(height: 8),
                                                          Container(
                                                            padding: const EdgeInsets.all(8),
                                                            decoration: BoxDecoration(
                                                              color: const Color(0xFFF1F5F9),
                                                              borderRadius: BorderRadius.circular(6),
                                                            ),
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                const Text(
                                                                  'الخدمات المخصصة لهذا البند:',
                                                                  style: TextStyle(
                                                                    fontSize: 11,
                                                                    fontWeight: FontWeight.bold,
                                                                    color: AppColors.brandSecondaryText,
                                                                  ),
                                                                ),
                                                                const SizedBox(height: 4),
                                                                ...item.services.map(
                                                                  (s) => Padding(
                                                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                                                    child: Row(
                                                                      children: [
                                                                        const Icon(
                                                                          Icons.build_circle_outlined,
                                                                          size: 13,
                                                                          color: AppColors.accentPrimary,
                                                                        ),
                                                                        const SizedBox(width: 4),
                                                                        Expanded(
                                                                          child: Text(
                                                                            '${s.serviceName} ${s.notes.isNotEmpty ? '(${s.notes})' : ''}',
                                                                            style: const TextStyle(fontSize: 11),
                                                                          ),
                                                                        ),
                                                                        Text(
                                                                          '${s.price.fmt}\$',
                                                                          style: const TextStyle(
                                                                            fontSize: 11,
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
                                                        ],

                                                        const Divider(height: 14),

                                                        // Subtotal for item + services
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          children: [
                                                            const Text(
                                                              'إجمالي البند شاملاً الخدمات:',
                                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                                            ),
                                                            Text(
                                                              '${(item.agreedPrice + item.servicesTotal).fmt} ${AppCurrency.symbol(invCurrency)}',
                                                              style: const TextStyle(
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 14,
                                                                color: Color(0xFF2563EB),
                                                              ),
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

                                    // Bottom Totals & Submit Section
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        border: Border(top: BorderSide(color: Color(0xFFCBD5E1))),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'مجموع الأصناف: ${itemsTotal.fmt} ${AppCurrency.symbol(invCurrency)}',
                                                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                              ),
                                              Text(
                                                'مجموع الخدمات: ${servicesTotal.fmt} ${AppCurrency.symbol(invCurrency)}',
                                                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                              ),
                                              Text(
                                                'الخصم: -${salesDiscount.fmt} ${AppCurrency.symbol(invCurrency)}',
                                                style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'الإجمالي النهائي للفاتورة:',
                                                    style: TextStyle(fontSize: 12, color: AppColors.brandSecondaryText),
                                                  ),
                                                  Text(
                                                    '${grandTotal.fmt} ${AppCurrency.symbol(invCurrency)}',
                                                    style: const TextStyle(
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.accentPrimary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    'المدفوع: ${(cashPaid + totalDeposits).fmt} ${AppCurrency.symbol(invCurrency)}'
                                                    '${totalDeposits > 0 ? " (عربون ${totalDeposits.fmt})" : ""}',
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        'المتبقي: ${remaining.fmt} ${AppCurrency.symbol(invCurrency)}',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.bold,
                                                          color: remaining <= 0.01
                                                              ? AppColors.successGreen
                                                              : AppColors.dangerWaste,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: remaining <= 0.01
                                                              ? const Color(0xFFDCFCE7)
                                                              : const Color(0xFFFEE2E2),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          remaining <= 0.01 ? 'مسددة بالكامل' : 'متبقي ذمة',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                            color: remaining <= 0.01
                                                                ? const Color(0xFF15803D)
                                                                : const Color(0xFFB91C1C),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),

                                          if (formError != null) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              formError!,
                                              style: const TextStyle(
                                                color: AppColors.dangerWaste,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],

                                          const SizedBox(height: 12),

                                          // SUBMIT BUTTON
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.accentPrimary,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(vertical: 14),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                              ),
                                              onPressed: () {
                                                if (draftItems.isEmpty) {
                                                  setSt(() => formError = 'يجب إضافة صنف واحد على الأقل للفاتورة.');
                                                  return;
                                                }
                                                if (clientCtrl.text.trim().isEmpty) {
                                                  setSt(() => formError = 'يرجى إدخال اسم العميل / الزبون.');
                                                  return;
                                                }
                                                if (salesDiscount < 0 || salesDiscount > itemsTotal + servicesTotal) {
                                                  setSt(() => formError = 'قيمة خصم المبيعات غير صحيحة.');
                                                  return;
                                                }

                                                final enteredDeposit = double.tryParse(depositCtrl.text) ?? 0.0;
                                                final deposit = enteredDeposit;
                                                final cash = cashInvoice
                                                    ? (grandTotal - deposit).clamp(0.0, double.infinity)
                                                    : (double.tryParse(cashCtrl.text) ?? 0.0);

                                                if (deposit < 0 ||
                                                    cash < 0 ||
                                                    deposit + cash > grandTotal + 0.01) {
                                                  setSt(() => formError = 'إجمالي العربون والنقد لا يمكن أن يتجاوز قيمة الفاتورة.');
                                                  return;
                                                }

                                                // Determine overall sourceType: if all items same source, use it; else 'مصادر متعددة'
                                                final sourcesSet = draftItems.map((i) => i.sourceType).toSet();
                                                final String overallSourceType = sourcesSet.length == 1
                                                    ? sourcesSet.first
                                                    : 'مصادر متعددة (${sourcesSet.join(" + ")})';

                                                final invoice = WorkshopInvoiceModel(
                                                  id: 'wi_${DateTime.now().millisecondsSinceEpoch}',
                                                  invoiceNo: 'WRK-INV-${erp.workshopInvoices.length + 101}',
                                                  date: DateTime.now(),
                                                  clientName: clientCtrl.text.trim(),
                                                  items: List.of(draftItems),
                                                  sourceType: overallSourceType,
                                                  sourceId: draftItems.first.sourceId,
                                                  projectId: presetProjectId ?? '',
                                                  itemDescription: draftItems.map((i) => i.description).join(' + '),
                                                  sourceQuantity: draftItems.fold<double>(0.0, (s, i) => s + i.quantity),
                                                  sourceUnitCategory: draftItems.first.unitCategory,
                                                  agreedPrice: itemsTotal,
                                                  depositDeducted: deposit,
                                                  cashPaidNow: cash,
                                                  netCost: draftItems.fold<double>(0.0, (s, i) => s + i.netCost),
                                                  salesDiscount: salesDiscount,
                                                  services: draftItems.expand((i) => i.services).toList(),
                                                  photoPath: photoCtrl.text.trim(),
                                                  isGranite: draftItems.any((i) => i.isGranite),
                                                  isCashInvoice: cashInvoice,
                                                  currency: invCurrency,
                                                );

                                                final created = erp.createWorkshopInvoice(invoice);
                                                if (!created) {
                                                  setSt(
                                                    () => formError = cashInvoice
                                                        ? 'تعذر اعتماد الفاتورة النقدية؛ تحقق من المخزون أو تسوية المبلغ بالكامل.'
                                                        : 'المخزون غير كافٍ أو تعذر اعتماد الفاتورة.',
                                                  );
                                                  return;
                                                }

                                                Navigator.pop(ctx);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      cashInvoice
                                                          ? 'تم إصدار فاتورة البيع النقدية وتحصيلها بالكامل بنجاح.'
                                                          : (presetProjectId != null
                                                              ? 'تم إصدار وترحيل فاتورة المشروع بنجاح.'
                                                              : 'تم إصدار وحفظ فاتورة المعمل بنجاح.'),
                                                    ),
                                                    backgroundColor: AppColors.successGreen,
                                                  ),
                                                );
                                              },
                                              child: Text(
                                                cashInvoice
                                                    ? 'إصدار فاتورة البيع النقدية وتحصيلها'
                                                    : (presetProjectId != null
                                                        ? 'إصدار وترحيل فاتورة المشروع'
                                                        : 'إصدار وحفظ فاتورة المعمل'),
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
