import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';
import '../widgets/currency_selector.dart';
import '../widgets/thermal_receipt_dialog.dart';
import '../widgets/a4_invoice_print_dialog.dart';
import '../widgets/a4_statement_print_dialog.dart';
import '../widgets/app_image_attachment.dart';
import '../widgets/workshop_order_dialogs.dart';
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

  String get displayName =>
      '$typeName $grade ${thicknessCm}سم ($category - مواد المعمل) — المتاح: ${availableQty.fmt}';
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

  // Workshop Invoices (Tab 6) search/filter
  final TextEditingController _workshopInvoicesSearchCtrl = TextEditingController();
  String _workshopInvoicesSearch = '';
  String _workshopInvoicesCurrency = 'ALL';

  // Projects (Tab 7) search/filter
  final TextEditingController _projectsSearchCtrl = TextEditingController();
  String _projectsSearch = '';
  String _projectsCurrency = 'ALL';

  // Cash Invoices (Tab 9) search/filter
  final TextEditingController _cashInvoicesSearchCtrl = TextEditingController();
  String _cashInvoicesSearch = '';
  String _cashInvoicesCurrency = 'ALL';

  @override
  void initState() {
    super.initState();
    _workshopTabController = TabController(length: 9, vsync: this);
  }

  bool _matchesWorkshopInvoice(
    WorkshopInvoiceModel inv,
    String query,
    String currencyFilter,
    ERPProvider erp,
  ) {
    if (currencyFilter != 'ALL') {
      final isInvSyp = AppCurrency.isSyp(inv.currency);
      final isInvUsd = AppCurrency.isUsd(inv.currency);

      final client = erp.clients
          .where((c) => c.name.trim() == inv.clientName.trim())
          .firstOrNull;

      final isSypHolder = client != null && client.isSypCustomer;
      final isUsdHolder = client != null && client.isUsdCustomer;

      if (currencyFilter == AppCurrency.syp) {
        if (isInvSyp) {
          // matches
        } else if (isSypHolder && !isInvUsd) {
          // matches
        } else {
          return false;
        }
      } else {
        if (isInvUsd) {
          // matches
        } else if (isUsdHolder && !isInvSyp) {
          // matches
        } else {
          return false;
        }
      }
    }

    if (query.trim().isEmpty) return true;

    final client = erp.clients
        .where((c) => c.name.trim() == inv.clientName.trim())
        .firstOrNull;
    final phone = client?.phone ?? '';

    final text = '${inv.invoiceNo} ${inv.clientName} $phone ${inv.itemDescription}';
    return arabicFuzzyMatch(text, query);
  }

  bool _matchesWorkshopProject(
    WorkshopProjectModel project,
    String query,
    String currencyFilter,
    ERPProvider erp,
  ) {
    final linkedInvoices = erp.workshopInvoices
        .where((i) => i.projectId == project.id)
        .toList();

    if (currencyFilter != 'ALL') {
      final hasSypInvoice = linkedInvoices.any((i) => AppCurrency.isSyp(i.currency));
      final hasUsdInvoice = linkedInvoices.any((i) => AppCurrency.isUsd(i.currency));

      final client = erp.clients
          .where((c) => c.name.trim() == project.clientName.trim())
          .firstOrNull;
      final isSypHolder = client != null && client.isSypCustomer;
      final isUsdHolder = client != null && client.isUsdCustomer;

      if (currencyFilter == AppCurrency.syp) {
        if (hasSypInvoice) {
          // matches
        } else if (isSypHolder && !hasUsdInvoice) {
          // matches
        } else if (linkedInvoices.isEmpty && isSypHolder) {
          // matches
        } else {
          return false;
        }
      } else {
        if (hasUsdInvoice) {
          // matches
        } else if (isUsdHolder && !hasSypInvoice) {
          // matches
        } else if (linkedInvoices.isEmpty && isUsdHolder) {
          // matches
        } else {
          return false;
        }
      }
    }

    if (query.trim().isEmpty) return true;

    final invNos = linkedInvoices.map((i) => i.invoiceNo).join(' ');
    final text = '${project.name} ${project.clientName} ${project.phone} ${project.description} $invNos';
    return arabicFuzzyMatch(text, query);
  }

  @override
  void dispose() {
    _workshopInvoicesSearchCtrl.dispose();
    _projectsSearchCtrl.dispose();
    _cashInvoicesSearchCtrl.dispose();
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
                  _buildWorkshopStockGrid(erp, m2, 'م²'),
                  _buildWorkshopStockGrid(erp, m3, 'م³'),
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
                                          t.complexity == 'معقد'
                                              ? '${t.name} • المتاح ${t.quantity.toInt() == t.quantity ? t.quantity.toInt() : t.quantity.fmt} قطعة'
                                              : '${t.name} • المتاح ${t.quantity.fmt} ${t.unitSymbol}',
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
                                        if (t.complexity == 'بسيط') ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: const Color(0xFFCBD5E1),
                                              ),
                                            ),
                                            child: const Text(
                                              'التسعير: تسعير فردي لكل بند على حدة (لا يوجد سعر إجمالي للتفصيل)',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF475569),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                  vertical: 2,
                                                ),
                                            child: Text(
                                              'عدد البنود: ${t.lineItems.length}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors
                                                    .brandSecondaryText,
                                              ),
                                            ),
                                          ),
                                        ] else ...[
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
                                              'صافي سعر التفصيل: ${t.totalNetCost.fmt} \$',
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
                                                color:
                                                    AppColors.panelBorder,
                                              ),
                                            ),
                                            child: Text(
                                              'سعر البيع: ${t.sellingPrice.fmt} \$',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    accent ??
                                                    AppColors.successGreen,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: const Color(0xFFCBD5E1),
                                              ),
                                            ),
                                            child: Text(
                                              'إجمالي القطع المتاحة: ${t.quantity.toInt() == t.quantity ? t.quantity.toInt() : t.quantity.fmt} قطعة',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.brandPrimaryText,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                  vertical: 2,
                                                ),
                                            child: Text(
                                              'عدد البنود: ${t.lineItems.length}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors
                                                    .brandSecondaryText,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (t.complexity == 'بسيط' && t.lineItems.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: AppColors.panelBorder,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.view_agenda_outlined,
                                                  size: 14,
                                                  color: AppColors
                                                      .brandSecondaryText,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'تفاصيل بنود المواد (${t.lineItems.length}):',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors
                                                        .brandSecondaryText,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 6,
                                              children: t.lineItems.map((li) {
                                                final typeStr =
                                                    '${li.typeName} ${li.grade}${li.thicknessCm > 0 ? " ${li.thicknessCm}سم" : ""}'
                                                        .trim();
                                                final lineSell =
                                                    li.sellingPricePerMeter > 0
                                                        ? li.sellingPricePerMeter
                                                        : (t.complexity == 'معقد'
                                                            ? t.sellingPrice
                                                            : 0.0);
                                                return Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(6),
                                                    border: Border.all(
                                                      color: const Color(
                                                        0xFFCBD5E1,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Wrap(
                                                    crossAxisAlignment:
                                                        WrapCrossAlignment
                                                            .center,
                                                    spacing: 8,
                                                    runSpacing: 4,
                                                    children: [
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          const Icon(
                                                            Icons.layers,
                                                            size: 13,
                                                            color: AppColors
                                                                .accentPrimary,
                                                          ),
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          Text(
                                                            'نوع الرخام: $typeStr',
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: AppColors
                                                                  .brandPrimaryText,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      Text(
                                                        '•',
                                                        style: TextStyle(
                                                          color: Colors
                                                              .grey.shade400,
                                                        ),
                                                      ),
                                                      Text(
                                                        'الكمية المتاحة: ${li.area.fmt} ${li.category == "متر مكعب" ? "م³" : "م²"}',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Color(
                                                            0xFF15803D,
                                                          ),
                                                        ),
                                                      ),
                                                      Text(
                                                        '•',
                                                        style: TextStyle(
                                                          color: Colors
                                                              .grey.shade400,
                                                        ),
                                                      ),
                                                      Text(
                                                        'سعر البند: ${lineSell.fmt} \$ / ${li.category == "متر مكعب" ? "م³" : "م²"}',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: AppColors
                                                              .accentPrimary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (t.complexity == 'معقد') ...[
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        AppColors.partnersEquityAccent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                  ),
                                  onPressed: () =>
                                      _showAddComplexTailoringInventoryDialog(
                                    erp,
                                    t,
                                  ),
                                  icon: const Icon(
                                    Icons.add_box_outlined,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'إضافة مخزون للتفصيل ككل',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: AppColors.brandPrimaryText,
                                    side: const BorderSide(
                                      color: AppColors.panelBorder,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                  ),
                                  onPressed: () =>
                                      _showTailoringDetailsModal(erp, t),
                                  icon: const Icon(
                                    Icons.info_outline_rounded,
                                    size: 16,
                                    color: AppColors.accentPrimary,
                                  ),
                                  label: const Text(
                                    'التفاصيل',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ] else ...[
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
                                const SizedBox(width: 6),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: AppColors.brandPrimaryText,
                                    side: const BorderSide(
                                      color: AppColors.panelBorder,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                  ),
                                  onPressed: () =>
                                      _showTailoringDetailsModal(erp, t),
                                  icon: const Icon(
                                    Icons.info_outline_rounded,
                                    size: 16,
                                    color: AppColors.accentPrimary,
                                  ),
                                  label: const Text(
                                    'التفاصيل',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
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
            child: Builder(
              builder: (context) {
                final activeOrders = erp.workshopOrders
                    .where((o) => o.status == 'قيد التنفيذ')
                    .toList();
                if (activeOrders.isEmpty) {
                  return const Card(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.assignment_outlined, size: 48, color: Colors.grey),
                            SizedBox(height: 12),
                            Text(
                              'لا توجد طلبيات معمل قيد التنفيذ حالياً.',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'الطلبيات المُرحلة لفواتير تنتقل تلقائياً إلى سجل الفواتير وقسم الزبائن في المالية.',
                              style: TextStyle(fontSize: 13, color: AppColors.brandSecondaryText),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return Card(
                  child: ListView.separated(
                    itemCount: activeOrders.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final ord = activeOrders[idx];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'الهاتف: ${ord.clientPhone}${ord.photoPath.isEmpty ? "" : " • مرفق صورة"}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (ord.items.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: ord.items.map((i) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Text(
                                    '${i.description} (${i.quantity.fmt} ${i.unitCategory} × ${i.unitPrice.fmt}\$ = ${i.agreedPrice.fmt}\$)',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                                  ),
                                )).toList(),
                              ),
                            ] else if (ord.customDimensionsText.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'التفاصيل: ${ord.customDimensionsText}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'السعر: ${ord.agreedPrice.fmt}${ord.currencySymbol}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'العربون: ${ord.depositAmount.fmt}${ord.currencySymbol} (صندوق الطلبيات)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.orderDepositBoxAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onPressed: () => showWorkshopOrderPreview(context, ord),
                              icon: const Icon(Icons.print_outlined, size: 16),
                              label: const Text('معاينة للورشة'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.dangerWaste,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onPressed: () => showCancelWorkshopOrderDialog(context, erp, ord),
                              icon: const Icon(Icons.cancel_outlined, size: 16),
                              label: const Text('إلغاء الطلبية'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelOrderDialog(ERPProvider erp, WorkshopOrderModel ord) {
    showCancelWorkshopOrderDialog(context, erp, ord);
  }

  // -------------------------------------------------------------
  // SUB-TAB 6: WORKSHOP INVOICES
  // -------------------------------------------------------------
  Widget _buildTab6Invoices(ERPProvider erp, {bool cashOnly = false}) {
    final rawInvoices = cashOnly
        ? erp.workshopInvoices
              .where((invoice) => invoice.isCashInvoice)
              .toList()
        : erp.workshopInvoices;

    final searchCtrl =
        cashOnly ? _cashInvoicesSearchCtrl : _workshopInvoicesSearchCtrl;
    final searchQuery =
        cashOnly ? _cashInvoicesSearch : _workshopInvoicesSearch;
    final currencyFilter =
        cashOnly ? _cashInvoicesCurrency : _workshopInvoicesCurrency;

    final invoices = rawInvoices
        .where((inv) => _matchesWorkshopInvoice(
              inv,
              searchQuery,
              currencyFilter,
              erp,
            ))
        .toList();

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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
          const SizedBox(height: 12),
          SectionSearchAndFilterBar(
            searchController: searchCtrl,
            searchQuery: searchQuery,
            onSearchChanged: (v) => setState(() {
              if (cashOnly) {
                _cashInvoicesSearch = v;
              } else {
                _workshopInvoicesSearch = v;
              }
            }),
            selectedCurrency: currencyFilter,
            onCurrencyChanged: (c) => setState(() {
              if (cashOnly) {
                _cashInvoicesCurrency = c;
              } else {
                _workshopInvoicesCurrency = c;
              }
            }),
            hintText: cashOnly
                ? 'بحث في فواتير المعمل النقدية بالاسم، الهاتف، أو رقم الفاتورة...'
                : 'بحث في فواتير المعمل بالاسم، الهاتف، أو رقم الفاتورة...',
            onClear: () => setState(() {
              if (cashOnly) {
                _cashInvoicesSearch = '';
              } else {
                _workshopInvoicesSearch = '';
              }
            }),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: invoices.isEmpty
                ? const Card(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'لا توجد فواتير مطابقة للبحث أو التصفية الحالية.',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ),
                    ),
                  )
                : Card(
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
  // -------------------------------------------------------------
  // SUB-TAB 7: WORKSHOP PROJECTS (All / Pending / Completed-Paid)
  // -------------------------------------------------------------
  Widget _buildTab7Projects(ERPProvider erp) {
    final filteredProjects = erp.workshopProjects
        .where((p) => _matchesWorkshopProject(
              p,
              _projectsSearch,
              _projectsCurrency,
              erp,
            ))
        .toList();

    final allProjects = filteredProjects;
    final pending = filteredProjects
        .where((p) => erp.pendingProjects.contains(p))
        .toList();
    final completed = filteredProjects
        .where((p) => erp.completedProjects.contains(p))
        .toList();
    final projectInvs = erp.workshopInvoices
        .where((i) =>
            i.projectId.isNotEmpty &&
            filteredProjects.any((p) => p.id == i.projectId))
        .toList();

    return DefaultTabController(
      length: 3,
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
            // Summary cards
            Row(
              children: [
                _buildProjectSummaryStatCard('كافة المشاريع', '${allProjects.length}', AppColors.accentPrimary),
                const SizedBox(width: 8),
                _buildProjectSummaryStatCard('بانتظار الدفع', '${pending.length}', AppColors.dangerWaste),
                const SizedBox(width: 8),
                _buildProjectSummaryStatCard('مكتملة ومسددة', '${completed.length}', AppColors.successGreen),
                const SizedBox(width: 8),
                _buildProjectSummaryStatCard('فواتير المشاريع', '${projectInvs.length}', const Color(0xFF6366F1)),
              ],
            ),
            const SizedBox(height: 12),
            SectionSearchAndFilterBar(
              searchController: _projectsSearchCtrl,
              searchQuery: _projectsSearch,
              onSearchChanged: (v) => setState(() => _projectsSearch = v),
              selectedCurrency: _projectsCurrency,
              onCurrencyChanged: (c) => setState(() => _projectsCurrency = c),
              hintText: 'بحث في المشاريع بالاسم، العميل، الهاتف، أو رقم الفاتورة...',
              onClear: () => setState(() => _projectsSearch = ''),
            ),
            const SizedBox(height: 12),
            Container(
              color: const Color(0xFFF1F5F9),
              child: TabBar(
                tabs: [
                  Tab(text: 'كافة المشاريع (${allProjects.length})'),
                  Tab(text: 'بانتظار الدفع (${pending.length})'),
                  Tab(text: 'مكتملة / مدفوعة (${completed.length})'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [
                  _buildProjectList(
                    erp,
                    allProjects,
                    'لا توجد مشاريع مسجلة بعد. انقر على زر إضافة مشروع للبدء.',
                  ),
                  _buildProjectList(
                    erp,
                    pending,
                    'لا توجد مشاريع بانتظار الدفع.',
                  ),
                  _buildProjectList(
                    erp,
                    completed,
                    'لا توجد مشاريع مكتملة ومسددة بعد.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectSummaryStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
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
      return Card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(emptyHint, style: const TextStyle(color: AppColors.brandSecondaryText)),
          ),
        ),
      );
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
          final dueSyp = erp.projectDueSyp(p.id);
          final invTotalUsd = invs.where((i) => i.currency == AppCurrency.usd).fold<double>(0.0, (s, i) => s + i.grandTotal);
          final invTotalSyp = invs.where((i) => i.currency == AppCurrency.syp).fold<double>(0.0, (s, i) => s + i.grandTotal);
          final collectedUsd = invs.where((i) => i.currency == AppCurrency.usd).fold<double>(0.0, (s, i) => s + (i.cashPaidNow + i.depositDeducted));
          final collectedSyp = invs.where((i) => i.currency == AppCurrency.syp).fold<double>(0.0, (s, i) => s + (i.cashPaidNow + i.depositDeducted));
          final isFullyPaid = invs.isNotEmpty && due <= 0.01 && dueSyp <= 0.01;

          return ExpansionTile(
            leading: p.photoPath.isNotEmpty
                ? AppImageThumbnail(
                    imagePath: p.photoPath,
                    width: 44,
                    height: 44,
                    title: 'مخطط / صورة المشروع (${p.name})',
                  )
                : const CircleAvatar(
                    backgroundColor: AppColors.chipBgSky,
                    child: Icon(
                      Icons.domain_rounded,
                      color: AppColors.orderDepositBoxAccent,
                    ),
                  ),
            title: Row(
              children: [
                Text(
                  'المشروع: ${p.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(
                    Icons.picture_as_pdf_rounded,
                    size: 15,
                  ),
                  label: const Text(
                    'معاينة كشف الحساب قبل الطباعة',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () {
                    A4StatementPrintDialog.show(
                      context,
                      statementData: A4StatementData.fromProject(
                        project: p,
                        erp: erp,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                if (isFullyPaid)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('مسدد بالكامل', style: TextStyle(fontSize: 10, color: AppColors.successGreen, fontWeight: FontWeight.bold)),
                  )
                else if (due > 0.01 || dueSyp > 0.01)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('متبقي: ${AppCurrency.dual(due, dueSyp)}', style: const TextStyle(fontSize: 10, color: AppColors.dangerWaste, fontWeight: FontWeight.bold)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('بانتظار إصدار فواتير', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            subtitle: Text(
              'الزبون: ${p.clientName} ${p.phone.isNotEmpty ? "(${p.phone})" : ""} • الفواتير: ${invs.length} • المحصل: ${AppCurrency.dual(collectedUsd, collectedSyp)} • المتبقي: ${AppCurrency.dual(due, dueSyp)}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.add_shopping_cart_rounded,
                    color: AppColors.successGreen,
                  ),
                  tooltip: 'إضافة فاتورة لهذا المشروع',
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
                                  items: old.items,
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: AppImagePreviewCard(
                    imagePath: p.photoPath,
                    title: 'مخطط / صورة المشروع (${p.name})',
                  ),
                ),
              if (p.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.notes_rounded, size: 16, color: Colors.blueGrey),
                      const SizedBox(width: 6),
                      Expanded(child: Text(p.description, style: const TextStyle(fontSize: 12, color: Colors.black87))),
                    ],
                  ),
                ),
              // Financial Summary Banner inside Project Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 4,
                        children: [
                          Text('إجمالي الفواتير: ${AppCurrency.dual(invTotalUsd, invTotalSyp)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('المحصل: ${AppCurrency.dual(collectedUsd, collectedSyp)}', style: const TextStyle(fontSize: 12, color: AppColors.successGreen, fontWeight: FontWeight.bold)),
                          Text('المتبقي: ${AppCurrency.dual(due, dueSyp)}', style: TextStyle(fontSize: 12, color: (due > 0.01 || dueSyp > 0.01) ? AppColors.dangerWaste : Colors.grey, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orderDepositBoxAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => _showAddWorkshopInvoiceDialog(
                        erp,
                        presetProjectId: p.id,
                        presetClientName: p.clientName,
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('إضافة فاتورة للمشروع', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              // Invoices belonging to this project
              if (invs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'لا توجد فواتير لهذا المشروع بعد. أصدر فاتورة من الزر أعلاه.',
                      style: TextStyle(color: AppColors.brandSecondaryText, fontSize: 13),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          'فواتير المشروع (${invs.length}):',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
                        ),
                      ),
                      ...invs.map((inv) {
                        final isInvPaid = inv.remainingBalance <= 0.01;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isInvPaid ? const Color(0xFFE2E8F0) : const Color(0xFFFECACA),
                            ),
                            boxShadow: const [
                              BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CurrencyBadge(currency: inv.currency),
                                  const SizedBox(width: 8),
                                  Text(
                                    inv.invoiceNo,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    intl.DateFormat('yyyy/MM/dd HH:mm').format(inv.date),
                                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                                  ),
                                  const Spacer(),
                                  if (isInvPaid)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text('خالصة ومسددة بالكامل', style: TextStyle(fontSize: 11, color: AppColors.successGreen, fontWeight: FontWeight.bold)),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text('متبقي: ${inv.remainingBalance.fmt} ${inv.currencySymbol}', style: const TextStyle(fontSize: 11, color: AppColors.dangerWaste, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (inv.items.isNotEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: inv.items.map((it) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 1),
                                    child: Text(
                                      '• ${it.description} — ${it.quantity.fmt} ${it.unitCategory} × ${it.unitPrice.fmt} = ${it.agreedPrice.fmt} ${inv.currencySymbol}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                                    ),
                                  )).toList(),
                                )
                              else
                                Text(
                                  '• ${inv.itemDescription} (${inv.sourceQuantity.fmt} ${inv.sourceUnitCategory})',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                                ),
                              if (inv.services.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  'الخدمات: ${inv.services.map((s) => "${s.serviceName}: ${s.price.fmt}${inv.currencySymbol}").join(" + ")}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF0D9488)),
                                ),
                              ],
                              const Divider(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: Wrap(
                                      spacing: 12,
                                      runSpacing: 4,
                                      children: [
                                        Text('الإجمالي: ${inv.grandTotal.fmt} ${inv.currencySymbol}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        Text('المدفوع: ${(inv.cashPaidNow + inv.depositDeducted).fmt} ${inv.currencySymbol}', style: const TextStyle(fontSize: 12, color: AppColors.successGreen, fontWeight: FontWeight.bold)),
                                        Text('المتبقي: ${inv.remainingBalance.fmt} ${inv.currencySymbol}', style: TextStyle(fontSize: 12, color: isInvPaid ? Colors.grey : AppColors.dangerWaste, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 20, color: Color(0xFF2563EB)),
                                    tooltip: 'معاينة وطباعة الفاتورة A4',
                                    onPressed: () => A4InvoicePrintDialog.show(
                                      context,
                                      invoiceData: A4InvoiceData.fromWorkshopInvoice(inv),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.print_rounded, size: 20, color: Color(0xFF475569)),
                                    tooltip: 'إيصال حراري',
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => ThermalReceiptDialog(
                                          title: 'فاتورة مشروع معمل',
                                          invoiceNo: inv.invoiceNo,
                                          dateText: intl.DateFormat('yyyy-MM-dd').format(inv.date),
                                          partyName: inv.clientName,
                                          items: inv.items.isNotEmpty
                                              ? [
                                                  ...inv.items.expand(
                                                    (item) => [
                                                      {
                                                        'name': item.description,
                                                        'details': item.sourceType,
                                                        'qty': '${item.quantity.fmt} ${item.unitCategory == "متر مكعب" ? "م³" : item.unitCategory == "متر مربع" ? "م²" : "وحدة"}',
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
                                                    'qty': inv.sourceQuantity > 0 ? '${inv.sourceQuantity.fmt} ${inv.sourceUnitCategory}' : '1',
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
                                          advancePayment: inv.cashPaidNow + inv.depositDeducted,
                                          grandTotal: inv.grandTotal,
                                          remainingBalance: inv.remainingBalance,
                                        ),
                                      );
                                    },
                                  ),
                                  if (!isInvPaid) ...[
                                    const SizedBox(width: 4),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.successGreen,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        minimumSize: const Size(60, 32),
                                      ),
                                      onPressed: () => _showCollectProjectInvoiceDialog(erp, inv),
                                      child: const Text('تحصيل', style: TextStyle(fontSize: 12)),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }

  void _showCollectProjectInvoiceDialog(ERPProvider erp, WorkshopInvoiceModel inv) {
    final amountCtrl = TextEditingController(text: inv.remainingBalance.fmt);
    String? errorMsg;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setSt) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.payments_rounded, color: AppColors.successGreen),
                const SizedBox(width: 8),
                Expanded(child: Text('تحصيل دفعة من فاتورة ${inv.invoiceNo}')),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('العميل: ${inv.clientName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.panelBorder),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('إجمالي الفاتورة:', style: TextStyle(fontSize: 12)),
                            Text('${inv.grandTotal.fmt} ${inv.currencySymbol}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('المسدد سابقاً:', style: TextStyle(fontSize: 12)),
                            Text('${(inv.cashPaidNow + inv.depositDeducted).fmt} ${inv.currencySymbol}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.successGreen)),
                          ],
                        ),
                        const Divider(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('الرصيد المتبقي للتحصيل:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            Text(
                              '${inv.remainingBalance.fmt} ${inv.currencySymbol}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.dangerWaste),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'المبلغ المحصل الآن (${inv.currencySymbol})',
                      helperText: 'الحد الأقصى المسموح: ${inv.remainingBalance.fmt} ${inv.currencySymbol}',
                      errorText: errorMsg,
                      suffixIcon: TextButton(
                        onPressed: () {
                          setSt(() {
                            amountCtrl.text = inv.remainingBalance.fmt;
                            errorMsg = null;
                          });
                        },
                        child: const Text('كامل المتبقي', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                    onChanged: (val) {
                      final parsed = double.tryParse(val.trim()) ?? 0.0;
                      setSt(() {
                        if (parsed > inv.remainingBalance + 0.001) {
                          errorMsg = 'خطأ: المبلغ المدخل يتجاوز الرصيد المتبقي (${inv.remainingBalance.fmt} ${inv.currencySymbol})!';
                        } else if (parsed <= 0 && val.trim().isNotEmpty) {
                          errorMsg = 'المبلغ يجب أن يكون أكبر من الصفر';
                        } else {
                          errorMsg = null;
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('إلغاء')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.successGreen,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 16),
                label: const Text('تأكيد التحصيل'),
                onPressed: () {
                  final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                  if (amt <= 0) {
                    setSt(() => errorMsg = 'يرجى إدخال مبلغ صحيح أكبر من الصفر.');
                    return;
                  }
                  if (amt > inv.remainingBalance + 0.001) {
                    setSt(() => errorMsg = 'خطأ: المبلغ المدخل (${amt.fmt}) يتجاوز الرصيد المتبقي للتحصيل (${inv.remainingBalance.fmt} ${inv.currencySymbol})!');
                    return;
                  }
                  final ok = erp.collectWorkshopInvoice(inv, amt);
                  if (!ok) {
                    setSt(() => errorMsg = 'تعذر تنفيذ عملية التحصيل.');
                    return;
                  }
                  Navigator.pop(dctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم تحصيل ${amt.fmt} ${inv.currencySymbol} بنجاح وترحيلها للصندوق.'),
                      backgroundColor: AppColors.successGreen,
                    ),
                  );
                },
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
  /// Tailoring details: every line item grouped/categorized by type,
  /// with ability to edit the selling price for any individual line item.
  void _showTailoringDetailsModal(ERPProvider erp, WorkshopTailoringModel t) {
    final sellingCtrl = TextEditingController(text: t.sellingPrice.fmt);
    final Map<String, TextEditingController> lineSellingCtrls = {
      for (final li in t.lineItems)
        li.id: TextEditingController(
          text: (li.sellingPricePerMeter > 0
                  ? li.sellingPricePerMeter
                  : t.sellingPrice)
              .fmt,
        ),
    };
    final Map<String, TextEditingController> qtyCtrls = {
      for (final li in t.lineItems)
        li.id: TextEditingController(text: li.quantity.fmt),
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          // Group line items by material type
          final Map<String, List<TailoringLineItem>> groupedLines = {};
          for (final li in t.lineItems) {
            final typeStr =
                '${li.typeName} ${li.grade}${li.thicknessCm > 0 ? " ${li.thicknessCm}سم" : ""}'
                    .trim();
            final key = typeStr.isNotEmpty
                ? typeStr
                : (li.source == 'scrap' ? 'خردة وزيادات' : 'خامة عامة');
            groupedLines.putIfAbsent(key, () => []).add(li);
          }

          return Dialog(
            child: Container(
              width: 720,
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.accentPrimary,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تفاصيل: ${t.name} (${t.complexity})',
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(fontSize: 18),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Text(
                      'المادة الأساسية: ${t.rawMaterialDescription}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (t.complexity == 'معقد') ...[
                          Text(
                            'إجمالي القطع المتاحة: ${t.quantity.toInt() == t.quantity ? t.quantity.toInt() : t.quantity.fmt} قطعة',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF15803D),
                            ),
                          ),
                          Text(
                            'صافي سعر التفصيل (شامل الخدمات): ${t.totalNetCost.fmt} \$',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.brandPrimaryText,
                            ),
                          ),
                          Text(
                            'إجمالي سعر البيع: ${t.sellingPrice.fmt} \$',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.accentPrimary,
                            ),
                          ),
                        ] else ...[
                          Text(
                            'الكمية الكلية المتاحة: ${t.quantity.fmt} ${t.unitSymbol}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF15803D),
                            ),
                          ),
                          const Text(
                            'التسعير: تسعير فردي لكل بند على حدة (لا يوجد سعر إجمالي للتفصيل)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.accentPrimary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (t.photoPath.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: AppImagePreviewCard(
                          imagePath: t.photoPath,
                          title: 'صورة التفصيل المرفقة (${t.name})',
                        ),
                      ),
                    const SizedBox(height: 14),

                    // Section: Line items categorized by type
                    Row(
                      children: [
                        const Icon(
                          Icons.category_outlined,
                          size: 18,
                          color: AppColors.accentPrimary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'بنود التفصيل مصنفة حسب نوع الرخام / الخامة (${groupedLines.length} أنواع • ${t.lineItems.length} بنود):',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.brandPrimaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (t.lineItems.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.panelBorder),
                        ),
                        child: Text(
                          'الأبعاد: ${t.lengthCm}x${t.widthCm}${t.unitCategory == 'متر مكعب' ? 'x${t.heightCm}' : ''} سم • ${t.measurementCount.fmt} × ${t.measurementPerCount.fmt} ${t.unitSymbol}',
                        ),
                      ),

                    ...groupedLines.entries.map((entry) {
                      final typeKey = entry.key;
                      final lines = entry.value;
                      final totalArea = lines.fold<double>(
                        0.0,
                        (sum, item) => sum + item.area,
                      );
                      final categoryUnit = lines.first.category;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.panelBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Group Header Banner
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEDF2F7),
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(9),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.layers_outlined,
                                    size: 16,
                                    color: AppColors.brandPrimaryText,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'نوع الرخام / الخامة: $typeKey',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppColors.brandPrimaryText,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(0xFFCBD5E1),
                                      ),
                                    ),
                                    child: Text(
                                      'المتاح: ${totalArea.fmt} $categoryUnit (${lines.length} بنود)',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF15803D),
                                      ),
                                    ),
                                  ),
                                  if (t.complexity == 'بسيط') ...[
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppColors.accentPrimary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 6,
                                        ),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        _showAddTailoringInventoryDialog(
                                          erp,
                                          t,
                                          lines.first.id,
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.add_box_outlined,
                                        size: 14,
                                      ),
                                      label: const Text(
                                        'إضافة مخزون',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Items in this group
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                children: lines.map((li) {
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'بند: الطول ${li.lengthCm} سم • العرض ${li.widthCm} سم${li.category == 'متر مكعب' ? ' • الارتفاع ${li.heightCm} سم' : ''} • الكمية: ${li.quantity.fmt} قطع (${li.area.fmt} ${li.category})',
                                                  style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color:
                                                      AppColors.dangerWaste,
                                                  size: 20,
                                                ),
                                                tooltip:
                                                    'حذف البند وإرجاع مخزونه',
                                                onPressed: () {
                                                  if (li.source ==
                                                      'materials') {
                                                    erp.restoreWorkshopStock(
                                                      li.stockId,
                                                      li.area,
                                                    );
                                                  } else {
                                                    final m = erp.scrapItems
                                                        .where(
                                                          (s) =>
                                                              s.id ==
                                                              li.stockId,
                                                        )
                                                        .toList();
                                                    if (m.isNotEmpty) {
                                                      m.first.isSold = false;
                                                    }
                                                  }
                                                  t.lineItems.remove(li);
                                                  qtyCtrls.remove(li.id);
                                                  lineSellingCtrls.remove(li.id);
                                                  erp.refresh();
                                                  setSt(() {});
                                                },
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 12,
                                            runSpacing: 4,
                                            children: [
                                              Text(
                                                'تكلفة المتر الأصلية: ${li.netCostPerMeter.fmt} \$',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors
                                                      .brandSecondaryText,
                                                ),
                                              ),
                                              Text(
                                                'تكلفة المتر بعد الخدمات: ${li.netCostPerMeterAfterServices.fmt} \$',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF166534),
                                                ),
                                              ),
                                              Text(
                                                'إجمالي سعر البند: ${li.lineTotal.fmt} \$',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      AppColors.successGreen,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (li.services.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'الخدمات المرفقة: ${li.services.map((s) => '${s.serviceName} (${s.price}\$)').join('، ')}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors
                                                    .brandSecondaryText,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 8),

                                          // Editable Selling Price for this specific line item
                                          if (t.complexity == 'بسيط') ...[
                                            Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.chipBgBlue,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: AppColors.panelBorder,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: TextField(
                                                    controller:
                                                        lineSellingCtrls[li.id],
                                                    keyboardType:
                                                        const TextInputType
                                                            .numberWithOptions(
                                                          decimal: true,
                                                        ),
                                                    decoration:
                                                        InputDecoration(
                                                      labelText:
                                                          'سعر بيع المتر لهذا البند (\$ / ${li.category})',
                                                      isDense: true,
                                                      prefixIcon: const Icon(
                                                        Icons.sell_outlined,
                                                        size: 16,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor: AppColors
                                                        .accentPrimary,
                                                    padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                      horizontal: 10,
                                                      vertical: 8,
                                                    ),
                                                  ),
                                                  onPressed: () {
                                                    final newSell =
                                                        double.tryParse(
                                                          lineSellingCtrls[
                                                                  li.id]!
                                                              .text,
                                                        ) ??
                                                        li.sellingPricePerMeter;
                                                    if (newSell > 0) {
                                                      li.sellingPricePerMeter =
                                                          newSell;
                                                      if (t.complexity != 'بسيط') {
                                                        final double totalArea =
                                                            t.lineItems.fold<
                                                              double
                                                            >(
                                                              0.0,
                                                              (s, l) =>
                                                                  s + l.area,
                                                            );
                                                        if (totalArea > 0) {
                                                          t.sellingPrice =
                                                              t.lineItems.fold<
                                                                    double
                                                                  >(
                                                                    0.0,
                                                                    (s, l) =>
                                                                        s +
                                                                        (l.area *
                                                                            l.sellingPricePerMeter),
                                                                  ) /
                                                              totalArea;
                                                          sellingCtrl.text =
                                                              t.sellingPrice.fmt;
                                                        }
                                                      }
                                                      erp.saveToDisk();
                                                      erp.notifyListeners();
                                                      setSt(() {});
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            'تم تحديث سعر بيع بند "${li.typeName}" إلى ${newSell.fmt} \$ بنجاح.',
                                                          ),
                                                          backgroundColor:
                                                              AppColors
                                                                  .successGreen,
                                                          duration:
                                                              const Duration(
                                                                seconds: 2,
                                                              ),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  child: const Text(
                                                    'تطبيق السعر',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],

                                          // Per-line pieces consumption adjustment
                                          if (li.source == 'materials') ...[
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextField(
                                                    controller: qtyCtrls[li.id],
                                                    keyboardType:
                                                        TextInputType.number,
                                                    decoration:
                                                        const InputDecoration(
                                                      labelText:
                                                          'تعديل كمية قطع البند',
                                                      isDense: true,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                OutlinedButton(
                                                  onPressed: () {
                                                    final nv =
                                                        double.tryParse(
                                                          qtyCtrls[li.id]!
                                                              .text,
                                                        ) ??
                                                        li.quantity;
                                                    if (nv <= 0) return;
                                                    final oldQty = li.quantity;
                                                    final oldArea = li.area;
                                                    li.quantity = nv;
                                                    final delta =
                                                        li.area - oldArea;
                                                    if (delta > 0) {
                                                      final ok = erp
                                                          .deductWorkshopStock(
                                                            li.stockId,
                                                            delta,
                                                          );
                                                      if (!ok) {
                                                        li.quantity = oldQty;
                                                        qtyCtrls[li.id]!.text =
                                                            oldQty.fmt;
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                              'لا يوجد مخزون كافٍ في مواد المعمل لهذه الزيادة.',
                                                            ),
                                                            backgroundColor:
                                                                AppColors
                                                                    .dangerWaste,
                                                          ),
                                                        );
                                                        return;
                                                      }
                                                      t.quantity += delta;
                                                    } else if (delta < 0) {
                                                      erp.restoreWorkshopStock(
                                                        li.stockId,
                                                        -delta,
                                                      );
                                                      t.quantity += delta;
                                                    }
                                                    erp.refresh();
                                                    setSt(() {});
                                                  },
                                                  child: const Text(
                                                    'تعديل القطع',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),

                    if (t.complexity == 'معقد') ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: sellingCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'إجمالي سعر البيع للتفصيل المعقد (\$)',
                          isDense: true,
                          prefixIcon: Icon(Icons.sell_outlined),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (t.complexity == 'معقد') {
                          _showAddComplexTailoringInventoryDialog(erp, t);
                        } else {
                          _showAddTailoringInventoryDialog(erp, t);
                        }
                      },
                      icon: const Icon(Icons.add_box_outlined, size: 16),
                      label: Text(
                        t.complexity == 'معقد'
                            ? 'إضافة مخزون للتفصيل ككل (زيادة قطع وخصم مواد)'
                            : 'إضافة مخزون للتفصيل حسب البند والنوع من صفحة مواد المعمل',
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
                              // Save all individual line selling prices
                              for (final li in t.lineItems) {
                                if (lineSellingCtrls.containsKey(li.id)) {
                                  final p = double.tryParse(
                                    lineSellingCtrls[li.id]!.text,
                                  );
                                  if (p != null && p > 0) {
                                    li.sellingPricePerMeter = p;
                                  }
                                }
                              }
                              if (t.complexity == 'معقد') {
                                final enteredSelling = double.tryParse(
                                  sellingCtrl.text.trim(),
                                );
                                if (enteredSelling != null &&
                                    enteredSelling > 0) {
                                  t.sellingPrice = enteredSelling;
                                }
                              }
                              erp.saveToDisk();
                              erp.notifyListeners();
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'تم حفظ التعديلات وأسعار بيع البنود بنجاح.',
                                  ),
                                  backgroundColor: AppColors.successGreen,
                                ),
                              );
                            },
                            child: const Text('حفظ جميع التعديلات'),
                          ),
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

  void _showAddTailoringInventoryDialog(
    ERPProvider erp,
    WorkshopTailoringModel t, [
    String? initialLineId,
  ]) {
    if (t.lineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد بنود لهذا التفصيل لإضافة مخزون إليها.'),
          backgroundColor: AppColors.dangerWaste,
        ),
      );
      return;
    }

    String selectedLineId = (initialLineId != null &&
            t.lineItems.any((li) => li.id == initialLineId))
        ? initialLineId
        : t.lineItems.first.id;

    final initialLine = t.lineItems.firstWhere(
      (item) => item.id == selectedLineId,
      orElse: () => t.lineItems.first,
    );

    final addQtyCtrl = TextEditingController(text: '1');
    final lineSellingPriceCtrl = TextEditingController(
      text: (initialLine.sellingPricePerMeter > 0
              ? initialLine.sellingPricePerMeter
              : (t.complexity == 'معقد' ? t.sellingPrice : 0.0))
          .fmt,
    );
    String? formError;
    String? selectedWsId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final li = t.lineItems.firstWhere(
            (item) => item.id == selectedLineId,
            orElse: () => t.lineItems.first,
          );

          // Group all line items by material type for clear categorized selection
          final Map<String, List<TailoringLineItem>> groupedLines = {};
          for (final item in t.lineItems) {
            final typeStr =
                '${item.typeName} ${item.grade}${item.thicknessCm > 0 ? " ${item.thicknessCm}سم" : ""}'
                    .trim();
            final key = typeStr.isNotEmpty
                ? typeStr
                : (item.source == 'scrap' ? 'خردة' : 'بدون نوع');
            groupedLines.putIfAbsent(key, () => []).add(item);
          }

          // Find best matching material in erp.workshopStock for this specific line type
          final matchingStockItems = erp.workshopStock.where((w) {
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

          final bestMatch = matchingStockItems.isNotEmpty
              ? matchingStockItems.first
              : (erp.workshopStock.any((w) => w.typeName == li.typeName)
                  ? erp.workshopStock.firstWhere(
                      (w) => w.typeName == li.typeName,
                    )
                  : (erp.workshopStock.isNotEmpty
                      ? erp.workshopStock.first
                      : null));

          selectedWsId ??= bestMatch?.id;
          final currentWs = erp.workshopStock.firstWhere(
            (w) => w.id == selectedWsId,
            orElse: () =>
                bestMatch ??
                (erp.workshopStock.isNotEmpty
                    ? erp.workshopStock.first
                    : WorkshopStockModel(
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
          final double currentMeterPrice = currentWs.netCostPerUnit;
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
                Expanded(
                  child: Text(
                    'إضافة مخزون لتفصيل: ${t.name} (حسب نوع الرخام والبند)',
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Line item selector grouped by type
                    const Text(
                      'اختر بند التفصيل المراد زيادة رصيده (مصنف حسب نوع الرخام):',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedLineId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.category_outlined, size: 18),
                      ),
                      items: groupedLines.entries.expand((entry) {
                        final typeName = entry.key;
                        return entry.value.map((item) {
                          return DropdownMenuItem<String>(
                            value: item.id,
                            child: Text(
                              '[$typeName] — (${item.lengthCm}×${item.widthCm}سم) • حالياً: ${item.quantity.fmt} قطع (${item.area.fmt} ${item.category})',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        });
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setSt(() {
                            selectedLineId = v;
                            selectedWsId = null;
                            final selectedLi = t.lineItems.firstWhere(
                              (it) => it.id == v,
                              orElse: () => t.lineItems.first,
                            );
                            lineSellingPriceCtrl.text =
                                (selectedLi.sellingPricePerMeter > 0
                                        ? selectedLi.sellingPricePerMeter
                                        : (t.complexity == 'معقد'
                                            ? t.sellingPrice
                                            : 0.0))
                                    .fmt;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Dimensions and quantity addition for this line item
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
                          Row(
                            children: [
                              const Icon(
                                Icons.layers,
                                size: 16,
                                color: AppColors.accentPrimary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'نوع الرخام والخامة للبند: ${li.typeName} ${li.grade}${li.thicknessCm > 0 ? " ${li.thicknessCm}سم" : ""}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.brandPrimaryText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'الأبعاد: الطول ${li.lengthCm} سم • العرض ${li.widthCm} سم ${isCube ? "• الارتفاع ${li.heightCm} سم" : ""} • مساحة القطعة: ${pieceArea.fmt} ${isCube ? "م³" : "م²"}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.brandSecondaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'الرصيد الحالي لهذا البند: ${li.quantity.fmt} قطع (${li.area.fmt} ${li.category}) • سعر البيع الحالي: ${li.sellingPricePerMeter.fmt} \$ / ${li.category}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF15803D),
                            ),
                          ),
                          const SizedBox(height: 10),
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
                                    labelText:
                                        'الكمية المراد إضافتها لهذا البند (عدد القطع)',
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
                    Text(
                      'المادة المسحوبة من صفحة مواد المعمل المطابقة لنوع [${li.typeName}]:',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (erp.workshopStock.isEmpty)
                      const Text(
                        'لا توجد مواد مسجلة في مواد المعمل.',
                        style: TextStyle(color: AppColors.dangerWaste),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: selectedWsId,
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true),
                        items: erp.workshopStock
                            .where(
                              (w) =>
                                  w.availableQty > 0 || w.id == selectedWsId,
                            )
                            .map((w) {
                          return DropdownMenuItem<String>(
                            value: w.id,
                            child: Text(
                              '${w.typeName} ${w.grade} ${w.thicknessCm}سم — متاح: ${w.availableQty.fmt} ${w.category} — سعر المتر: ${w.netCostPerUnit.fmt}\$',
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setSt(() => selectedWsId = v),
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
                              const Text(
                                'سعر متر المادة الحالي من صفحة مواد المعمل:',
                              ),
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
                              const Text(
                                'القيمة المضافة المحسوبة (الأمتار × سعر المتر):',
                              ),
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
                              const Text('المخزون المتاح في مواد المعمل:'),
                              Text(
                                '${currentWs.availableQty.fmt} ${li.category}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: currentWs.availableQty >= deltaArea
                                      ? AppColors.successGreen
                                      : AppColors.dangerWaste,
                                ),
                              ),
                            ],
                          ),
                          if (t.complexity != 'بسيط') ...[
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Per-line item selling price edit field
                    TextField(
                      controller: lineSellingPriceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText:
                            'سعر بيع المتر لهذا البند بعد الإضافة (\$ / ${li.category})',
                        isDense: true,
                        prefixIcon: const Icon(
                          Icons.price_change_outlined,
                          size: 18,
                        ),
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
                  if (currentWs.availableQty + 0.0001 < deltaArea) {
                    setSt(
                      () => formError =
                          'الكمية المحسوبة (${deltaArea.fmt} ${li.category}) تتجاوز المتاح في مواد المعمل (${currentWs.availableQty.fmt}).',
                    );
                    return;
                  }

                  final newSell =
                      double.tryParse(lineSellingPriceCtrl.text) ??
                      li.sellingPricePerMeter;
                  if (newSell < 0) {
                    setSt(() => formError = 'أدخل سعر بيع صحيح.');
                    return;
                  }

                  // 1. Deduct from Workshop Stock (مواد المعمل)
                  currentWs.availableQty =
                      (currentWs.availableQty - deltaArea).clamp(
                    0.0,
                    double.infinity,
                  );

                  // 2. Update line item pieces, weighted average cost, and individual selling price
                  final double oldLineArea = li.area;
                  final double oldLineCost = oldLineArea * li.netCostPerMeter;
                  li.quantity += addedQtyPieces;
                  final double newLineArea = li.area;
                  final double newLineCost = oldLineCost + addedValue;
                  li.netCostPerMeter = newLineArea > 0
                      ? (newLineCost / newLineArea)
                      : li.netCostPerMeter;
                  if (newSell > 0) {
                    li.sellingPricePerMeter = newSell;
                  }

                  // 3. Update tailoring quantity and recalculated weighted average selling price for complex tailoring only
                  t.quantity += deltaArea;
                  if (t.complexity != 'بسيط') {
                    final double totalArea = t.lineItems.fold<double>(
                      0.0,
                      (s, l) => s + l.area,
                    );
                    if (totalArea > 0) {
                      t.sellingPrice =
                          t.lineItems.fold<double>(
                            0.0,
                            (s, l) => s + (l.area * l.sellingPricePerMeter),
                          ) /
                          totalArea;
                    }
                  }

                  erp.saveToDisk();
                  erp.notifyListeners();
                  Navigator.pop(ctx);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تمت إضافة ${addedQtyPieces.fmt} قطع (${deltaArea.fmt} ${li.category}) لبند "${li.typeName}" بنجاح، وخُصمت من صفحة مواد المعمل.',
                      ),
                      backgroundColor: AppColors.successGreen,
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('تأكيد وإضافة المخزون للبند'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddComplexTailoringInventoryDialog(
    ERPProvider erp,
    WorkshopTailoringModel t,
  ) {
    if (t.lineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لا توجد بنود لهذا التفصيل المعقد لحساب استهلاك المواد.',
          ),
          backgroundColor: AppColors.dangerWaste,
        ),
      );
      return;
    }

    final addPiecesCtrl = TextEditingController(text: '1');
    final sellingPriceCtrl = TextEditingController(text: t.sellingPrice.fmt);
    String? formError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final int addedPieces = int.tryParse(addPiecesCtrl.text.trim()) ?? 0;
          final double baseCount = t.quantity > 0 ? t.quantity : 1.0;

          // Requirements per line item for addedPieces
          final requirements = t.lineItems.map((li) {
            final double perUnitPieces = li.quantity / baseCount;
            final double perUnitArea = li.area / baseCount;
            final double reqPieces =
                perUnitPieces * (addedPieces > 0 ? addedPieces : 0);
            final double reqArea =
                perUnitArea * (addedPieces > 0 ? addedPieces : 0);

            // Find matching workshop material in erp.workshopStock
            WorkshopStockModel? matchWs;
            if (li.stockId.isNotEmpty) {
              final byId = erp.workshopStock
                  .where((w) => w.id == li.stockId)
                  .toList();
              if (byId.isNotEmpty) matchWs = byId.first;
            }
            if (matchWs == null) {
              final bySpec = erp.workshopStock.where((w) {
                if (w.typeName != li.typeName) return false;
                if (li.grade.isNotEmpty && w.grade != li.grade) return false;
                if (li.thicknessCm > 0 &&
                    (w.thicknessCm - li.thicknessCm).abs() > 0.01) {
                  return false;
                }
                return true;
              }).toList();
              if (bySpec.isNotEmpty) {
                matchWs = bySpec.first;
              } else {
                final byType = erp.workshopStock
                    .where((w) => w.typeName == li.typeName)
                    .toList();
                if (byType.isNotEmpty) matchWs = byType.first;
              }
            }

            final bool hasEnough =
                matchWs != null && (matchWs.availableQty + 0.0001 >= reqArea);
            return (
              lineItem: li,
              matchWs: matchWs,
              reqPieces: reqPieces,
              reqArea: reqArea,
              hasEnough: hasEnough,
            );
          }).toList();

          final bool allMaterialsAvailable =
              requirements.every((r) => r.hasEnough);

          return AlertDialog(
            title: Row(
              children: [
                const Icon(
                  Icons.add_shopping_cart_rounded,
                  color: AppColors.partnersEquityAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'إضافة مخزون للتفصيل المعقد: ${t.name} (كقطعة كاملة)',
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 650,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Overview banner
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'الرصيد الحالي: ${t.quantity.toInt() == t.quantity ? t.quantity.toInt() : t.quantity.fmt} قطعة',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                              Text(
                                'صافي سعر التفصيل: ${t.totalNetCost.fmt} \$',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.brandPrimaryText,
                                ),
                              ),
                              Text(
                                'سعر البيع الحالي: ${t.sellingPrice.fmt} \$',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.accentPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'تنبيه: كل تفصيل معقد يحسب كوحدة/قطعة متكاملة. عند إضافة عدد من القطع، سيتم احتساب المواد المطلوبة لجميع بنود التفصيل وخصمها تلقائياً من مخزون مواد المعمل.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Inputs: number of pieces & unified selling price
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: addPiecesCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'عدد القطع المراد إضافتها للتفصيل',
                              isDense: true,
                              prefixIcon: Icon(
                                Icons.exposure_plus_1,
                                size: 18,
                              ),
                            ),
                            onChanged: (_) => setSt(() => formError = null),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: sellingPriceCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'سعر البيع الإجمالي للتفصيل (\$)',
                              isDense: true,
                              prefixIcon: Icon(
                                Icons.sell_outlined,
                                size: 18,
                              ),
                            ),
                            onChanged: (_) => setSt(() => formError = null),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Material requirements table
                    const Text(
                      'المواد المطلوبة للاستهلاك والخصم من مواد المعمل:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.brandPrimaryText,
                      ),
                    ),
                    const SizedBox(height: 6),

                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.panelBorder),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: requirements.map((req) {
                          final li = req.lineItem;
                          final match = req.matchWs;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: req.hasEnough
                                  ? Colors.white
                                  : AppColors.dangerWaste.withValues(
                                      alpha: 0.08,
                                    ),
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey.shade200,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.layers_outlined,
                                  size: 16,
                                  color: AppColors.brandPrimaryText,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${li.typeName} ${li.grade}${li.thicknessCm > 0 ? " ${li.thicknessCm}سم" : ""}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        'الأبعاد: ${li.lengthCm}×${li.widthCm}سم • المطلوب: ${req.reqArea.fmt} ${li.category} (${req.reqPieces.fmt} قطع)',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.brandSecondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'المتاح بالمعمل: ${match?.availableQty.fmt ?? "0"} ${li.category}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: req.hasEnough
                                            ? const Color(0xFF15803D)
                                            : AppColors.dangerWaste,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: req.hasEnough
                                            ? const Color(0xFFDCFCE7)
                                            : const Color(0xFFFEE2E2),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        req.hasEnough ? 'متوفر' : 'غير كافٍ',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: req.hasEnough
                                              ? const Color(0xFF166534)
                                              : const Color(0xFF991B1B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
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
                  backgroundColor: AppColors.partnersEquityAccent,
                ),
                onPressed: () {
                  if (addedPieces <= 0) {
                    setSt(
                      () => formError = 'أدخل عدد قطع صحيح أكبر من الصفر.',
                    );
                    return;
                  }
                  if (!allMaterialsAvailable) {
                    final shortage =
                        requirements.firstWhere((r) => !r.hasEnough);
                    setSt(
                      () => formError =
                          'نقص في مخزون مواد المعمل لـ [${shortage.lineItem.typeName}]. المطلوب ${shortage.reqArea.fmt} ${shortage.lineItem.category} والمتاح ${shortage.matchWs?.availableQty.fmt ?? "0"}.',
                    );
                    return;
                  }

                  final newSell =
                      double.tryParse(sellingPriceCtrl.text.trim()) ??
                          t.sellingPrice;
                  if (newSell < 0) {
                    setSt(() => formError = 'أدخل سعر بيع صحيح.');
                    return;
                  }

                  // 1. Deduct materials from workshop stock and increment line item pieces
                  for (final req in requirements) {
                    if (req.matchWs != null) {
                      req.matchWs!.availableQty =
                          (req.matchWs!.availableQty - req.reqArea).clamp(
                        0.0,
                        double.infinity,
                      );
                    }
                    req.lineItem.quantity += req.reqPieces;
                  }

                  // 2. Increment complex tailoring quantity by added pieces
                  t.quantity += addedPieces;

                  // 3. Update unified selling price
                  if (newSell > 0) {
                    t.sellingPrice = newSell;
                  }

                  erp.saveToDisk();
                  erp.notifyListeners();
                  Navigator.pop(ctx);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تمت إضافة $addedPieces قطعة للتفصيل المعقد "${t.name}" بنجاح، وخُصمت المواد المستهلكة من صفحة مواد المعمل.',
                      ),
                      backgroundColor: AppColors.successGreen,
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('تأكيد وإضافة المخزون للتفصيل ككل'),
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
          final List<_TailoringStockOption> allStockOptions = erp.workshopStock
              .where((w) => w.availableQty > 0 || w.id == selectedStockId)
              .map(
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
              )
              .toList();

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
                            selling = enteredSelling;
                          } else if (totalNetComplexCost > 0) {
                            selling = totalNetComplexCost * 1.3;
                          } else {
                            selling = draftLines.fold<double>(
                                  0.0,
                                  (sum, line) => sum + line.lineTotal,
                                );
                          }
                          for (final li in draftLines) {
                            li.sellingPricePerMeter = 0.0;
                          }
                        } else {
                          // Simple tailoring: No overall price for the entire tailoring item (no combined total price for all line items);
                          // each line item has its own individual price.
                          selling = 0.0;
                        }

                        // Commit stock: deduct materials from workshop stock (مواد المعمل).
                        for (final li in draftLines) {
                          if (erp.workshopStock.any((w) => w.id == li.stockId)) {
                            final ok = erp.deductWorkshopStock(
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
                          } else {
                            final wsMatch = erp.workshopStock
                                .where((w) => w.typeName == li.typeName)
                                .toList();
                            if (wsMatch.isNotEmpty) {
                              final ok = erp.deductWorkshopStock(
                                wsMatch.first.id,
                                li.area,
                              );
                              if (!ok) {
                                setSt(
                                  () => formError =
                                      'نقص في مخزون مواد المعمل لـ ${li.typeName}. راجع الكميات.',
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
                          unitCategory: complexity == 'معقد' ? 'قطعة' : productUnit,
                          measurementCount: 1,
                          quantity: complexity == 'معقد' ? 1.0 : outputMeasure,
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
                              complexity == 'معقد'
                                  ? 'تم حفظ التفصيل المعقد كقطعة واحدة بسعر بيع إجمالي ${selling.fmt}\$ وخصم استهلاك المواد من المخزون.'
                                  : 'تم حفظ التفصيل بكمية ${outputMeasure.fmt} ${productUnit == 'متر مكعب' ? 'م³' : 'م²'} وخصم استهلاك المواد من المخزون.',
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

  double getWorkshopCubicSellingPrice(ERPProvider erp, WorkshopStockModel w) {
    if (w.category == 'متر مكعب' && w.recommendedSalePrice > 0) return w.recommendedSalePrice;
    final exactWorkshop = erp.workshopStock.where((s) => s.typeName.trim() == w.typeName.trim() && s.grade.trim() == w.grade.trim() && s.category == 'متر مكعب' && s.recommendedSalePrice > 0).toList();
    if (exactWorkshop.isNotEmpty) return exactWorkshop.first.recommendedSalePrice;
    final matches = erp.workshopStock.where((s) => s.typeName.trim() == w.typeName.trim() && s.category == 'متر مكعب' && s.recommendedSalePrice > 0).toList();
    if (matches.isNotEmpty) return matches.first.recommendedSalePrice;
    final exactFac = erp.factoryWarehouse.where((f) => f.typeName.trim() == w.typeName.trim() && f.grade.trim() == w.grade.trim() && f.category == 'متر مكعب' && f.recommendedSalePrice > 0).toList();
    if (exactFac.isNotEmpty) return exactFac.first.recommendedSalePrice;
    final facMatches = erp.factoryWarehouse.where((f) => f.typeName.trim() == w.typeName.trim() && f.category == 'متر مكعب' && f.recommendedSalePrice > 0).toList();
    if (facMatches.isNotEmpty) return facMatches.first.recommendedSalePrice;
    return w.recommendedSalePrice > 0 ? w.recommendedSalePrice : (w.netCostPerUnit * 1.3);
  }

  void _showEditWorkshopDraftItemModal({
    required BuildContext context,
    required WorkshopInvoiceItem item,
    required String currency,
    required ERPProvider erp,
    required void Function(WorkshopInvoiceItem updatedItem) onSave,
  }) {
    String editUnitCategory = item.unitCategory;
    final descCtrl = TextEditingController(text: item.description);
    final lenCtrl = TextEditingController(text: item.lengthCm > 0 ? item.lengthCm.fmt : '');
    final widCtrl = TextEditingController(text: item.widthCm > 0 ? item.widthCm.fmt : '');
    final heiCtrl = TextEditingController(text: item.heightCm > 0 ? item.heightCm.fmt : '');

    double initialCount = 1.0;
    if (item.lengthCm > 0 && item.widthCm > 0) {
      final singlePiece = item.isCubicMeter && item.heightCm > 0
          ? (item.lengthCm / 100.0) * (item.widthCm / 100.0) * (item.heightCm / 100.0)
          : (item.lengthCm / 100.0) * (item.widthCm / 100.0);
      if (singlePiece > 0.000001 && item.quantity >= singlePiece) {
        final calcCount = (item.quantity / singlePiece).roundToDouble();
        if ((item.quantity - (calcCount * singlePiece)).abs() < 0.001) {
          initialCount = calcCount;
        }
      }
    } else {
      initialCount = item.quantity > 0 ? item.quantity : 1.0;
    }
    final countCtrl = TextEditingController(text: initialCount.fmt);
    final unitPriceCtrl = TextEditingController(text: item.unitPrice.fmt);
    final agreedCtrl = TextEditingController(text: item.agreedPrice.fmt);
    final List<ServiceAttachment> editServices = List.of(item.services);
    String? editSelectedServiceId;
    final editServicePriceCtrl = TextEditingController();
    final editServiceNotesCtrl = TextEditingController();

    double lookupPredefinedThickness() {
      final stockMatches = erp.workshopStock.where((w) => w.id == item.sourceId).toList();
      if (stockMatches.isNotEmpty && stockMatches.first.thicknessCm > 0) return stockMatches.first.thicknessCm;
      final facMatches = erp.factoryWarehouse.where((w) => w.id == item.sourceId).toList();
      if (facMatches.isNotEmpty && facMatches.first.thicknessCm > 0) return facMatches.first.thicknessCm;
      for (final s in erp.workshopStock) {
        if (s.thicknessCm > 0 && item.description.contains(s.typeName)) return s.thicknessCm;
      }
      for (final f in erp.factoryWarehouse) {
        if (f.thicknessCm > 0 && item.description.contains(f.typeName)) return f.thicknessCm;
      }
      return item.heightCm > 0 ? item.heightCm : 2.0;
    }

    double lookupCubicPrice() {
      final stockMatches = erp.workshopStock.where((w) => w.id == item.sourceId).toList();
      if (stockMatches.isNotEmpty) {
        return getWorkshopCubicSellingPrice(erp, stockMatches.first);
      }
      final facMatches = erp.factoryWarehouse.where((w) => w.id == item.sourceId).toList();
      if (facMatches.isNotEmpty) {
        final f = facMatches.first;
        if (f.category == 'متر مكعب' && f.recommendedSalePrice > 0) return f.recommendedSalePrice;
        final cMatches = erp.factoryWarehouse.where((w) => w.typeName.trim() == f.typeName.trim() && w.category == 'متر مكعب' && w.recommendedSalePrice > 0).toList();
        if (cMatches.isNotEmpty) return cMatches.first.recommendedSalePrice;
        return f.recommendedSalePrice;
      }
      for (final s in erp.workshopStock) {
        if (item.description.contains(s.typeName)) {
          return getWorkshopCubicSellingPrice(erp, s);
        }
      }
      for (final f in erp.factoryWarehouse) {
        if (item.description.contains(f.typeName)) {
          if (f.category == 'متر مكعب' && f.recommendedSalePrice > 0) return f.recommendedSalePrice;
          final cMatches = erp.factoryWarehouse.where((w) => w.typeName.trim() == f.typeName.trim() && w.category == 'متر مكعب' && w.recommendedSalePrice > 0).toList();
          if (cMatches.isNotEmpty) return cMatches.first.recommendedSalePrice;
          return f.recommendedSalePrice;
        }
      }
      return item.unitPrice;
    }

    if (item.unitCategory == 'متر مكعب' && heiCtrl.text.isEmpty) {
      heiCtrl.text = lookupPredefinedThickness().fmt;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final bool isCube = editUnitCategory == 'متر مكعب';
          final double l = double.tryParse(lenCtrl.text) ?? 0.0;
          final double w = double.tryParse(widCtrl.text) ?? 0.0;
          final double h = double.tryParse(heiCtrl.text) ?? 0.0;
          final double cnt = double.tryParse(countCtrl.text) ?? 0.0;
          final double up = double.tryParse(unitPriceCtrl.text) ?? 0.0;

          final bool hasDimensions = l > 0 && w > 0;
          final double totalVolumeOrArea = isCube
              ? ((hasDimensions && h > 0 && cnt > 0) ? (l / 100.0) * (w / 100.0) * (h / 100.0) * cnt : 0.0)
              : (hasDimensions && cnt > 0 ? (l / 100.0) * (w / 100.0) * cnt : cnt);

          final double itemBasePrice = (hasDimensions || isCube)
              ? (totalVolumeOrArea * up)
              : (double.tryParse(agreedCtrl.text) ?? (cnt * up));

          final double srvTotal = editServices.fold(0.0, (s, e) => s + e.price);
          final double grandTotalWithServices = itemBasePrice + srvTotal;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 580,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit_note_rounded, color: AppColors.accentPrimary, size: 26),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تعديل بند: ${item.description}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        const Text(
                          'وحدة القياس / البيع:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        ChoiceChip(
                          label: const Text('متر مربع (م²)'),
                          selected: !isCube,
                          onSelected: (sel) {
                            if (sel) {
                              setSt(() {
                                editUnitCategory = 'متر مربع';
                                heiCtrl.clear();
                                final stockMatches = erp.workshopStock.where((s) => s.id == item.sourceId).toList();
                                if (stockMatches.isNotEmpty && stockMatches.first.recommendedSalePrice > 0) {
                                  unitPriceCtrl.text = stockMatches.first.recommendedSalePrice.fmt;
                                }
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('متر مكعب (م³)'),
                          selected: isCube,
                          selectedColor: const Color(0xFFDCFCE7),
                          onSelected: (sel) {
                            if (sel) {
                              setSt(() {
                                editUnitCategory = 'متر مكعب';
                                heiCtrl.text = lookupPredefinedThickness().fmt;
                                final cp = lookupCubicPrice();
                                if (cp > 0) unitPriceCtrl.text = cp.fmt;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'وصف البند',
                        isDense: true,
                        prefixIcon: Icon(Icons.description_outlined, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: lenCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'العرض (سم)',
                              isDense: true,
                            ),
                            onChanged: (_) => setSt(() {}),
                          ),
                        ),
                        if (isCube) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: heiCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'الارتفاع = السماكة (سم)',
                                helperText: 'سماكة المادة: ${lookupPredefinedThickness().fmt} سم',
                                isDense: true,
                              ),
                              onChanged: (_) => setSt(() {}),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: countCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'الكمية (العدد / القطع)',
                              isDense: true,
                            ),
                            onChanged: (_) => setSt(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: unitPriceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'سعر بيع المتر (${isCube ? "م³" : "م²"} ${AppCurrency.symbol(currency)})',
                              helperText: isCube ? 'سعر المتر المكعب للمادة' : null,
                              isDense: true,
                            ),
                            onChanged: (_) => setSt(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الأمتار المحسوبة: ${totalVolumeOrArea.fmt} ${isCube ? "م³" : "م²"}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF166534),
                                ),
                              ),
                              if (isCube)
                                Text(
                                  'الحجم = ${(l / 100).fmt}م × ${(w / 100).fmt}م × ${(h / 100).fmt}م × ${cnt.fmt} قطع',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                                ),
                            ],
                          ),
                          Text(
                            'الإجمالي: ${itemBasePrice.fmt} ${AppCurrency.symbol(currency)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Dedicated Services Section
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
                              const Icon(Icons.handyman_outlined, size: 16, color: AppColors.accentPrimary),
                              const SizedBox(width: 6),
                              const Text(
                                'الخدمات الملحقة بهذا البند:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const Spacer(),
                              Text(
                                'إجمالي الخدمات: ${srvTotal.fmt} ${AppCurrency.symbol(currency)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (editServices.isNotEmpty)
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: editServices.asMap().entries.map((e) {
                                return Chip(
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: Colors.white,
                                  label: Text(
                                    '${e.value.serviceName}: ${e.value.price.fmt} ${AppCurrency.symbol(currency)}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  deleteIcon: const Icon(Icons.close, size: 14),
                                  onDeleted: () => setSt(() => editServices.removeAt(e.key)),
                                );
                              }).toList(),
                            )
                          else
                            const Text(
                              'لا توجد خدمات مخصصة ملحقة بهذا البند.',
                              style: TextStyle(fontSize: 11, color: AppColors.brandSecondaryText),
                            ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  value: editSelectedServiceId,
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'اختر خدمة إضافية', isDense: true),
                                  items: erp.services
                                      .map((s) => DropdownMenuItem(value: s.id, child: Text('${s.name} (${s.unitRate}\$)')))
                                      .toList(),
                                  onChanged: (v) => setSt(() {
                                    editSelectedServiceId = v;
                                    if (v != null) {
                                      final srv = erp.services.firstWhere((s) => s.id == v);
                                      editServicePriceCtrl.text = srv.unitRate.fmt;
                                    }
                                  }),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: TextField(
                                  controller: editServicePriceCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(labelText: 'سعر الخدمة', isDense: true),
                                ),
                              ),
                              const SizedBox(width: 6),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                                onPressed: () {
                                  if (editSelectedServiceId == null) return;
                                  final p = double.tryParse(editServicePriceCtrl.text) ?? 0.0;
                                  if (p <= 0) return;
                                  final srv = erp.services.firstWhere((s) => s.id == editSelectedServiceId);
                                  setSt(() {
                                    editServices.add(ServiceAttachment(
                                      serviceName: srv.name,
                                      price: p,
                                      notes: editServiceNotesCtrl.text.trim(),
                                    ));
                                    editSelectedServiceId = null;
                                    editServicePriceCtrl.clear();
                                    editServiceNotesCtrl.clear();
                                  });
                                },
                                child: const Text('إرفاق', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('الإجمالي الجديد للبند شاملاً الخدمات:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(
                            '${grandTotalWithServices.fmt} ${AppCurrency.symbol(currency)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4F46E5)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('إلغاء'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          onPressed: () {
                            final nq = (isCube || hasDimensions) ? totalVolumeOrArea : cnt;
                            final nup = double.tryParse(unitPriceCtrl.text) ?? item.unitPrice;
                            final nagreed = itemBasePrice;
                            final updated = item.copyWith(
                              description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : item.description,
                              unitCategory: editUnitCategory,
                              lengthCm: l,
                              widthCm: w,
                              heightCm: isCube ? h : 0.0,
                              count: cnt > 0 ? cnt : 1.0,
                              quantity: nq > 0 ? nq : item.quantity,
                              unitPrice: nup,
                              agreedPrice: nagreed,
                              services: List.of(editServices),
                            );
                            onSave(updated);
                            Navigator.pop(ctx);
                          },
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('حفظ التعديلات'),
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

  void _showAddOrderDialog(ERPProvider erp) {
    String orderCurrency = AppCurrency.usd;
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final depositCtrl = TextEditingController();
    final photoCtrl = TextEditingController();
    String? formError;
    String? itemError;

    // Items inside this order
    final List<WorkshopInvoiceItem> draftItems = [];

    // Current item being configured
    String itemSourceType = 'بيع خياطة بسيطة';
    String? selectedRecordId;
    String? selectedLineItemId;
    String recordSearch = '';
    final itemDescCtrl = TextEditingController();
    final itemQtyCtrl = TextEditingController(text: '1');
    final itemUnitPriceCtrl = TextEditingController(text: '0');
    final itemAgreedCtrl = TextEditingController(text: '0');
    String itemUnitCat = 'متر مربع';
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

    // Dedicated services for current item
    final List<ServiceAttachment> currentItemServices = [];
    String? selectedServiceId;
    final servicePriceCtrl = TextEditingController();
    final serviceNotesCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final dialogWidth = MediaQuery.of(ctx).size.width.clamp(900.0, 1280.0);
          final dialogHeight = MediaQuery.of(ctx).size.height * 0.90;

          // Raw stock items
          final rawFiltered = erp.workshopStock
              .where((w) => w.availableQty > 0)
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

          final bool rawCube = itemUnitCat == 'متر مكعب' || selectedRaw?.category == 'متر مكعب';
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
          final servicesFiltered = erp.services.toList();
          final serviceValue = servicesFiltered.any((s) => s.id == selectedServiceId)
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
          final double grandTotal = itemsTotal + servicesTotal;
          final double depositAmount = double.tryParse(depositCtrl.text) ?? 0.0;
          final double remaining = (grandTotal - depositAmount).clamp(0.0, double.infinity);

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
                        const Icon(
                          Icons.assignment_add,
                          color: AppColors.orderDepositBoxAccent,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Row(
                            children: [
                              const Text(
                                'إنشاء طلبية معمل جديدة (طلب معمل)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 12),
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
                                  '${draftItems.length} بنود مضافة',
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
                  // Left side = The order input fields
                  // Right side = The selected line items
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ==========================================
                          // LEFT COLUMN: INPUT FIELDS
                          // ==========================================
                          Expanded(
                            flex: 5,
                            child: Directionality(
                              textDirection: TextDirection.rtl,
                              child: Container(
                                color: Colors.white,
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Section 1: Customer & Currency Information
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
                                                  'بيانات الزبون والعملة',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                const Spacer(),
                                                SizedBox(
                                                  width: 180,
                                                  child: CurrencySelector(
                                                    value: orderCurrency,
                                                    dense: true,
                                                    onChanged: (v) => setSt(() => orderCurrency = v),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextField(
                                                    controller: nameCtrl,
                                                    decoration: const InputDecoration(
                                                      labelText: 'اسم الزبون (إلزامي)',
                                                      isDense: true,
                                                      prefixIcon: Icon(Icons.badge_outlined, size: 18),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: TextField(
                                                    controller: phoneCtrl,
                                                    decoration: const InputDecoration(
                                                      labelText: 'رقم هاتف الزبون',
                                                      isDense: true,
                                                      prefixIcon: Icon(Icons.phone_outlined, size: 18),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 16),

                                      // Section 2: Add Line Item to Order (4 types)
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
                                                  'إضافة بند جديد للطلبية',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),

                                            // 1. Source Type Selector (4 Types)
                                            const Text(
                                              'نوع البند المراد بيعه:',
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
                                                  value: 'بيع خياطة بسيطة',
                                                  child: Text('بيع خياطة بسيطة (Sell Simple Tailoring)'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'بيع خياطة معقدة',
                                                  child: Text('بيع خياطة معقدة (Sell Complex Tailoring)'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'بيع قطع إضافية',
                                                  child: Text('بيع قطع إضافية (Sell Extra Pieces)'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'بيع مواد خام من المعمل',
                                                  child: Text('بيع مواد خام من المعمل (Sell Raw Materials)'),
                                                ),
                                              ],
                                              onChanged: (v) => setSt(() {
                                                itemSourceType = v!;
                                                selectedRecordId = null;
                                                selectedLineItemId = null;
                                                selectedRawId = null;
                                                recordSearch = '';
                                                rawSearch = '';
                                                itemDescCtrl.clear();
                                                itemQtyCtrl.text = '1';
                                                itemUnitPriceCtrl.text = '0';
                                                itemAgreedCtrl.text = '0';
                                                rawLenCtrl.clear();
                                                rawWidCtrl.clear();
                                                rawHeiCtrl.clear();
                                                rawQtyCtrl.text = '1';
                                                rawPriceCtrl.clear();
                                                itemError = null;
                                              }),
                                            ),

                                            const SizedBox(height: 10),

                                            // 2. Specific Item Type Fields
                                            if (itemSourceType == 'بيع مواد خام من المعمل') ...[
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
                                                  labelText: 'اختر المادة الخام من مواد المعمل',
                                                  isDense: true,
                                                ),
                                                items: rawFiltered
                                                    .map(
                                                      (w) => DropdownMenuItem(
                                                        value: w.id,
                                                        child: Text(
                                                          '${w.typeName} ${w.grade} — المتاح: ${w.availableQty.fmt} ${w.category == "متر مكعب" ? "م³" : "م²"} (سعر المتر: ${w.recommendedSalePrice.fmt}\$)',
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                                onChanged: (v) => setSt(() {
                                                  selectedRawId = v;
                                                  final newlySelected = erp.workshopStock.where((w) => w.id == v).firstOrNull;
                                                  if (newlySelected != null) {
                                                    itemUnitCat = newlySelected.category;
                                                    itemIsGranite = newlySelected.isGranite;
                                                    final isCube = itemUnitCat == 'متر مكعب';
                                                    if (isCube) {
                                                      rawHeiCtrl.text = newlySelected.thicknessCm.fmt;
                                                      final cp = getWorkshopCubicSellingPrice(erp, newlySelected);
                                                      rawPriceCtrl.text = cp.fmt;
                                                    } else {
                                                      rawHeiCtrl.clear();
                                                      rawPriceCtrl.text = newlySelected.recommendedSalePrice > 0
                                                          ? newlySelected.recommendedSalePrice.fmt
                                                          : (newlySelected.netCostPerUnit * 1.3).fmt;
                                                    }
                                                  }
                                                }),
                                              ),
                                              if (selectedRaw != null) ...[
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    const Text(
                                                      'وحدة القياس / البيع:',
                                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    ChoiceChip(
                                                      label: const Text('متر مربع (م²)'),
                                                      selected: !rawCube,
                                                      onSelected: (sel) {
                                                        if (sel) {
                                                          setSt(() {
                                                            itemUnitCat = 'متر مربع';
                                                            rawHeiCtrl.clear();
                                                            rawPriceCtrl.text = selectedRaw!.recommendedSalePrice > 0
                                                                ? selectedRaw!.recommendedSalePrice.fmt
                                                                : (selectedRaw!.netCostPerUnit * 1.3).fmt;
                                                            final p = double.tryParse(rawPriceCtrl.text) ?? 0;
                                                            itemAgreedCtrl.text = (rawArea * p).fmt;
                                                          });
                                                        }
                                                      },
                                                    ),
                                                    const SizedBox(width: 8),
                                                    ChoiceChip(
                                                      label: const Text('متر مكعب (م³)'),
                                                      selected: rawCube,
                                                      selectedColor: const Color(0xFFDCFCE7),
                                                      onSelected: (sel) {
                                                        if (sel) {
                                                          setSt(() {
                                                            itemUnitCat = 'متر مكعب';
                                                            rawHeiCtrl.text = selectedRaw!.thicknessCm.fmt;
                                                            final cp = getWorkshopCubicSellingPrice(erp, selectedRaw!);
                                                            rawPriceCtrl.text = cp.fmt;
                                                            final p = double.tryParse(rawPriceCtrl.text) ?? 0;
                                                            itemAgreedCtrl.text = (rawArea * p).fmt;
                                                          });
                                                        }
                                                      },
                                                    ),
                                                  ],
                                                ),
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
                                                        }),
                                                      ),
                                                    ),
                                                    if (rawCube) ...[
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: TextField(
                                                          controller: rawHeiCtrl,
                                                          keyboardType: TextInputType.number,
                                                          decoration: InputDecoration(
                                                            labelText: 'الارتفاع = السماكة (سم)',
                                                            helperText: 'سماكة المادة: ${selectedRaw.thicknessCm.fmt} سم',
                                                            isDense: true,
                                                          ),
                                                          onChanged: (_) => setSt(() {
                                                            final p = double.tryParse(rawPriceCtrl.text) ?? 0;
                                                            itemAgreedCtrl.text = (rawArea * p).fmt;
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
                                                        }),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: TextField(
                                                        controller: rawPriceCtrl,
                                                        keyboardType: TextInputType.number,
                                                        decoration: InputDecoration(
                                                          labelText: 'سعر بيع المتر (${rawCube ? "م³" : "م²"} \$)',
                                                          helperText: rawCube
                                                              ? 'سعر المتر المكعب: ${getWorkshopCubicSellingPrice(erp, selectedRaw!).fmt} \$'
                                                              : (selectedRaw.recommendedSalePrice > 0 ? 'سعر المستودع: ${selectedRaw.recommendedSalePrice.fmt} \$' : null),
                                                          isDense: true,
                                                        ),
                                                        onChanged: (_) => setSt(() {
                                                          final p = double.tryParse(rawPriceCtrl.text) ?? 0;
                                                          itemAgreedCtrl.text = (rawArea * p).fmt;
                                                        }),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                // Total Meters Price Field
                                                TextField(
                                                  controller: itemAgreedCtrl,
                                                  readOnly: true,
                                                  decoration: const InputDecoration(
                                                    labelText: 'إجمالي سعر الأمتار (\$)',
                                                    isDense: true,
                                                    prefixIcon: Icon(Icons.calculate_outlined, size: 18),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'الأمتار المحسوبة: ${rawArea.fmt} ${rawCube ? "م³" : "م²"} • المتاح: ${selectedRaw.availableQty.fmt}',
                                                  style: const TextStyle(fontSize: 11, color: AppColors.accentPrimary),
                                                ),
                                                if (rawCube)
                                                  Text(
                                                    'الحجم = ${(rl / 100).fmt}م × ${(rw / 100).fmt}م × ${(rh / 100).fmt}م × ${rq.fmt} قطع = ${rawArea.fmt} م³',
                                                    style: const TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                                                  ),
                                              ],
                                            ] else if (itemSourceType == 'بيع خياطة بسيطة') ...[
                                              // Select Simple Tailoring
                                              DropdownButtonFormField<String>(
                                                value: selectedRecordId,
                                                isExpanded: true,
                                                decoration: const InputDecoration(
                                                  labelText: 'اختر الخياطة البسيطة',
                                                  isDense: true,
                                                ),
                                                items: erp.simpleTailorings
                                                    .map(
                                                      (t) => DropdownMenuItem(
                                                        value: t.id,
                                                        child: Text(
                                                          '${t.name} (المتاح: ${t.quantity.fmt} ${t.unitSymbol})',
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                                onChanged: (v) => setSt(() {
                                                  selectedRecordId = v;
                                                  selectedLineItemId = null;
                                                  final t = erp.simpleTailorings.firstWhere((x) => x.id == v);
                                                  itemPhoto = t.photoPath;
                                                  itemIsGranite = t.isGranite;
                                                  itemUnitCat = 'متر مربع';
                                                  if (t.lineItems.isNotEmpty) {
                                                    selectedLineItemId = t.lineItems.first.id;
                                                    final li = t.lineItems.first;
                                                    itemUnitPriceCtrl.text = (li.sellingPricePerMeter > 0 ? li.sellingPricePerMeter : t.sellingPrice).fmt;
                                                    itemDescCtrl.text = '${t.name} - ${li.description}';
                                                  } else {
                                                    itemUnitPriceCtrl.text = t.sellingPrice.fmt;
                                                    itemDescCtrl.text = t.name;
                                                  }
                                                  final q = double.tryParse(itemQtyCtrl.text) ?? 1.0;
                                                  final up = double.tryParse(itemUnitPriceCtrl.text) ?? 0.0;
                                                  itemAgreedCtrl.text = (q * up).fmt;
                                                }),
                                              ),
                                              if (selectedRecordId != null) ...[
                                                const SizedBox(height: 8),
                                                Builder(
                                                  builder: (_) {
                                                    final t = erp.simpleTailorings.firstWhere((x) => x.id == selectedRecordId);
                                                    return DropdownButtonFormField<String>(
                                                      value: selectedLineItemId,
                                                      isExpanded: true,
                                                      decoration: const InputDecoration(
                                                        labelText: 'اختر البند المحدد من داخل هذه الخياطة',
                                                        isDense: true,
                                                      ),
                                                      items: t.lineItems
                                                          .map(
                                                            (li) {
                                                              final pieceMeters = (li.lengthCm > 0 && li.widthCm > 0)
                                                                  ? (li.lengthCm / 100.0) * (li.widthCm / 100.0)
                                                                  : 1.0;
                                                              final totalLiMeters = pieceMeters * li.quantity;
                                                              return DropdownMenuItem(
                                                                value: li.id,
                                                                child: Text(
                                                                  '${li.description} • الأبعاد: ${li.lengthCm}×${li.widthCm}سم • المتاح: ${totalLiMeters.fmt} م² (${li.quantity.fmt} قطع)',
                                                                ),
                                                              );
                                                            },
                                                          )
                                                          .toList(),
                                                      onChanged: (lv) => setSt(() {
                                                        selectedLineItemId = lv;
                                                        if (lv != null) {
                                                          final li = t.lineItems.firstWhere((x) => x.id == lv);
                                                          itemDescCtrl.text = '${t.name} - ${li.description}';
                                                          itemUnitPriceCtrl.text = (li.sellingPricePerMeter > 0 ? li.sellingPricePerMeter : t.sellingPrice).fmt;
                                                          final q = double.tryParse(itemQtyCtrl.text) ?? 1.0;
                                                          final up = double.tryParse(itemUnitPriceCtrl.text) ?? 0.0;
                                                          itemAgreedCtrl.text = (q * up).fmt;
                                                        }
                                                      }),
                                                    );
                                                  },
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: TextField(
                                                        controller: itemQtyCtrl,
                                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                        decoration: const InputDecoration(
                                                          labelText: 'الكمية المطلوبة بالمتر (م²)',
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
                                                          labelText: 'سعر المتر الإفرادي (\$)',
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
                                                TextField(
                                                  controller: itemAgreedCtrl,
                                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                  decoration: const InputDecoration(
                                                    labelText: 'إجمالي سعر الأمتار (\$)',
                                                    isDense: true,
                                                  ),
                                                ),
                                              ],
                                            ] else if (itemSourceType == 'بيع خياطة معقدة') ...[
                                              // Complex tailoring is treated as pieces
                                              DropdownButtonFormField<String>(
                                                value: selectedRecordId,
                                                isExpanded: true,
                                                decoration: const InputDecoration(
                                                  labelText: 'اختر الخياطة المعقدة',
                                                  isDense: true,
                                                ),
                                                items: erp.complexTailorings
                                                    .map(
                                                      (t) => DropdownMenuItem(
                                                        value: t.id,
                                                        child: Text(
                                                          '${t.name} • المتاح: ${t.quantity.fmt} قطع (سعر القطعة: ${t.sellingPrice.fmt}\$)',
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                                onChanged: (v) => setSt(() {
                                                  selectedRecordId = v;
                                                  if (v != null) {
                                                    final t = erp.complexTailorings.firstWhere((x) => x.id == v);
                                                    itemDescCtrl.text = t.name;
                                                    itemUnitPriceCtrl.text = t.sellingPrice.fmt;
                                                    itemQtyCtrl.text = '1';
                                                    itemAgreedCtrl.text = t.sellingPrice.fmt;
                                                    itemUnitCat = 'قطعة';
                                                    itemIsGranite = t.isGranite;
                                                    itemPhoto = t.photoPath;
                                                  }
                                                }),
                                              ),
                                              if (selectedRecordId != null) ...[
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: TextField(
                                                        controller: itemQtyCtrl,
                                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                        decoration: const InputDecoration(
                                                          labelText: 'عدد القطع',
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
                                                          labelText: 'سعر القطعة الإفرادي (\$)',
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
                                                TextField(
                                                  controller: itemAgreedCtrl,
                                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                  decoration: const InputDecoration(
                                                    labelText: 'إجمالي السعر للقطع (\$)',
                                                    isDense: true,
                                                  ),
                                                ),
                                              ],
                                            ] else if (itemSourceType == 'بيع قطع إضافية') ...[
                                              DropdownButtonFormField<String>(
                                                value: selectedRecordId,
                                                isExpanded: true,
                                                decoration: const InputDecoration(
                                                  labelText: 'اختر القطعة الإضافية',
                                                  isDense: true,
                                                ),
                                                items: erp.scrapItems
                                                    .where((s) => !s.isSold)
                                                    .map(
                                                      (s) => DropdownMenuItem(
                                                        value: s.id,
                                                        child: Text('${s.description} (${s.sellingPrice.fmt}\$)'),
                                                      ),
                                                    )
                                                    .toList(),
                                                onChanged: (v) => setSt(() {
                                                  selectedRecordId = v;
                                                  if (v != null) {
                                                    final s = erp.scrapItems.firstWhere((x) => x.id == v);
                                                    itemDescCtrl.text = s.description;
                                                    itemUnitPriceCtrl.text = s.sellingPrice.fmt;
                                                    itemAgreedCtrl.text = s.sellingPrice.fmt;
                                                    itemQtyCtrl.text = '1';
                                                    itemUnitCat = 'قطعة';
                                                    itemPhoto = s.photoPath;
                                                  }
                                                }),
                                              ),
                                              if (selectedRecordId != null) ...[
                                                const SizedBox(height: 8),
                                                TextField(
                                                  controller: itemDescCtrl,
                                                  decoration: const InputDecoration(
                                                    labelText: 'وصف القطعة الإضافية',
                                                    isDense: true,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                TextField(
                                                  controller: itemAgreedCtrl,
                                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                  decoration: const InputDecoration(
                                                    labelText: 'السعر (\$)',
                                                    isDense: true,
                                                  ),
                                                ),
                                              ],
                                            ],

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
                                                            labelText: 'ملاحظات (اختياري)',
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

                                            // BUTTON: ADD ITEM TO ORDER
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
                                                  double itemQty = 1.0;
                                                  double itemAgreed = 0.0;
                                                  double itemNet = 0.0;
                                                  double itemUnitPrice = 0.0;
                                                  String itemDesc = itemDescCtrl.text.trim();

                                                  double itemLen = 0.0;
                                                  double itemWid = 0.0;
                                                  double itemHei = 0.0;
                                                  double itemCount = 1.0;

                                                  if (itemSourceType == 'بيع مواد خام من المعمل') {
                                                    if (selectedRaw == null || rawArea <= 0) {
                                                      setSt(() => itemError = 'يرجى اختيار المادة وتحديد الأبعاد.');
                                                      return;
                                                    }
                                                    itemQty = rawArea;
                                                    itemUnitPrice = rp;
                                                    itemAgreed = rawArea * rp;
                                                    itemNet = rawArea * selectedRaw.netCostPerUnit;
                                                    itemDesc = '${selectedRaw.typeName} ${selectedRaw.grade} ${selectedRaw.thicknessCm}سم';
                                                    itemLen = rl;
                                                    itemWid = rw;
                                                    itemHei = rawCube ? rh : 0.0;
                                                    itemCount = rq > 0 ? rq : 1.0;
                                                  } else {
                                                    if (selectedRecordId == null) {
                                                      setSt(() => itemError = 'يرجى اختيار السجل أو التفصيل.');
                                                      return;
                                                    }
                                                    itemQty = double.tryParse(itemQtyCtrl.text) ?? 1.0;
                                                    itemUnitPrice = double.tryParse(itemUnitPriceCtrl.text) ?? 0.0;
                                                    itemAgreed = double.tryParse(itemAgreedCtrl.text) ?? 0.0;
                                                    itemCount = itemQty;

                                                    if (itemSourceType == 'بيع خياطة بسيطة') {
                                                      final t = erp.simpleTailorings.firstWhere((x) => x.id == selectedRecordId);
                                                      itemNet = (t.quantity > 0 ? (t.totalNetCost / t.quantity) : 0) * itemQty;
                                                      if (selectedLineItemId != null) {
                                                        final liMatches = t.lineItems.where((x) => x.id == selectedLineItemId).toList();
                                                        if (liMatches.isNotEmpty) {
                                                          final li = liMatches.first;
                                                          itemLen = li.lengthCm;
                                                          itemWid = li.widthCm;
                                                          itemHei = li.heightCm;
                                                        }
                                                      }
                                                      if (itemDesc.isEmpty) itemDesc = t.name;
                                                    } else if (itemSourceType == 'بيع خياطة معقدة') {
                                                      final t = erp.complexTailorings.firstWhere((x) => x.id == selectedRecordId);
                                                      itemNet = (t.quantity > 0 ? (t.totalNetCost / t.quantity) : 0) * itemQty;
                                                      if (itemDesc.isEmpty) itemDesc = t.name;
                                                    } else if (itemSourceType == 'بيع قطع إضافية') {
                                                      final s = erp.scrapItems.firstWhere((x) => x.id == selectedRecordId);
                                                      itemNet = s.baseCost;
                                                      if (itemDesc.isEmpty) itemDesc = s.description;
                                                    }
                                                  }

                                                  final newItem = WorkshopInvoiceItem(
                                                    id: 'woi_${DateTime.now().microsecondsSinceEpoch}',
                                                    sourceType: itemSourceType,
                                                    sourceId: itemSourceType == 'بيع مواد خام من المعمل'
                                                        ? selectedRawId!
                                                        : selectedRecordId!,
                                                    sourceLineItemId: selectedLineItemId ?? '',
                                                    description: itemDesc,
                                                    quantity: itemQty,
                                                    unitCategory: rawCube ? 'متر مكعب' : itemUnitCat,
                                                    unitPrice: itemUnitPrice,
                                                    agreedPrice: itemAgreed,
                                                    netCost: itemNet,
                                                    depositAmount: 0.0,
                                                    isGranite: itemIsGranite,
                                                    services: List.of(currentItemServices),
                                                    photoPath: itemPhoto,
                                                    lengthCm: itemLen,
                                                    widthCm: itemWid,
                                                    heightCm: itemHei,
                                                    count: itemCount,
                                                  );

                                                  setSt(() {
                                                    draftItems.add(newItem);
                                                    selectedRecordId = null;
                                                    selectedLineItemId = null;
                                                    selectedRawId = null;
                                                    recordSearch = '';
                                                    rawSearch = '';
                                                    itemUnitCat = 'متر مربع';
                                                    currentItemServices.clear();
                                                    itemDescCtrl.clear();
                                                    itemQtyCtrl.text = '1';
                                                    itemUnitPriceCtrl.text = '0';
                                                    itemAgreedCtrl.text = '0';
                                                    rawLenCtrl.clear();
                                                    rawWidCtrl.clear();
                                                    rawHeiCtrl.clear();
                                                    rawPriceCtrl.clear();
                                                    itemError = null;
                                                    formError = null;
                                                  });
                                                },
                                                icon: const Icon(Icons.add_task_rounded, size: 18),
                                                label: const Text(
                                                  '+ إضافة هذا الصنف إلى الطلبية',
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 16),

                                      // Section 3: Deposit (Mandatory) & Attachment
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
                                                const Icon(Icons.savings_outlined, size: 18, color: AppColors.orderDepositBoxAccent),
                                                const SizedBox(width: 6),
                                                const Text(
                                                  'العربون والدفعة المقدمة (إلزامي للطلبية)',
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            TextField(
                                              controller: depositCtrl,
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              decoration: InputDecoration(
                                                labelText: 'مبلغ العربون / الدفعة الأولى (إلزامي) (${AppCurrency.symbol(orderCurrency)})',
                                                isDense: true,
                                                helperText: 'يُودع في صندوق الطلبيات المعزول ولا يُرحل للصندوق الرئيسي إلا عند إصدار الفاتورة.',
                                              ),
                                              onChanged: (_) => setSt(() {}),
                                            ),
                                            const SizedBox(height: 12),
                                            AppImageAttachmentPicker(
                                              initialPath: photoCtrl.text,
                                              label: 'صورة الطلبية / المخطط',
                                              onImageChanged: (p) => setSt(() => photoCtrl.text = p),
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

                          // VERTICAL DIVIDER
                          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFCBD5E1)),

                          // ==========================================
                          // RIGHT COLUMN: ITEMS LIST & SUMMARY
                          // ==========================================
                          Expanded(
                            flex: 6,
                            child: Directionality(
                              textDirection: TextDirection.rtl,
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
                                          const Icon(Icons.list_alt_rounded, size: 20, color: AppColors.orderDepositBoxAccent),
                                          const SizedBox(width: 8),
                                          const Expanded(
                                            child: Text(
                                              'أصناف وبنود الطلبية المحددة (اضغط على أي بند لتعديله)',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: Color(0xFF0F172A),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
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

                                    // List of items
                                    Expanded(
                                      child: draftItems.isEmpty
                                          ? Center(
                                              child: Padding(
                                                padding: const EdgeInsets.all(24),
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.assignment_outlined,
                                                      size: 64,
                                                      color: Colors.grey.shade400,
                                                    ),
                                                    const SizedBox(height: 12),
                                                    const Text(
                                                      'لم يتم إضافة أي بند للطلبية بعد',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 16,
                                                        color: Color(0xFF475569),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    const Text(
                                                      'اختر نوع البند من القائمة يساراً وأضف الأصناف والخدمات لتظهر هنا.',
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
                                                return Card(
                                                  elevation: 1,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                                                  ),
                                                  child: InkWell(
                                                    borderRadius: BorderRadius.circular(10),
                                                    onTap: () {
                                                      _showEditWorkshopDraftItemModal(
                                                        context: context,
                                                        item: item,
                                                        currency: orderCurrency,
                                                        erp: erp,
                                                        onSave: (updated) => setSt(() {
                                                          draftItems[idx] = updated;
                                                        }),
                                                      );
                                                    },
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(12),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
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
                                                                  style: const TextStyle(
                                                                    fontWeight: FontWeight.bold,
                                                                    fontSize: 14,
                                                                  ),
                                                                ),
                                                              ),
                                                              IconButton(
                                                                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2563EB)),
                                                                tooltip: 'تعديل هذا البند',
                                                                onPressed: () {
                                                                  _showEditWorkshopDraftItemModal(
                                                                    context: context,
                                                                    item: item,
                                                                    currency: orderCurrency,
                                                                    erp: erp,
                                                                    onSave: (updated) => setSt(() {
                                                                      draftItems[idx] = updated;
                                                                    }),
                                                                  );
                                                                },
                                                              ),
                                                              IconButton(
                                                                icon: const Icon(
                                                                  Icons.delete_outline_rounded,
                                                                  size: 18,
                                                                  color: AppColors.dangerWaste,
                                                                ),
                                                                tooltip: 'حذف',
                                                                onPressed: () => setSt(() => draftItems.removeAt(idx)),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 6),
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
                                                                'القيمة: ${item.agreedPrice.fmt} ${AppCurrency.symbol(orderCurrency)}',
                                                                style: const TextStyle(
                                                                  fontWeight: FontWeight.bold,
                                                                  fontSize: 13,
                                                                  color: Color(0xFF0F172A),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          if (item.services.isNotEmpty) ...[
                                                            const SizedBox(height: 6),
                                                            Wrap(
                                                              spacing: 6,
                                                              runSpacing: 4,
                                                              children: item.services.map((s) => Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                decoration: BoxDecoration(
                                                                  color: const Color(0xFFEFF6FF),
                                                                  borderRadius: BorderRadius.circular(4),
                                                                ),
                                                                child: Text(
                                                                  'خدمة: ${s.serviceName} (${s.price}\$)',
                                                                  style: const TextStyle(fontSize: 10, color: Color(0xFF1D4ED8)),
                                                                ),
                                                              )).toList(),
                                                            ),
                                                          ],
                                                          const Divider(height: 12),
                                                          Row(
                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                            children: [
                                                              const Text(
                                                                'إجمالي البند مع الخدمات:',
                                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                                              ),
                                                              Text(
                                                                '${(item.agreedPrice + item.servicesTotal).fmt} ${AppCurrency.symbol(orderCurrency)}',
                                                                style: const TextStyle(
                                                                  fontWeight: FontWeight.bold,
                                                                  fontSize: 13,
                                                                  color: Color(0xFF2563EB),
                                                                ),
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
                                    ),

                                    // Bottom Totals & Confirm Button
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
                                                'مجموع البنود: ${itemsTotal.fmt} ${AppCurrency.symbol(orderCurrency)}',
                                                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                              ),
                                              Text(
                                                'مجموع الخدمات: ${servicesTotal.fmt} ${AppCurrency.symbol(orderCurrency)}',
                                                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
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
                                                    'إجمالي الطلبية النهائي:',
                                                    style: TextStyle(fontSize: 11, color: AppColors.brandSecondaryText),
                                                  ),
                                                  Text(
                                                    '${grandTotal.fmt} ${AppCurrency.symbol(orderCurrency)}',
                                                    style: const TextStyle(
                                                      fontSize: 18,
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
                                                    'العربون المقدم: ${depositAmount.fmt} ${AppCurrency.symbol(orderCurrency)}',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.orderDepositBoxAccent,
                                                    ),
                                                  ),
                                                  Text(
                                                    'المتبقي عند التسليم: ${remaining.fmt} ${AppCurrency.symbol(orderCurrency)}',
                                                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
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

                                          // SUBMIT BUTTON for Order
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.orderDepositBoxAccent,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(vertical: 14),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                              ),
                                              onPressed: () {
                                                if (draftItems.isEmpty) {
                                                  setSt(() => formError = 'يجب إضافة بند واحد على الأقل للطلبية.');
                                                  return;
                                                }
                                                if (nameCtrl.text.trim().isEmpty) {
                                                  setSt(() => formError = 'يرجى إدخال اسم العميل / الزبون.');
                                                  return;
                                                }
                                                final dep = double.tryParse(depositCtrl.text) ?? 0.0;
                                                if (dep <= 0) {
                                                  setSt(() => formError = 'يجب إدخال قيمة العربون (أكبر من صفر).');
                                                  return;
                                                }
                                                if (dep > grandTotal) {
                                                  setSt(() => formError = 'العربون لا يمكن أن يتجاوز إجمالي الطلبية.');
                                                  return;
                                                }

                                                final order = WorkshopOrderModel(
                                                  id: 'order_${DateTime.now().millisecondsSinceEpoch}',
                                                  orderNo: 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                                                  date: DateTime.now(),
                                                  clientName: nameCtrl.text.trim(),
                                                  clientPhone: phoneCtrl.text.trim(),
                                                  customDimensionsText: draftItems.map((i) => i.description).join(' + '),
                                                  agreedPrice: grandTotal,
                                                  depositAmount: dep,
                                                  photoPath: photoCtrl.text.trim(),
                                                  status: 'قيد التنفيذ',
                                                  currency: orderCurrency,
                                                  items: List.of(draftItems),
                                                );

                                                erp.createWorkshopOrder(order);

                                                Navigator.pop(ctx);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('تم تسجيل الطلبية وحفظ العربون في صندوق الطلبيات بنجاح.'),
                                                    backgroundColor: AppColors.successGreen,
                                                  ),
                                                );
                                              },
                                              child: const Text(
                                                'حفظ وتثبيت الطلبية',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
    String? linkedOrderId; // ID of the order linked to this invoice if imported

    // The list of line items added to this invoice
    final List<WorkshopInvoiceItem> draftItems = [];

    // Current item being configured
    String itemSourceType = 'طلب معمل';
    String? selectedRecordId;
    String? selectedLineItemId;
    String? selectedOrderClient;
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
    final servicePriceCtrl = TextEditingController();
    final serviceNotesCtrl = TextEditingController();

    double getAvailableStockForRaw(WorkshopStockModel w) {
      final used = draftItems
          .where((i) => (i.sourceType == 'بيع مواد خام من المعمل' || i.sourceType == 'مواد خام') && i.sourceId == w.id)
          .fold<double>(0.0, (s, i) => s + i.quantity);
      return (w.availableQty - used).clamp(0.0, double.infinity);
    }

    double getAvailableForTailoring(WorkshopTailoringModel t) {
      final used = draftItems
          .where(
            (i) =>
                (i.sourceType == 'بيع خياطة بسيطة' ||
                    i.sourceType == 'تفصيل بسيط' ||
                    i.sourceType == 'بيع خياطة معقدة' ||
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
      if (linkedOrderId != null && totalOrderDeposits <= 0) {
        // If order linked, depositCtrl is kept as set by order
      } else if (totalOrderDeposits > 0) {
        depositCtrl.text = totalOrderDeposits.fmt;
      }

      final disc = double.tryParse(salesDiscountCtrl.text) ?? 0.0;
      final curDeposit = double.tryParse(depositCtrl.text) ?? 0.0;
      final grandTotal = (itemsTotal + servicesTotal - disc).clamp(
        0.0,
        double.infinity,
      );

      if (cashInvoice) {
        cashCtrl.text = (grandTotal - curDeposit)
            .clamp(0.0, double.infinity)
            .fmt;
      } else {
        if (cashCtrl.text.isEmpty || cashCtrl.text == '0') {
          cashCtrl.text = (grandTotal - curDeposit)
              .clamp(0.0, double.infinity)
              .fmt;
        }
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final dialogWidth = MediaQuery.of(ctx).size.width.clamp(900.0, 1280.0);
          final dialogHeight = MediaQuery.of(ctx).size.height * 0.90;

          // Active orders grouped by customer name
          final activeOrders = erp.workshopOrders
              .where((o) => o.status == 'قيد التنفيذ')
              .where((o) => !draftItems.any((i) => i.sourceId == o.id) && linkedOrderId != o.id)
              .toList();

          final Map<String, List<WorkshopOrderModel>> ordersByClient = {};
          for (final o in activeOrders) {
            final cName = o.clientName.trim().isEmpty ? 'عميل بدون اسم' : o.clientName.trim();
            ordersByClient.putIfAbsent(cName, () => []).add(o);
          }

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

          final bool rawCube = itemUnitCat == 'متر مكعب' || selectedRaw?.category == 'متر مكعب';
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
          final servicesFiltered = erp.services.toList();
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
          final double totalDeposits = double.tryParse(depositCtrl.text) ?? 0.0;
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
                                  '${draftItems.length} بنود مضافة',
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
                  // Right side = The selected line items
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ==========================================
                          // LEFT COLUMN: THE INVOICE INPUT FIELDS
                          // ==========================================
                          Expanded(
                            flex: 5,
                            child: Directionality(
                              textDirection: TextDirection.rtl,
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

                                      // Section 2: Add Line Item to Invoice (5 types)
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
                                                  'إضافة بند جديد للفاتورة',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),

                                            // 1. Source Type Selector (The 5 exact types)
                                            const Text(
                                              'نوع البند (Source Type):',
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
                                                  value: 'طلب معمل',
                                                  child: Text('طلب معمل (Factory Order)'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'بيع خياطة بسيطة',
                                                  child: Text('بيع خياطة بسيطة (Sell Simple Tailoring)'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'بيع خياطة معقدة',
                                                  child: Text('بيع خياطة معقدة (Sell Complex Tailoring)'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'بيع قطع إضافية',
                                                  child: Text('بيع قطع إضافية (Sell Extra Pieces)'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'بيع مواد خام من المعمل',
                                                  child: Text('بيع مواد خام من المعمل (Sell Raw Materials)'),
                                                ),
                                              ],
                                              onChanged: (v) => setSt(() {
                                                itemSourceType = v!;
                                                selectedRecordId = null;
                                                selectedLineItemId = null;
                                                selectedRawId = null;
                                                selectedOrderClient = null;
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

                                            // 2. Specific Item Type Fields
                                            // ----------------------------------------------------
                                            // TYPE 1: طلب معمل (Factory Orders Grouped by Client)
                                            // ----------------------------------------------------
                                            if (itemSourceType == 'طلب معمل') ...[
                                              if (ordersByClient.isEmpty)
                                                Container(
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Row(
                                                    children: [
                                                      Icon(Icons.info_outline, size: 18, color: AppColors.brandSecondaryText),
                                                      SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          'لا توجد طلبيات معمل قيد التنفيذ متاحة للتحويل حالياً.',
                                                          style: TextStyle(fontSize: 12, color: AppColors.brandSecondaryText),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              else ...[
                                                const Text(
                                                  'الطلبيات مجمعة بحسب اسم الزبون:',
                                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                                ),
                                                const SizedBox(height: 6),
                                                DropdownButtonFormField<String>(
                                                  value: selectedOrderClient,
                                                  isExpanded: true,
                                                  decoration: const InputDecoration(
                                                    labelText: 'اختر الزبون صاحب الطلبية',
                                                    isDense: true,
                                                    prefixIcon: Icon(Icons.people_outline, size: 18),
                                                  ),
                                                  items: ordersByClient.keys.map((cName) {
                                                    final count = ordersByClient[cName]!.length;
                                                    return DropdownMenuItem(
                                                      value: cName,
                                                      child: Text('$cName ($count طلبيات قيد التنفيذ)'),
                                                    );
                                                  }).toList(),
                                                  onChanged: (cName) => setSt(() {
                                                    selectedOrderClient = cName;
                                                    selectedRecordId = null;
                                                  }),
                                                ),
                                                if (selectedOrderClient != null) ...[
                                                  const SizedBox(height: 8),
                                                  DropdownButtonFormField<String>(
                                                    value: selectedRecordId,
                                                    isExpanded: true,
                                                    decoration: const InputDecoration(
                                                      labelText: 'اختر طلبية هذا الزبون لإدراجها',
                                                      isDense: true,
                                                      prefixIcon: Icon(Icons.assignment_outlined, size: 18),
                                                    ),
                                                    items: ordersByClient[selectedOrderClient]!.map((o) {
                                                      return DropdownMenuItem(
                                                        value: o.id,
                                                        child: Text(
                                                          '${o.orderNo} • عربون: ${o.depositAmount.fmt}\$ • إجمالي: ${o.agreedPrice.fmt}\$ (${o.items.isNotEmpty ? o.items.length : 1} بنود)',
                                                        ),
                                                      );
                                                    }).toList(),
                                                    onChanged: (oid) => setSt(() {
                                                      selectedRecordId = oid;
                                                    }),
                                                  ),
                                                  if (selectedRecordId != null) ...[
                                                    const SizedBox(height: 10),
                                                    Builder(
                                                      builder: (_) {
                                                        final ord = erp.workshopOrders.firstWhere((x) => x.id == selectedRecordId);
                                                        return Column(
                                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                                          children: [
                                                            Container(
                                                              padding: const EdgeInsets.all(10),
                                                              decoration: BoxDecoration(
                                                                color: const Color(0xFFEFF6FF),
                                                                borderRadius: BorderRadius.circular(8),
                                                                border: Border.all(color: const Color(0xFFBFDBFE)),
                                                              ),
                                                              child: Column(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                  Text(
                                                                    'الطلبية: ${ord.orderNo} • الزبون: ${ord.clientName}',
                                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E3A8A)),
                                                                  ),
                                                                  const SizedBox(height: 4),
                                                                  Text(
                                                                    'قيمة العربون: ${ord.depositAmount.fmt} ${AppCurrency.symbol(ord.currency)} (يُقيد كدفعة ويتحول للصندوق الرئيسي)',
                                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.orderDepositBoxAccent),
                                                                  ),
                                                                  if (ord.items.isNotEmpty) ...[
                                                                    const SizedBox(height: 4),
                                                                    Text(
                                                                      'البنود الجاهزة للنقل: ${ord.items.map((i) => i.description).join(" ، ")}',
                                                                      style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                                                                    ),
                                                                  ],
                                                                ],
                                                              ),
                                                            ),
                                                            const SizedBox(height: 8),
                                                            ElevatedButton.icon(
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor: const Color(0xFF2563EB),
                                                                foregroundColor: Colors.white,
                                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                              ),
                                                              onPressed: () {
                                                                linkedOrderId = ord.id;
                                                                clientCtrl.text = ord.clientName;
                                                                invCurrency = ord.currency;
                                                                depositCtrl.text = ord.depositAmount.fmt;

                                                                setSt(() {
                                                                  if (ord.items.isNotEmpty) {
                                                                    for (final it in ord.items) {
                                                                      draftItems.add(it.copyWith(
                                                                        id: 'wii_${DateTime.now().microsecondsSinceEpoch}_${it.id}',
                                                                        depositAmount: 0.0,
                                                                      ));
                                                                    }
                                                                  } else {
                                                                    draftItems.add(
                                                                      WorkshopInvoiceItem(
                                                                        id: 'wii_${DateTime.now().microsecondsSinceEpoch}',
                                                                        sourceType: 'طلب معمل',
                                                                        sourceId: ord.id,
                                                                        description: ord.customDimensionsText.isNotEmpty
                                                                            ? ord.customDimensionsText
                                                                            : 'طلب معمل ${ord.orderNo}',
                                                                        quantity: 1.0,
                                                                        unitCategory: 'مقطوعية',
                                                                        unitPrice: ord.agreedPrice,
                                                                        agreedPrice: ord.agreedPrice,
                                                                        netCost: ord.agreedPrice * 0.60,
                                                                        depositAmount: ord.depositAmount,
                                                                        isGranite: false,
                                                                        photoPath: ord.photoPath,
                                                                      ),
                                                                    );
                                                                  }
                                                                  selectedRecordId = null;
                                                                  selectedOrderClient = null;
                                                                  recomputeInvoiceFinancials();
                                                                });

                                                                ScaffoldMessenger.of(context).showSnackBar(
                                                                  SnackBar(
                                                                    content: Text(
                                                                      'تم استيراد بنود الطلبية ${ord.orderNo} بنجاح وقيد العربون (${ord.depositAmount.fmt}). اضغط على أي بند لتعديله.',
                                                                    ),
                                                                    backgroundColor: AppColors.successGreen,
                                                                  ),
                                                                );
                                                              },
                                                              icon: const Icon(Icons.download_done_rounded, size: 18),
                                                              label: const Text('نقل بنود الطلبية حرفياً إلى الفاتورة وقيد العربون'),
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ],
                                              ],
                                            ] else if (itemSourceType == 'بيع مواد خام من المعمل') ...[
                                              // ----------------------------------------------------
                                              // TYPE 2: بيع مواد خام من المعمل
                                              // Removed: وصف البند & المبلغ المتفق للبند
                                              // Renamed: التكلفة الصافية -> إجمالي سعر الأمتار
                                              // سعر المتر from factory stock
                                              // ----------------------------------------------------
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
                                                  labelText: 'اختر المادة الخام من مواد المعمل',
                                                  isDense: true,
                                                ),
                                                items: rawFiltered
                                                    .map(
                                                      (w) => DropdownMenuItem(
                                                        value: w.id,
                                                        child: Text(
                                                          '${w.typeName} ${w.grade} — المتاح: ${getAvailableStockForRaw(w).fmt} ${w.category == "متر مكعب" ? "م³" : "م²"} (سعر المتر: ${w.recommendedSalePrice.fmt}\$)',
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                                onChanged: (v) => setSt(() {
                                                  selectedRawId = v;
                                                  final newlySelected = erp.workshopStock.where((w) => w.id == v).firstOrNull;
                                                  if (newlySelected != null) {
                                                    itemUnitCat = newlySelected.category;
                                                    itemIsGranite = newlySelected.isGranite;
                                                    final isCube = itemUnitCat == 'متر مكعب';
                                                    if (isCube) {
                                                      rawHeiCtrl.text = newlySelected.thicknessCm.fmt;
                                                      final cp = getWorkshopCubicSellingPrice(erp, newlySelected);
                                                      rawPriceCtrl.text = cp.fmt;
                                                    } else {
                                                      rawHeiCtrl.clear();
                                                      rawPriceCtrl.text = newlySelected.recommendedSalePrice > 0
                                                          ? newlySelected.recommendedSalePrice.fmt
                                                          : (newlySelected.netCostPerUnit * 1.3).fmt;
                                                    }
                                                  }
                                                }),
                                              ),
                                              if (selectedRaw != null) ...[
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    const Text(
                                                      'وحدة القياس / البيع:',
                                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    ChoiceChip(
                                                      label: const Text('متر مربع (م²)'),
                                                      selected: !rawCube,
                                                      onSelected: (sel) {
                                                        if (sel) {
                                                          setSt(() {
                                                            itemUnitCat = 'متر مربع';
                                                            rawHeiCtrl.clear();
                                                            rawPriceCtrl.text = selectedRaw!.recommendedSalePrice > 0
                                                                ? selectedRaw!.recommendedSalePrice.fmt
                                                                : (selectedRaw!.netCostPerUnit * 1.3).fmt;
                                                            final p = double.tryParse(rawPriceCtrl.text) ?? 0;
                                                            itemAgreedCtrl.text = (rawArea * p).fmt;
                                                          });
                                                        }
                                                      },
                                                    ),
                                                    const SizedBox(width: 8),
                                                    ChoiceChip(
                                                      label: const Text('متر مكعب (م³)'),
                                                      selected: rawCube,
                                                      selectedColor: const Color(0xFFDCFCE7),
                                                      onSelected: (sel) {
                                                        if (sel) {
                                                          setSt(() {
                                                            itemUnitCat = 'متر مكعب';
                                                            rawHeiCtrl.text = selectedRaw!.thicknessCm.fmt;
                                                            final cp = getWorkshopCubicSellingPrice(erp, selectedRaw!);
                                                            rawPriceCtrl.text = cp.fmt;
                                                            final p = double.tryParse(rawPriceCtrl.text) ?? 0;
                                                            itemAgreedCtrl.text = (rawArea * p).fmt;
                                                          });
                                                        }
                                                      },
                                                    ),
                                                  ],
                                                ),
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
                                                        }),
                                                      ),
                                                    ),
                                                    if (rawCube) ...[
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: TextField(
                                                          controller: rawHeiCtrl,
                                                          keyboardType: TextInputType.number,
                                                          decoration: InputDecoration(
                                                            labelText: 'الارتفاع = السماكة (سم)',
                                                            helperText: 'سماكة المادة: ${selectedRaw.thicknessCm.fmt} سم',
                                                            isDense: true,
                                                          ),
                                                          onChanged: (_) => setSt(() {
                                                            final p = double.tryParse(rawPriceCtrl.text) ?? 0;
                                                            itemAgreedCtrl.text = (rawArea * p).fmt;
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
                                                        }),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: TextField(
                                                        controller: rawPriceCtrl,
                                                        keyboardType: TextInputType.number,
                                                        decoration: InputDecoration(
                                                          labelText: 'سعر بيع المتر (${rawCube ? "م³" : "م²"} \$)',
                                                          helperText: rawCube
                                                              ? 'سعر المتر المكعب: ${getWorkshopCubicSellingPrice(erp, selectedRaw!).fmt} \$'
                                                              : (selectedRaw.recommendedSalePrice > 0 ? 'سعر المستودع: ${selectedRaw.recommendedSalePrice.fmt} \$' : null),
                                                          isDense: true,
                                                        ),
                                                        onChanged: (_) => setSt(() {
                                                          final p = double.tryParse(rawPriceCtrl.text) ?? 0;
                                                          itemAgreedCtrl.text = (rawArea * p).fmt;
                                                        }),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                // Total Meters Price field
                                                TextField(
                                                  controller: itemAgreedCtrl,
                                                  readOnly: true,
                                                  decoration: const InputDecoration(
                                                    labelText: 'إجمالي سعر الأمتار (\$)',
                                                    isDense: true,
                                                    prefixIcon: Icon(Icons.calculate_outlined, size: 18),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'الأمتار المحسوبة: ${rawArea.fmt} ${rawCube ? "م³" : "م²"} • المتاح: ${getAvailableStockForRaw(selectedRaw).fmt}',
                                                  style: const TextStyle(fontSize: 11, color: AppColors.accentPrimary),
                                                ),
                                                if (rawCube)
                                                  Text(
                                                    'الحجم = ${(rl / 100).fmt}م × ${(rw / 100).fmt}م × ${(rh / 100).fmt}م × ${rq.fmt} قطع = ${rawArea.fmt} م³',
                                                    style: const TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                                                  ),
                                              ],
                                            ] else if (itemSourceType == 'بيع خياطة بسيطة') ...[
                                              // ----------------------------------------------------
                                              // TYPE 3: بيع خياطة بسيطة
                                              // Select tailoring -> Select specific line item -> Quantity in meters -> Unit meter price -> Total meters price
                                              // ----------------------------------------------------
                                              DropdownButtonFormField<String>(
                                                value: selectedRecordId,
                                                isExpanded: true,
                                                decoration: const InputDecoration(
                                                  labelText: 'اختر الخياطة البسيطة',
                                                  isDense: true,
                                                ),
                                                items: erp.simpleTailorings
                                                    .map(
                                                      (t) => DropdownMenuItem(
                                                        value: t.id,
                                                        child: Text(
                                                          '${t.name} (المتاح: ${getAvailableForTailoring(t).fmt} ${t.unitSymbol})',
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                                onChanged: (v) => setSt(() {
                                                  selectedRecordId = v;
                                                  selectedLineItemId = null;
                                                  final t = erp.simpleTailorings.firstWhere((x) => x.id == v);
                                                  itemPhoto = t.photoPath;
                                                  itemIsGranite = t.isGranite;
                                                  itemUnitCat = 'متر مربع';
                                                  if (t.lineItems.isNotEmpty) {
                                                    selectedLineItemId = t.lineItems.first.id;
                                                    final li = t.lineItems.first;
                                                    itemUnitPriceCtrl.text = (li.sellingPricePerMeter > 0 ? li.sellingPricePerMeter : t.sellingPrice).fmt;
                                                    itemDescCtrl.text = '${t.name} - ${li.description}';
                                                  } else {
                                                    itemUnitPriceCtrl.text = t.sellingPrice.fmt;
                                                    itemDescCtrl.text = t.name;
                                                  }
                                                  final q = double.tryParse(itemQtyCtrl.text) ?? 1.0;
                                                  final up = double.tryParse(itemUnitPriceCtrl.text) ?? 0.0;
                                                  itemAgreedCtrl.text = (q * up).fmt;
                                                }),
                                              ),
                                              if (selectedRecordId != null) ...[
                                                const SizedBox(height: 8),
                                                Builder(
                                                  builder: (_) {
                                                    final t = erp.simpleTailorings.firstWhere((x) => x.id == selectedRecordId);
                                                    return DropdownButtonFormField<String>(
                                                      value: selectedLineItemId,
                                                      isExpanded: true,
                                                      decoration: const InputDecoration(
                                                        labelText: 'اختر البند المحدد من داخل هذه الخياطة للبيع',
                                                        isDense: true,
                                                      ),
                                                      items: t.lineItems
                                                          .map(
                                                            (li) {
                                                              final pieceMeters = (li.lengthCm > 0 && li.widthCm > 0)
                                                                  ? (li.lengthCm / 100.0) * (li.widthCm / 100.0)
                                                                  : 1.0;
                                                              final totalLiMeters = pieceMeters * li.quantity;
                                                              return DropdownMenuItem(
                                                                value: li.id,
                                                                child: Text(
                                                                  '${li.description} • الأبعاد: ${li.lengthCm}×${li.widthCm}سم • المتاح: ${totalLiMeters.fmt} م² (${li.quantity.fmt} قطع)',
                                                                ),
                                                              );
                                                            },
                                                          )
                                                          .toList(),
                                                      onChanged: (lv) => setSt(() {
                                                        selectedLineItemId = lv;
                                                        if (lv != null) {
                                                          final li = t.lineItems.firstWhere((x) => x.id == lv);
                                                          itemDescCtrl.text = '${t.name} - ${li.description}';
                                                          itemUnitPriceCtrl.text = (li.sellingPricePerMeter > 0 ? li.sellingPricePerMeter : t.sellingPrice).fmt;
                                                          final q = double.tryParse(itemQtyCtrl.text) ?? 1.0;
                                                          final up = double.tryParse(itemUnitPriceCtrl.text) ?? 0.0;
                                                          itemAgreedCtrl.text = (q * up).fmt;
                                                        }
                                                      }),
                                                    );
                                                  },
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: TextField(
                                                        controller: itemQtyCtrl,
                                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                        decoration: const InputDecoration(
                                                          labelText: 'الكمية المطلوبة بالمتر (م²)',
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
                                                          labelText: 'سعر المتر الإفرادي (\$)',
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
                                                TextField(
                                                  controller: itemAgreedCtrl,
                                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                  decoration: const InputDecoration(
                                                    labelText: 'إجمالي سعر الأمتار (\$)',
                                                    isDense: true,
                                                  ),
                                                ),
                                              ],
                                            ] else if (itemSourceType == 'بيع خياطة معقدة') ...[
                                              // ----------------------------------------------------
                                              // TYPE 4: بيع خياطة معقدة
                                              // Treated as single unit/piece: "عدد القطع", individual unit price, total price
                                              // ----------------------------------------------------
                                              DropdownButtonFormField<String>(
                                                value: selectedRecordId,
                                                isExpanded: true,
                                                decoration: const InputDecoration(
                                                  labelText: 'اختر الخياطة المعقدة',
                                                  isDense: true,
                                                ),
                                                items: erp.complexTailorings
                                                    .map(
                                                      (t) => DropdownMenuItem(
                                                        value: t.id,
                                                        child: Text(
                                                          '${t.name} • المتاح: ${getAvailableForTailoring(t).fmt} قطع (سعر القطعة: ${t.sellingPrice.fmt}\$)',
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                                onChanged: (v) => setSt(() {
                                                  selectedRecordId = v;
                                                  if (v != null) {
                                                    final t = erp.complexTailorings.firstWhere((x) => x.id == v);
                                                    itemDescCtrl.text = t.name;
                                                    itemUnitPriceCtrl.text = t.sellingPrice.fmt;
                                                    itemQtyCtrl.text = '1';
                                                    itemAgreedCtrl.text = t.sellingPrice.fmt;
                                                    itemUnitCat = 'قطعة';
                                                    itemIsGranite = t.isGranite;
                                                    itemPhoto = t.photoPath;
                                                  }
                                                }),
                                              ),
                                              if (selectedRecordId != null) ...[
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: TextField(
                                                        controller: itemQtyCtrl,
                                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                        decoration: const InputDecoration(
                                                          labelText: 'عدد القطع',
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
                                                          labelText: 'سعر القطعة الإفرادي (\$)',
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
                                                TextField(
                                                  controller: itemAgreedCtrl,
                                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                  decoration: const InputDecoration(
                                                    labelText: 'إجمالي السعر للقطع (\$)',
                                                    isDense: true,
                                                  ),
                                                ),
                                              ],
                                            ] else if (itemSourceType == 'بيع قطع إضافية') ...[
                                              // ----------------------------------------------------
                                              // TYPE 5: بيع قطع إضافية
                                              // ----------------------------------------------------
                                              DropdownButtonFormField<String>(
                                                value: selectedRecordId,
                                                isExpanded: true,
                                                decoration: const InputDecoration(
                                                  labelText: 'اختر القطعة الإضافية',
                                                  isDense: true,
                                                ),
                                                items: erp.scrapItems
                                                    .where((s) => !s.isSold)
                                                    .map(
                                                      (s) => DropdownMenuItem(
                                                        value: s.id,
                                                        child: Text('${s.description} (${s.sellingPrice.fmt}\$)'),
                                                      ),
                                                    )
                                                    .toList(),
                                                onChanged: (v) => setSt(() {
                                                  selectedRecordId = v;
                                                  if (v != null) {
                                                    final s = erp.scrapItems.firstWhere((x) => x.id == v);
                                                    itemDescCtrl.text = s.description;
                                                    itemUnitPriceCtrl.text = s.sellingPrice.fmt;
                                                    itemAgreedCtrl.text = s.sellingPrice.fmt;
                                                    itemQtyCtrl.text = '1';
                                                    itemUnitCat = 'قطعة';
                                                    itemPhoto = s.photoPath;
                                                  }
                                                }),
                                              ),
                                              if (selectedRecordId != null) ...[
                                                const SizedBox(height: 8),
                                                TextField(
                                                  controller: itemDescCtrl,
                                                  decoration: const InputDecoration(
                                                    labelText: 'وصف القطعة الإضافية',
                                                    isDense: true,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                TextField(
                                                  controller: itemAgreedCtrl,
                                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                  decoration: const InputDecoration(
                                                    labelText: 'السعر (\$)',
                                                    isDense: true,
                                                  ),
                                                ),
                                              ],
                                            ],

                                            // Only show services and add button for items (not for 'طلب معمل' selector itself)
                                            if (itemSourceType != 'طلب معمل') ...[
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
                                                    double itemQty = 1.0;
                                                    double itemAgreed = 0.0;
                                                    double itemNet = 0.0;
                                                    double itemUnitPrice = 0.0;
                                                    String itemDesc = itemDescCtrl.text.trim();
                                                    double itemLen = 0.0;
                                                    double itemWid = 0.0;
                                                    double itemHei = 0.0;
                                                    double itemCount = 1.0;

                                                    if (itemSourceType == 'بيع مواد خام من المعمل') {
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
                                                      itemDesc = '${selectedRaw.typeName} ${selectedRaw.grade} ${selectedRaw.thicknessCm}سم';
                                                      itemLen = rl;
                                                      itemWid = rw;
                                                      itemHei = rawCube ? rh : 0.0;
                                                      itemCount = rq;
                                                    } else {
                                                      if (selectedRecordId == null) {
                                                        setSt(() => itemError = 'يرجى اختيار السجل أو التفصيل المراد إضافته.');
                                                        return;
                                                      }
                                                      itemQty = double.tryParse(itemQtyCtrl.text) ?? 1.0;
                                                      itemUnitPrice = double.tryParse(itemUnitPriceCtrl.text) ?? 0.0;
                                                      itemAgreed = double.tryParse(itemAgreedCtrl.text) ?? 0.0;

                                                      if (itemSourceType == 'بيع خياطة بسيطة') {
                                                        final t = erp.simpleTailorings.firstWhere((x) => x.id == selectedRecordId);
                                                        final avail = getAvailableForTailoring(t);
                                                        if (itemQty <= 0 || itemQty > avail + 0.0001) {
                                                          setSt(() => itemError = 'الكمية المطلوبة غير صحيحة أو تتجاوز المتاح.');
                                                          return;
                                                        }
                                                        itemNet = (t.quantity > 0 ? (t.totalNetCost / t.quantity) : 0) * itemQty;
                                                        if (itemDesc.isEmpty) itemDesc = t.name;
                                                        if (selectedLineItemId != null) {
                                                          final liMatches = t.lineItems.where((x) => x.id == selectedLineItemId);
                                                          if (liMatches.isNotEmpty) {
                                                            final li = liMatches.first;
                                                            itemLen = li.lengthCm;
                                                            itemWid = li.widthCm;
                                                            final pieceArea = (li.lengthCm > 0 && li.widthCm > 0) ? (li.lengthCm / 100.0) * (li.widthCm / 100.0) : 0.0;
                                                            itemCount = pieceArea > 0 ? (itemQty / pieceArea).roundToDouble() : itemQty;
                                                            if (itemCount <= 0) itemCount = 1.0;
                                                          }
                                                        }
                                                      } else if (itemSourceType == 'بيع خياطة معقدة') {
                                                        final t = erp.complexTailorings.firstWhere((x) => x.id == selectedRecordId);
                                                        final avail = getAvailableForTailoring(t);
                                                        if (itemQty <= 0 || itemQty > avail + 0.0001) {
                                                          setSt(() => itemError = 'عدد القطع المطلوب غير صحيح أو يتجاوز المتاح.');
                                                          return;
                                                        }
                                                        itemNet = (t.quantity > 0 ? (t.totalNetCost / t.quantity) : 0) * itemQty;
                                                        if (itemDesc.isEmpty) itemDesc = t.name;
                                                        itemCount = itemQty;
                                                      } else if (itemSourceType == 'بيع قطع إضافية') {
                                                        final s = erp.scrapItems.firstWhere((x) => x.id == selectedRecordId);
                                                        itemNet = s.baseCost;
                                                        if (itemDesc.isEmpty) itemDesc = s.description;
                                                        if (s.description.isNotEmpty) {
                                                          final m = RegExp(r'(\d+(?:\.\d+)?)\s*[*×xX]\s*(\d+(?:\.\d+)?)').firstMatch(s.description);
                                                          if (m != null) {
                                                            itemLen = double.tryParse(m.group(1)!) ?? 0.0;
                                                            itemWid = double.tryParse(m.group(2)!) ?? 0.0;
                                                          }
                                                        }
                                                        itemCount = itemQty;
                                                      }
                                                    }

                                                    final newItem = WorkshopInvoiceItem(
                                                      id: 'wii_${DateTime.now().microsecondsSinceEpoch}',
                                                      sourceType: itemSourceType,
                                                      sourceId: itemSourceType == 'بيع مواد خام من المعمل'
                                                          ? selectedRawId!
                                                          : selectedRecordId!,
                                                      sourceLineItemId: selectedLineItemId ?? '',
                                                      description: itemDesc,
                                                      quantity: itemQty,
                                                      unitCategory: rawCube ? 'متر مكعب' : itemUnitCat,
                                                      unitPrice: itemUnitPrice,
                                                      agreedPrice: itemAgreed,
                                                      netCost: itemNet,
                                                      depositAmount: 0.0,
                                                      isGranite: itemIsGranite,
                                                      services: List.of(currentItemServices),
                                                      photoPath: itemPhoto,
                                                      lengthCm: itemLen,
                                                      widthCm: itemWid,
                                                      heightCm: itemHei,
                                                      count: itemCount,
                                                    );

                                                    setSt(() {
                                                      draftItems.add(newItem);
                                                      selectedRecordId = null;
                                                      selectedLineItemId = null;
                                                      selectedRawId = null;
                                                      recordSearch = '';
                                                      rawSearch = '';
                                                      itemUnitCat = 'متر مربع';
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
                                              Builder(
                                                builder: (context) {
                                                  final curDep = double.tryParse(depositCtrl.text) ?? 0.0;
                                                  final curCash = double.tryParse(cashCtrl.text) ?? 0.0;
                                                  String? depError;
                                                  String? cashError;
                                                  if (depositCtrl.text.isNotEmpty) {
                                                    if (curDep < 0) {
                                                      depError = 'لا يمكن أن يكون سالباً';
                                                    } else if (curDep > grandTotal + 0.01) {
                                                      depError = 'العربون يتجاوز إجمالي الفاتورة';
                                                    }
                                                  }
                                                  if (cashCtrl.text.isNotEmpty) {
                                                    if (curCash < 0) {
                                                      cashError = 'لا يمكن أن يكون سالباً';
                                                    } else if (curDep + curCash > grandTotal + 0.01) {
                                                      cashError = 'المجموع يتجاوز الفاتورة (${grandTotal.fmt})';
                                                    }
                                                  }
                                                  return Row(
                                                    children: [
                                                      Expanded(
                                                        child: TextField(
                                                          controller: depositCtrl,
                                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                          decoration: InputDecoration(
                                                            labelText: 'العربون المخصوم (\$)',
                                                            isDense: true,
                                                            errorText: depError,
                                                            helperText: 'الحد الأقصى: ${grandTotal.fmt}',
                                                          ),
                                                          onChanged: (_) => setSt(() => recomputeInvoiceFinancials()),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: TextField(
                                                          controller: cashCtrl,
                                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                          decoration: InputDecoration(
                                                            labelText: 'النقد المدفوع الآن (\$)',
                                                            isDense: true,
                                                            errorText: cashError,
                                                            helperText: 'أقصى نقد إضافي: ${(grandTotal - curDep).clamp(0.0, double.infinity).fmt}',
                                                          ),
                                                          onChanged: (_) => setSt(() {}),
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                },
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
                              textDirection: TextDirection.rtl,
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
                                          const Expanded(
                                            child: Text(
                                              'أصناف وبنود الفاتورة المحددة (اضغط على أي بند لتعديله)',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: Color(0xFF0F172A),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
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
                                                      'اختر نوع الصنف من القائمة يساراً (طلب معمل، خياطة بسيطة، معقدة، قطع إضافية، مواد خام) لتظهر البنود هنا.',
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
                                                if (item.sourceType == 'بيع مواد خام من المعمل' || item.sourceType == 'مواد خام') {
                                                  chipColor = const Color(0xFFD1FAE5);
                                                  textColor = const Color(0xFF065F46);
                                                } else if (item.sourceType == 'بيع قطع إضافية' || item.sourceType == 'قطع زائدة') {
                                                  chipColor = const Color(0xFFFEF3C7);
                                                  textColor = const Color(0xFF92400E);
                                                } else if (item.sourceType == 'طلب معمل' || item.sourceType == 'طلبية معمل') {
                                                  chipColor = const Color(0xFFEDE9FE);
                                                  textColor = const Color(0xFF5B21B6);
                                                }

                                                return Card(
                                                  elevation: 1,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                                                  ),
                                                  child: InkWell(
                                                    borderRadius: BorderRadius.circular(10),
                                                    onTap: () {
                                                      _showEditWorkshopDraftItemModal(
                                                        context: context,
                                                        item: item,
                                                        currency: invCurrency,
                                                        erp: erp,
                                                        onSave: (updated) => setSt(() {
                                                          draftItems[idx] = updated;
                                                          recomputeInvoiceFinancials();
                                                        }),
                                                      );
                                                    },
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
                                                                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2563EB)),
                                                                tooltip: 'تعديل هذا البند',
                                                                onPressed: () {
                                                                  _showEditWorkshopDraftItemModal(
                                                                    context: context,
                                                                    item: item,
                                                                    currency: invCurrency,
                                                                    erp: erp,
                                                                    onSave: (updated) => setSt(() {
                                                                      draftItems[idx] = updated;
                                                                      recomputeInvoiceFinancials();
                                                                    }),
                                                                  );
                                                                },
                                                              ),
                                                              IconButton(
                                                                icon: const Icon(
                                                                  Icons.delete_outline_rounded,
                                                                  size: 18,
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
                                                          color: remaining < -0.01
                                                              ? const Color(0xFFFEE2E2)
                                                              : (remaining <= 0.01
                                                                  ? const Color(0xFFDCFCE7)
                                                                  : const Color(0xFFFEE2E8)),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          remaining < -0.01
                                                              ? 'تجاوز (${(-remaining).fmt})!'
                                                              : (remaining <= 0.01 ? 'مسددة بالكامل' : 'متبقي ذمة'),
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                            color: remaining < -0.01
                                                                ? const Color(0xFFB91C1C)
                                                                : (remaining <= 0.01
                                                                    ? const Color(0xFF15803D)
                                                                    : const Color(0xFFB91C1C)),
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

                                                if (deposit < 0) {
                                                  setSt(() => formError = 'خطأ: قيمة العربون لا يمكن أن تكون سالبة.');
                                                  return;
                                                }
                                                if (cash < 0) {
                                                  setSt(() => formError = 'خطأ: قيمة النقد المدفوع لا يمكن أن تكون سالبة.');
                                                  return;
                                                }
                                                if (deposit + cash > grandTotal + 0.01) {
                                                  final maxCash = (grandTotal - deposit).clamp(0.0, double.infinity);
                                                  setSt(() => formError =
                                                      'خطأ: إجمالي الدفعات (العربون ${deposit.fmt} + النقد ${cash.fmt}) يتجاوز إجمالي قيمة الفاتورة (${grandTotal.fmt}). الحد الأقصى للنقد الإضافي المسموح به: ${maxCash.fmt} ${AppCurrency.symbol(invCurrency)}.');
                                                  return;
                                                }

                                                // Determine overall sourceType
                                                final sourcesSet = draftItems.map((i) => i.sourceType).toSet();
                                                final String overallSourceType = sourcesSet.length == 1
                                                    ? sourcesSet.first
                                                    : (linkedOrderId != null ? 'طلب معمل' : 'مصادر متعددة (${sourcesSet.join(" + ")})');

                                                final invoice = WorkshopInvoiceModel(
                                                  id: 'wi_${DateTime.now().millisecondsSinceEpoch}',
                                                  invoiceNo: 'WRK-INV-${erp.workshopInvoices.length + 101}',
                                                  date: DateTime.now(),
                                                  clientName: clientCtrl.text.trim(),
                                                  items: List.of(draftItems),
                                                  sourceType: overallSourceType,
                                                  sourceId: linkedOrderId ?? draftItems.first.sourceId,
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

                                                // Ensure linked order is marked as completed and migrated
                                                if (linkedOrderId != null) {
                                                  final ordMatches = erp.workshopOrders.where((o) => o.id == linkedOrderId).toList();
                                                  if (ordMatches.isNotEmpty) {
                                                    ordMatches.first.status = 'مكتملة ومرحلة';
                                                    erp.saveToDisk();
                                                  }
                                                }

                                                final isProject = (presetProjectId != null && presetProjectId.isNotEmpty);

                                                Navigator.pop(ctx);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      isProject
                                                          ? 'تم حفظ فاتورة المشروع بنجاح.'
                                                          : (cashInvoice
                                                              ? 'تم إصدار فاتورة البيع النقدية وتحصيلها بالكامل بنجاح.'
                                                              : 'تم إصدار وحفظ فاتورة المعمل بنجاح وترحيل العربون والذمة للزبون.'),
                                                    ),
                                                    backgroundColor: AppColors.successGreen,
                                                  ),
                                                );
                                              },
                                              child: Text(
                                                (presetProjectId != null && presetProjectId.isNotEmpty)
                                                    ? 'حفظ'
                                                    : (cashInvoice
                                                        ? 'إصدار فاتورة البيع النقدية وتحصيلها'
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
