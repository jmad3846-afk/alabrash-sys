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
import '../widgets/factory_order_dialogs.dart';
import 'accounting_screens.dart';

class FactoryWorkspaceScreen extends StatefulWidget {
  final Function(int navIndex) onNavigateToCutting;
  const FactoryWorkspaceScreen({super.key, required this.onNavigateToCutting});

  @override
  State<FactoryWorkspaceScreen> createState() => _FactoryWorkspaceScreenState();
}

class _FactoryWorkspaceScreenState extends State<FactoryWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _navTabController;

  // Selected Blocks for Multi-Supplier Cutting Batch (legacy single flow)
  final List<String> selectedBlockIds = [];

  // Staged cutting selection: blockId -> tons picked for cutting.
  final Map<String, double> selectedCuttingTons = {};
  final Map<String, TextEditingController> cuttingQtyCtrls = {};
  bool cuttingAggregated = false;
  List<CuttingBatchInput> cuttingAggregates = [];

  // Factory Orders filters
  String _foStatusFilter = 'الكل';
  String _foSearchQuery = '';

  TextEditingController _cuttingQtyCtrl(String blockId) {
    return cuttingQtyCtrls.putIfAbsent(blockId, () => TextEditingController());
  }

  @override
  void dispose() {
    for (final c in cuttingQtyCtrls.values) {
      c.dispose();
    }
    _navTabController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _navTabController = TabController(length: 11, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final erp = Provider.of<ERPProvider>(context);

    return Scaffold(
      body: Column(
        children: [
          // Sub-Navbar Header Tabs
          Container(
            color: AppColors.panelSurface,
            child: TabBar(
              controller: _navTabController,
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
                Tab(text: '1. رئيسية المصنع'),
                Tab(text: '2. مخزون مصنع (البلوكات)'),
                Tab(text: '3. مستودع مصنع (الألواح)'),
                Tab(text: '4. الأشخاص (موردين ومعتمدين)'),
                Tab(text: '5. الأنواع والمقاسات'),
                Tab(text: '6. فواتير شراء من موردين'),
                Tab(text: '7. بيع لمعتمدين (POS المصنع)'),
                Tab(text: '8. سجل عمليات القص'),
                Tab(text: '9. طلبيات المصنع (Orders)'),
                Tab(text: '10. المرتجعات والمسموحات'),
                Tab(text: '11. الفواتير النقدية'),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: TabBarView(
              controller: _navTabController,
              children: [
                _buildSubTab1Home(erp),
                _buildSubTab2BlockStock(erp),
                _buildSubTab3SlabsWarehouse(erp),
                _buildSubTab4Persons(erp),
                _buildSubTab5Types(erp),
                _buildSubTab6SupplierPurchases(erp),
                _buildSubTab7POSSales(erp),
                _buildSubTab8CuttingLog(erp),
                _buildSubTab9FactoryOrders(erp),
                const ReturnsAllowancesScreen(factoryOnly: true),
                _buildCashFactoryInvoices(erp),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // SUB-TAB 1: FACTORY HOME STATS
  // -------------------------------------------------------------
  Widget _buildSubTab1Home(ERPProvider erp) {
    double totalBlockTons = erp.factoryBlocks.fold(
      0.0,
      (s, b) => s + b.weightTons,
    );
    double totalBlockVal = erp.factoryBlocks.fold(
      0.0,
      (s, b) => s + b.totalCost,
    );

    double totalSlabsM2 = erp.factoryWarehouse
        .where((w) => w.category == 'متر مربع')
        .fold(0.0, (s, w) => s + w.availableQty);
    double totalSlabsM3 = erp.factoryWarehouse
        .where((w) => w.category == 'متر مكعب')
        .fold(0.0, (s, w) => s + w.availableQty);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'لوحة ملخص إنتاج ومخزون المصنع',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.chipBgBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'إجمالي وزن البلوكات الخام: ${totalBlockTons.fmt} طن',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'إحصائيات البلوكات الخام حسب النوع والدرجة',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const Divider(height: 20),
                        ...erp.factoryBlocks.map(
                          (b) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${b.blockCode} • ${b.typeName} (${b.grade})',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${b.weightTons} طن (${b.tonCost}\$/طن)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'إجمالي قيمة البلوكات:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${totalBlockVal.fmt} \$',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.accentPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'إحصائيات الألواح الجاهزة بالمستودع',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'إجمالي الألواح المربعة (<= 5سم):',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${totalSlabsM2.fmt} م²',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.scrapBoxAccent,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'إجمالي الكتل التكعيبية (> 5سم):',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${totalSlabsM3.fmt} م³',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.partnersEquityAccent,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        ...erp.factoryWarehouse.map(
                          (w) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${w.typeName} ${w.thicknessCm}سم (${w.grade})',
                                ),
                                Text(
                                  '${w.availableQty} ${w.category == "متر مربع" ? "م²" : "م³"}',
                                  style: const TextStyle(
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
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // SUB-TAB 2: FACTORY INVENTORY GROUPED BY TYPE + GRADE (Section 2)
  //
  // Each supplier invoice line lands here classified by block type, grade,
  // supplier name and that supplier's price per ton. Per supplier lot the
  // user enters the tons required for cutting (+) into the aggregation.
  // -------------------------------------------------------------
  Widget _buildSubTab2BlockStock(ERPProvider erp) {
    final Map<String, List<FactoryBlockModel>> groups = {};
    for (final b in erp.factoryBlocks) {
      groups.putIfAbsent('${b.typeName}||${b.grade}', () => []).add(b);
    }
    final double grandTons = erp.factoryBlocks.fold(
      0.0,
      (s, b) => s + b.weightTons,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'مخزون المصنع (البلوكات) مصنفاً حسب النوع والدرجة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.chipBgBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'إجمالي المتاح: ${grandTons.fmt} طن',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (groups.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'المخزون فارغ. أضف فاتورة شراء من مورد لتغذية المخزون.',
                  ),
                ),
              ),
            ),

          ...groups.entries.map((entry) {
            final parts = entry.key.split('||');
            final typeName = parts[0];
            final grade = parts.length > 1 ? parts[1] : '';
            final lots = entry.value;
            final totalTons = lots.fold(0.0, (s, b) => s + b.weightTons);
            final isGranite = lots.first.isGranite;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: isGranite
                      ? AppColors.chipBgBlue
                      : AppColors.chipBgAmber,
                  child: Icon(
                    isGranite ? Icons.grid_on : Icons.view_comfy,
                    color: isGranite
                        ? AppColors.accentPrimary
                        : AppColors.partnersEquityAccent,
                  ),
                ),
                title: Text(
                  '$typeName ($grade) — المتاح: ${totalTons.fmt} طن',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${lots.length} شحنات موردين'),
                children: [
                  ...lots.map((b) {
                    final picked = selectedCuttingTons[b.id] ?? 0.0;
                    final remaining = (b.weightTons - picked).clamp(
                      0.0,
                      double.infinity,
                    );
                    final qtyCtrl = _cuttingQtyCtrl(b.id);
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.panelBorder),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'المورد ${b.supplierName} — ${b.weightTons.fmt} طن — تكلفة الطن ${b.tonCost.fmt}\$${b.tonSellingPrice > 0 ? ' — سعر البيع ${b.tonSellingPrice.fmt}\$' : ''}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (picked > 0)
                                    Text(
                                      'المحدد للقص: ${picked.fmt} طن (المتبقي: ${remaining.fmt})',
                                      style: const TextStyle(
                                        color: AppColors.successGreen,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 130,
                              child: TextField(
                                controller: qtyCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'أطنان للقص',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.partnersEquityAccent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                              onPressed: () {
                                final q = double.tryParse(qtyCtrl.text) ?? 0.0;
                                if (q <= 0 || q > remaining + 0.0001) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'أدخل عدد أطنان صحيح ضمن المتاح من هذه الشحنة.',
                                      ),
                                      backgroundColor: AppColors.dangerWaste,
                                    ),
                                  );
                                  return;
                                }
                                setState(() {
                                  selectedCuttingTons[b.id] =
                                      (selectedCuttingTons[b.id] ?? 0.0) + q;
                                  cuttingAggregated = false;
                                  cuttingAggregates = [];
                                  qtyCtrl.clear();
                                });
                              },
                              child: const Text('+'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: OutlinedButton.icon(
                      onPressed: () => _showAddBlockTypeDialog(erp),
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة نوع بلوك'),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 20),

          // Selected tons list.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الأطنان المحددة للقص:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  if (selectedCuttingTons.isEmpty)
                    const Text(
                      'لم يتم تحديد أي أطنان بعد.',
                      style: TextStyle(color: AppColors.brandSecondaryText),
                    ),
                  ...selectedCuttingTons.entries.map((e) {
                    final matches = erp.factoryBlocks
                        .where((b) => b.id == e.key)
                        .toList();
                    if (matches.isEmpty) return const SizedBox.shrink();
                    final b = matches.first;
                    return ListTile(
                      dense: true,
                      title: Text(
                        '${b.typeName} (${b.grade}) • المورد ${b.supplierName}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${e.value.fmt} طن × ${b.tonCost.fmt}\$ = ${(e.value * b.tonCost).fmt}\$',
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.dangerWaste,
                        ),
                        onPressed: () => setState(() {
                          selectedCuttingTons.remove(e.key);
                          cuttingAggregated = false;
                          cuttingAggregates = [];
                        }),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentPrimary,
                      ),
                      onPressed: selectedCuttingTons.isEmpty
                          ? null
                          : () => _aggregateCutting(erp),
                      icon: const Icon(Icons.functions_rounded),
                      label: const Text('تجميع (Aggregate)'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Aggregation results table.
          if (cuttingAggregated && cuttingAggregates.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              color: AppColors.chipBgGreen.withValues(alpha: 0.35),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'نتيجة التجميع (الوسط الحسابي لكل نوع ودرجة):',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'إجمالي سعر أطنان الموردين ÷ إجمالي عدد الأطنان',
                      style: TextStyle(
                        color: AppColors.brandSecondaryText,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...cuttingAggregates.map(
                      (a) => Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.panelBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${a.typeName} (${a.grade}) — ${a.totalTons.fmt} طن من ${a.selections.length} موردين',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              'السعر الوسطي: ${a.avgTonCost.fmt} \$/طن',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.scrapBoxAccent,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentPrimary,
                          padding: const EdgeInsets.all(16),
                        ),
                        onPressed: () => _transferToCutting(erp),
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text(
                          '[نقل إلى عملية القص]',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Arithmetic mean per type+grade:
  /// total price of supplier tons / total number of tons.
  void _aggregateCutting(ERPProvider erp) {
    final Map<String, List<MapEntry<String, double>>> perGroup = {};
    selectedCuttingTons.forEach((blockId, tons) {
      final matches = erp.factoryBlocks.where((b) => b.id == blockId).toList();
      if (matches.isEmpty || tons <= 0) return;
      final b = matches.first;
      perGroup
          .putIfAbsent('${b.typeName}||${b.grade}', () => [])
          .add(MapEntry(blockId, tons));
    });

    final result = <CuttingBatchInput>[];
    perGroup.forEach((key, entries) {
      final parts = key.split('||');
      double totalTons = 0.0;
      double totalPrice = 0.0;
      final sels = <CuttingBatchSelection>[];
      bool isGranite = false;
      for (final e in entries) {
        final b = erp.factoryBlocks.firstWhere((x) => x.id == e.key);
        isGranite = b.isGranite;
        totalTons += e.value;
        totalPrice += e.value * b.tonCost;
        sels.add(
          CuttingBatchSelection(
            blockId: b.id,
            supplierName: b.supplierName,
            tons: e.value,
            tonCost: b.tonCost,
          ),
        );
      }
      if (totalTons > 0) {
        result.add(
          CuttingBatchInput(
            typeName: parts[0],
            grade: parts.length > 1 ? parts[1] : '',
            isGranite: isGranite,
            totalTons: totalTons,
            avgTonCost: totalPrice / totalTons,
            selections: sels,
          ),
        );
      }
    });

    setState(() {
      cuttingAggregates = result;
      cuttingAggregated = result.isNotEmpty;
    });
    if (result.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر التجميع: تحقق من الأطنان المحددة.'),
          backgroundColor: AppColors.dangerWaste,
        ),
      );
    }
  }

  void _transferToCutting(ERPProvider erp) {
    erp.setPendingCuttingBatch(List.of(cuttingAggregates));
    setState(() {
      selectedCuttingTons.clear();
      cuttingAggregated = false;
      cuttingAggregates = [];
    });
    widget.onNavigateToCutting(0); // Cutting Calculator screen.
  }

  // -------------------------------------------------------------
  // SUB-TAB 3: SLABS & CUBES WAREHOUSE
  // -------------------------------------------------------------
  Widget _buildSubTab3SlabsWarehouse(ERPProvider erp) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: const Color(0xFFF1F5F9),
            child: const TabBar(
              tabs: [
                Tab(text: 'قسم المتر المربع (Thickness <= 5cm)'),
                Tab(text: 'قسم المتر المكعب (Thickness > 5cm)'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildWarehouseGrid(
                  erp,
                  erp.factoryWarehouse
                      .where((w) => w.category != 'متر مكعب')
                      .toList(),
                  isM2: true,
                ),
                _buildWarehouseGrid(
                  erp,
                  erp.factoryWarehouse
                      .where((w) => w.category == 'متر مكعب')
                      .toList(),
                  isM2: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarehouseGrid(
    ERPProvider erp,
    List<FactoryWarehouseModel> items, {
    required bool isM2,
  }) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
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
                    Text(
                      item.typeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.chipBgGreen,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.grade,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.scrapBoxAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'السماكة المصنعة: ${item.thicknessCm} سم',
                  style: const TextStyle(
                    color: AppColors.brandSecondaryText,
                    fontSize: 12,
                  ),
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'الكمية المتاحة:',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      '${item.availableQty.fmt} ${item.category == "متر مكعب" ? "م³" : (item.category == "متر طولي" ? "م.ط" : "م²")}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.accentPrimary,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'التكلفة الصافية:',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      '${item.netCostPerUnit.fmt} \$ / ${isM2 ? "م²" : "م³"}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'سعر البيع المقترح:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${item.recommendedSalePrice.fmt} \$',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.successGreen,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accentPrimary,
                      side: const BorderSide(color: AppColors.accentPrimary),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () =>
                        _showEditWarehouseSalePriceDialog(erp, item, isM2),
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: const Text(
                      'تعديل سعر البيع',
                      style: TextStyle(
                        fontSize: 12,
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

  void _showEditWarehouseSalePriceDialog(
    ERPProvider erp,
    FactoryWarehouseModel item,
    bool isM2,
  ) {
    final priceCtrl =
        TextEditingController(text: item.recommendedSalePrice.fmt);
    final unit = isM2 ? 'م²' : 'م³';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final newPrice = double.tryParse(priceCtrl.text) ?? 0.0;
          final margin = newPrice - item.netCostPerUnit;
          final marginPct = newPrice > 0 ? (margin / newPrice * 100) : 0.0;

          return AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.edit_note_rounded, color: AppColors.accentPrimary),
                SizedBox(width: 8),
                Text('تعديل سعر بيع الأمتار بالمستودع'),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                          '${item.typeName} • ${item.grade}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'السماكة: ${item.thicknessCm} سم • المتاح: ${item.availableQty.fmt} $unit',
                          style: const TextStyle(
                            color: AppColors.brandSecondaryText,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'التكلفة الصافية للوحدة: ${item.netCostPerUnit.fmt} \$',
                          style: const TextStyle(
                            color: AppColors.brandSecondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: priceCtrl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'سعر البيع الجديد (\$ لكل $unit)',
                      prefixIcon: const Icon(Icons.attach_money_rounded),
                    ),
                    onChanged: (_) => setSt(() {}),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: margin >= 0
                          ? AppColors.chipBgGreen
                          : AppColors.chipBgRed,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'هامش الربح المتوقع:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: margin >= 0
                                ? AppColors.successGreen
                                : AppColors.dangerWaste,
                          ),
                        ),
                        Text(
                          '${margin >= 0 ? "+" : ""}${margin.fmt}\$ (${marginPct.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: margin >= 0
                                ? AppColors.successGreen
                                : AppColors.dangerWaste,
                          ),
                        ),
                      ],
                    ),
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
                  if (newPrice < 0) return;
                  erp.updateFactoryWarehouseSalePrice(item.id, newPrice);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تم تحديث سعر بيع (${item.typeName}) إلى ${newPrice.fmt} \$ بنجاح.',
                      ),
                      backgroundColor: AppColors.successGreen,
                    ),
                  );
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text('حفظ السعر الجديد'),
              ),
            ],
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------
  // SUB-TAB 4: PERSONS (SUPPLIERS & CLIENTS)
  // -------------------------------------------------------------
  Widget _buildSubTab4Persons(ERPProvider erp) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: const Color(0xFFF1F5F9),
            child: const TabBar(
              tabs: [
                Tab(text: '1. الموردين (Suppliers)'),
                Tab(text: '2. المعتمدين والزبائن (Clients)'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Tab 1: Suppliers List
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'قائمة الموردين المعتمدين للبلوكات والغرانيت',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showAddSupplierDialog(erp),
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة مورد جديد'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Card(
                          child: ListView.separated(
                            itemCount: erp.suppliers.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final s = erp.suppliers[idx];
                              return ListTile(
                                title: Text(
                                  s.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'الهاتف: ${s.phone} • الموقع: ${s.location}',
                                ),
                                trailing: Text(
                                  'الذمة المستحقة: ${s.dualDebt}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
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
                ),
                // Tab 2: Clients List
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'قائمة المعتمدين والمصانع والزبائن',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showAddClientDialog(erp),
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة معتمد/زبون جديد'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Card(
                          child: ListView.separated(
                            itemCount: erp.clients.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final c = erp.clients[idx];
                              return ListTile(
                                title: Text(
                                  c.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'النوع: ${c.clientType} • الهاتف: ${c.phone} • الموقع: ${c.location}',
                                ),
                                trailing: Text(
                                  'الديون المستحقة: ${c.dualDebt}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.accentPrimary,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // SUB-TAB 5: TYPES & METER CATEGORIES
  // -------------------------------------------------------------
  Widget _buildSubTab5Types(ERPProvider erp) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'تعريف أنواع وأصناف المواد',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'إدارة أصناف البلوكات الخام وألواح الأمتار مع التوجيه التلقائي للمخزون.',
                    style: TextStyle(
                      color: AppColors.brandSecondaryText,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: () => _showUnifiedItemTypeDialog(erp),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('إضافة نوع مادة جديد (Add New Item Type)'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'قائمة الأصناف والخامات العامة (Unified Item Types)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Text(
                'إجمالي الأنواع: ${erp.blockTypes.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandSecondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: erp.blockTypes.isEmpty
                ? const ListTile(title: Text('لا توجد أنواع خامات أو مواد معرفة بعد.'))
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: erp.blockTypes.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final type = erp.blockTypes[idx];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: type.isGranite
                              ? AppColors.chipBgBlue
                              : AppColors.chipBgAmber,
                          child: Icon(
                            type.isGranite ? Icons.grid_on : Icons.view_comfy,
                            color: type.isGranite
                                ? AppColors.accentPrimary
                                : AppColors.partnersEquityAccent,
                          ),
                        ),
                        title: Text(
                          type.typeName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'النخب / الدرجة: ${type.grade} • الخامة: ${type.isGranite ? "غرانيت مستورد" : "رخام طبيعي"}',
                        ),
                        trailing: IconButton(
                          tooltip: 'تعديل نوع المادة',
                          icon: const Icon(Icons.edit_outlined, color: AppColors.accentPrimary),
                          onPressed: () =>
                              _showUnifiedItemTypeDialog(erp, existing: type),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showUnifiedItemTypeDialog(
    ERPProvider erp, {
    BlockTypeModel? existing,
  }) async {
    final nameController = TextEditingController(text: existing?.typeName ?? '');
    final gradeController = TextEditingController(text: existing?.grade ?? 'درجة أولى');
    bool isGranite = existing?.isGranite ?? false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  existing == null ? Icons.add_circle_outline : Icons.edit_outlined,
                  color: AppColors.accentPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  existing == null
                      ? 'إضافة نوع صنف عام (Add New Item Type)'
                      : 'تعديل نوع المادة (Edit Item Type)',
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم الصنف / المادة *',
                        hintText: 'مثال: رخام كاردينال، بيج تركي، غرانيت أسود',
                        prefixIcon: Icon(Icons.format_paint_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: gradeController,
                      decoration: const InputDecoration(
                        labelText: 'الدرجة / النخب',
                        hintText: 'درجة أولى، نخب أول، تجاري',
                        prefixIcon: Icon(Icons.grade_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('هل المادة غرانيت مستورد؟'),
                      subtitle: Text(
                        'يخضع لنسبة أرباح المحاسب (${erp.graniteAccountantPercentage.fmt}%)',
                      ),
                      value: isGranite,
                      onChanged: (value) =>
                          setDialogState(() => isGranite = value),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  final grade = gradeController.text.trim().isEmpty
                      ? 'درجة أولى'
                      : gradeController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('يرجى إدخال اسم الصنف / المادة.'),
                        backgroundColor: AppColors.dangerWaste,
                      ),
                    );
                    return;
                  }

                  if (existing == null) {
                    final newId = 'bt_${DateTime.now().millisecondsSinceEpoch}';
                    erp.addBlockType(
                      BlockTypeModel(
                        id: newId,
                        typeName: name,
                        grade: grade,
                        isGranite: isGranite,
                      ),
                    );
                    erp.addMeterType(
                      MeterTypeModel(
                        id: 'meter_$newId',
                        typeName: name,
                        grade: grade,
                        thicknessCm: 0.0,
                        category: 'متر مربع',
                        isGranite: isGranite,
                      ),
                    );
                  } else {
                    erp.updateBlockType(
                      BlockTypeModel(
                        id: existing.id,
                        typeName: name,
                        grade: grade,
                        isGranite: isGranite,
                      ),
                    );
                  }

                  Navigator.pop(dialogContext, true);
                },
                child: Text(existing == null ? 'حفظ وإضافة' : 'حفظ التعديلات'),
              ),
            ],
          );
        },
      ),
    );

    nameController.dispose();
    gradeController.dispose();
    if (saved == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? 'تمت إضافة نوع المادة كصنف عام وشامل في البلوكات والألواح.'
                : 'تم حفظ تعديل نوع المادة بنجاح.',
          ),
          backgroundColor: AppColors.successGreen,
        ),
      );
    }
  }

  // -------------------------------------------------------------
  // SUB-TAB 6: SUPPLIER PURCHASE INVOICES
  // -------------------------------------------------------------
  Widget _buildCashFactoryInvoices(ERPProvider erp) {
    final purchases = erp.factoryInvoices
        .where((invoice) => invoice.isCashInvoice &&
            invoice.invoiceType == 'شراء_مورد')
        .toList();
    final sales = erp.factoryInvoices
        .where((invoice) => invoice.isCashInvoice &&
            invoice.invoiceType == 'بيع_معتمد')
        .toList();
    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'فواتير نقدية مسددة بالكامل من/إلى الصندوق الرئيسي',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              color: const Color(0xFFF1F5F9),
              child: const TabBar(
                tabs: [
                  Tab(text: 'مبيعات نقدية'),
                  Tab(text: 'مشتريات نقدية'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [
                  Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _showAddPOSInvoiceDialog(erp, cashInvoice: true),
                          icon: const Icon(Icons.point_of_sale_rounded),
                          label: const Text('إضافة فاتورة بيع نقدية'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _buildPosInvoiceList(
                          sales,
                          emptyHint: 'لا توجد فواتير مبيعات نقدية.',
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _showAddSupplierInvoiceDialog(erp, cashInvoice: true),
                          icon: const Icon(Icons.payments_rounded),
                          label: const Text('إضافة فاتورة شراء نقدية'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _buildSupplierInvoiceList(
                          purchases,
                          emptyHint: 'لا توجد فواتير مشتريات نقدية.',
                        ),
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

  Widget _buildSubTab6SupplierPurchases(ERPProvider erp) {
    final due = erp.factoryInvoices
        .where((i) => i.invoiceType == 'شراء_مورد' && i.isDue)
        .toList();
    final paid = erp.factoryInvoices
        .where((i) => i.invoiceType == 'شراء_مورد' && !i.isDue)
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
                const Text(
                  'فواتير شراء البلوكات الخام من الموردين',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddSupplierInvoiceDialog(erp),
                  icon: const Icon(Icons.note_add_rounded),
                  label: const Text('[إضافة فاتورة شراء من مورد]'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              color: const Color(0xFFF1F5F9),
              child: const TabBar(
                tabs: [
                  Tab(text: 'مستحق الدفع (Due Payment)'),
                  Tab(text: 'مدفوعة (Paid)'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [
                  _buildSupplierInvoiceList(
                    due,
                    emptyHint: 'لا توجد فواتير مستحقة الدفع.',
                  ),
                  _buildSupplierInvoiceList(
                    paid,
                    emptyHint: 'لا توجد فواتير مدفوعة بالكامل بعد.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierInvoiceList(
    List<FactoryInvoiceModel> invoices, {
    required String emptyHint,
  }) {
    if (invoices.isEmpty) {
      return Card(child: Center(child: Text(emptyHint)));
    }
    return Card(
      child: ListView.separated(
        itemCount: invoices.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, idx) {
          final inv = invoices[idx];
          return ExpansionTile(
            leading: CurrencyBadge(currency: inv.currency),
            title: Text(
              '${inv.invoiceNo} • ${inv.partyName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'التاريخ: ${intl.DateFormat("yyyy-MM-dd").format(inv.date)} • الإجمالي: ${inv.grandTotal.fmt}${inv.currencySymbol} • المدفوع: ${inv.advancePayment.fmt}${inv.currencySymbol} • المتبقي: ${inv.remainingBalance.fmt}${inv.currencySymbol}',
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
                      invoiceData: A4InvoiceData.fromFactoryInvoice(inv),
                    );
                  },
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        inv.isDue ? AppColors.chipBgRed : AppColors.chipBgGreen,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    inv.isDue ? 'مستحق الدفع' : 'مدفوعة',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: inv.isDue
                          ? AppColors.dangerWaste
                          : AppColors.successGreen,
                    ),
                  ),
                ),
              ],
            ),
            children: [
              ...inv.items.map(
                (it) => ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: it.isMeterItem
                          ? AppColors.chipBgBlue
                          : AppColors.chipBgAmber,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      it.isMeterItem ? 'أمتار' : 'بلوك',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: it.isMeterItem
                            ? AppColors.accentPrimary
                            : AppColors.partnersEquityAccent,
                      ),
                    ),
                  ),
                  title: Text(
                    '${it.typeName.isNotEmpty ? it.typeName : it.description} ${it.grade}${it.isMeterItem && it.thicknessCm > 0 ? " (${it.thicknessCm.fmt} سم)" : ""}',
                  ),
                  subtitle: Text(
                    it.isMeterItem
                        ? '${it.quantity.fmt} ${it.meterUnit.isNotEmpty ? it.meterUnit : "متر"} × ${it.unitPrice.fmt}${inv.currencySymbol} = ${(it.quantity * it.unitPrice).fmt}${inv.currencySymbol}'
                        : '${it.quantity.fmt} طن × ${it.unitPrice.fmt}${inv.currencySymbol} = ${(it.quantity * it.unitPrice).fmt}${inv.currencySymbol}',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'واصلة: ${inv.isGoodsDelivered ? "نعم" : "لا (شحن: ${inv.shippingFee}${inv.currencySymbol})"}',
                    ),
                    Text(
                      'المتبقي: ${inv.remainingBalance.fmt} ${inv.currencySymbol}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------
  // SUB-TAB 7: POS FACTORY SALES TO CLIENTS
  // -------------------------------------------------------------
  Widget _buildSubTab7POSSales(ERPProvider erp) {
    final pending = erp.factoryInvoices
        .where((i) => i.invoiceType == 'بيع_معتمد' && i.isDue)
        .toList();
    final paid = erp.factoryInvoices
        .where((i) => i.invoiceType == 'بيع_معتمد' && !i.isDue)
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
                const Text(
                  'فواتير المعتمدين المعتمدين (Factory Approved Clients Invoices)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary,
                  ),
                  onPressed: () => _showAddPOSInvoiceDialog(erp),
                  icon: const Icon(Icons.point_of_sale_rounded),
                  label: const Text('[إضافة فاتورة مصنع]'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              color: const Color(0xFFF1F5F9),
              child: const TabBar(
                tabs: [
                  Tab(text: 'تحصيل معلق / مستحق الدفع (Pending Collection)'),
                  Tab(text: 'مدفوعة / مكتملة (Paid)'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [
                  _buildPosInvoiceList(
                    pending,
                    emptyHint: 'لا توجد فواتير بانتظار التحصيل.',
                  ),
                  _buildPosInvoiceList(
                    paid,
                    emptyHint: 'لا توجد فواتير مدفوعة بالكامل بعد.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPosInvoiceList(
    List<FactoryInvoiceModel> invoices, {
    required String emptyHint,
  }) {
    if (invoices.isEmpty) {
      return Card(child: Center(child: Text(emptyHint)));
    }
    return Card(
      child: ListView.separated(
        itemCount: invoices.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, idx) {
          final inv = invoices[idx];
          return ExpansionTile(
            leading: CurrencyBadge(currency: inv.currency),
            title: Text(
              '${inv.invoiceNo} • المعتمد: ${inv.partyName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'الأصناف: ${inv.items.length} • الإجمالي: ${inv.grandTotal.fmt}${inv.currencySymbol} • المدفوع: ${inv.advancePayment.fmt}${inv.currencySymbol} • المتبقي: ${inv.remainingBalance.fmt}${inv.currencySymbol} • التوصيل: ${inv.shippingFee > 0 ? "من قبلنا (${inv.shippingFee}${inv.currencySymbol})" : "الزبون"}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: inv.isDue
                        ? AppColors.chipBgRed
                        : AppColors.chipBgGreen,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    inv.isDue ? 'مستحق الدفع' : 'مدفوعة',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: inv.isDue
                          ? AppColors.dangerWaste
                          : AppColors.successGreen,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'معاينة طباعة A4 (Print Preview)',
                  icon: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Color(0xFF2563EB),
                  ),
                  onPressed: () {
                    A4InvoicePrintDialog.show(
                      context,
                      invoiceData: A4InvoiceData.fromFactoryInvoice(inv),
                    );
                  },
                ),
                IconButton(
                  tooltip: 'إيصال حراري (Thermal)',
                  icon: const Icon(
                    Icons.print_rounded,
                    color: AppColors.brandPrimaryText,
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => ThermalReceiptDialog(
                        title: 'فاتورة بيع مصنع',
                        invoiceNo: inv.invoiceNo,
                        dateText: intl.DateFormat(
                          'yyyy-MM-dd',
                        ).format(inv.date),
                        partyName: inv.partyName,
                        items: [
                          ...inv.items.map(
                            (i) => {
                              'name': i.description,
                              'details': '${i.lengthCm}x${i.widthCm}سم',
                              'qty': i.calculatedArea.fmt,
                              'total': i.grandTotal.fmt,
                            },
                          ),
                          ...inv.items.expand(
                            (i) => i.services.map(
                              (s) => {
                                'name': 'خدمة: ${s.serviceName}',
                                'details': s.notes,
                                'qty': '1',
                                'total': s.price.fmt,
                              },
                            ),
                          ),
                        ],
                        subtotal: inv.subtotal + inv.itemsServicesTotal,
                        shippingFee: inv.shippingFee,
                        advancePayment: inv.advancePayment,
                        grandTotal: inv.grandTotal,
                        remainingBalance: inv.remainingBalance,
                      ),
                    );
                  },
                ),
              ],
            ),
            children: [
              ...inv.items.map(
                (it) => ExpansionTile(
                  title: Text(
                    it.description,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    'الكمية: ${it.calculatedArea.fmt} • الإجمالي: ${it.grandTotal.fmt}${inv.currencySymbol}',
                  ),
                  children: [
                    ...it.services.map(
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
                ),
              ),
              if (inv.photoUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: AppImagePreviewCard(
                    imagePath: inv.photoUrl,
                    title: 'صورة الفاتورة المرفقة (${inv.invoiceNo})',
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------
  // SUB-TAB 8: HISTORICAL CUTTING LOG
  // -------------------------------------------------------------
  Widget _buildSubTab8CuttingLog(ERPProvider erp) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'سجل تاريخ عمليات القص والتحويل المصنعية',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: ListView.separated(
                itemCount: erp.cuttingOperations.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final cut = erp.cuttingOperations[idx];
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.chipBgAmber,
                      child: Icon(
                        Icons.content_cut_rounded,
                        color: AppColors.partnersEquityAccent,
                      ),
                    ),
                    title: Text(
                      'عملية قص: ${cut.targetTypeName} (${cut.thicknessCm}سم)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'التاريخ: ${intl.DateFormat("yyyy-MM-dd HH:mm").format(cut.timestamp)} • الأطنان المدخلة: ${cut.inputTons} طن • نسبة أجرة القص: ${(cut.cuttingFeePercentage * 100).fmt}%',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'المخرجات: ${cut.totalOutputArea} ${cut.category == "متر مربع" ? "م²" : "م³"}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'التكلفة الصافية: ${cut.netCostPerUnit.fmt}\$',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.accentPrimary,
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
  // SUB-TAB 9: FACTORY CUSTOM ORDERS
  // -------------------------------------------------------------
  Widget _buildSubTab9FactoryOrders(ERPProvider erp) {
    final allOrders = erp.factoryOrders;
    final inProgress = allOrders.where((o) => o.status == 'قيد التنفيذ').toList();
    final completed = allOrders.where((o) => o.status == 'مكتملة ومرحلة').toList();
    final cancelled = allOrders.where((o) => o.status.startsWith('ملغاة')).toList();

    List<FactoryOrderModel> filtered = allOrders;
    if (_foStatusFilter == 'قيد التنفيذ') {
      filtered = inProgress;
    } else if (_foStatusFilter == 'مكتملة ومرحلة') {
      filtered = completed;
    } else if (_foStatusFilter == 'ملغاة') {
      filtered = cancelled;
    }

    if (_foSearchQuery.isNotEmpty) {
      filtered = filtered.where((o) {
        final q = _foSearchQuery.toLowerCase();
        return o.orderNo.toLowerCase().contains(q) ||
            o.clientName.toLowerCase().contains(q) ||
            o.clientPhone.contains(q) ||
            o.items.any((it) => it.description.toLowerCase().contains(q));
      }).toList();
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.orderDepositBoxAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.assignment_turned_in_rounded,
                      color: AppColors.orderDepositBoxAccent,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'طلبيات المصنع (Factory Orders)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'أوامر تشغيل وتجهيز طلبيات المصنع مع حفظ وتتبع العربونات المعزولة وخصم المواد من المستودع',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.brandSecondaryText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orderDepositBoxAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => showAddFactoryOrderDialog(context, erp),
                icon: const Icon(Icons.post_add_rounded),
                label: const Text(
                  'إضافة طلبية مصنع جديدة +',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Metric Statistics Cards
          Row(
            children: [
              Expanded(
                child: _buildOrderStatCard(
                  title: 'إجمالي طلبيات المصنع',
                  value: '${allOrders.length}',
                  icon: Icons.list_alt_rounded,
                  color: AppColors.accentPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOrderStatCard(
                  title: 'قيد التنفيذ (معلقة)',
                  value: '${inProgress.length}',
                  icon: Icons.pending_actions_rounded,
                  color: const Color(0xFFD97706),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOrderStatCard(
                  title: 'مكتملة ومرحلة لفواتير',
                  value: '${completed.length}',
                  icon: Icons.check_circle_rounded,
                  color: AppColors.successGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOrderStatCard(
                  title: 'ملغاة',
                  value: '${cancelled.length}',
                  icon: Icons.cancel_rounded,
                  color: AppColors.dangerWaste,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOrderStatCard(
                  title: 'صندوق العربونات المعزول',
                  value: erp.dualOrderCash,
                  icon: Icons.savings_rounded,
                  color: AppColors.orderDepositBoxAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search and Filters Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'بحث برقم الطلبية أو اسم الزبون أو الهاتف...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.panelBorder),
                    ),
                  ),
                  onChanged: (v) => setState(() => _foSearchQuery = v.trim()),
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 6,
                children: ['الكل', 'قيد التنفيذ', 'مكتملة ومرحلة', 'ملغاة']
                    .map((status) => ChoiceChip(
                          label: Text(status),
                          selected: _foStatusFilter == status,
                          onSelected: (sel) {
                            if (sel) setState(() => _foStatusFilter = status);
                          },
                        ))
                    .toList(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Orders List
          Expanded(
            child: Card(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'لا توجد طلبيات تطابق الفلتر الحالي.',
                            style: TextStyle(
                              color: AppColors.brandSecondaryText,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, idx) {
                        final ord = filtered[idx];
                        final bool isInProgress = ord.status == 'قيد التنفيذ';
                        final bool isOrdCompleted =
                            ord.status == 'مكتملة ومرحلة';
                        final bool isOrdCancelled =
                            ord.status.startsWith('ملغاة');

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isInProgress
                                  ? AppColors.orderDepositBoxAccent
                                      .withValues(alpha: 0.3)
                                  : isOrdCompleted
                                      ? const Color(0xFFBBF7D0)
                                      : const Color(0xFFFECACA),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ExpansionTile(
                            leading: CurrencyBadge(currency: ord.currency),
                            title: Row(
                              children: [
                                Text(
                                  ord.orderNo,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '• الزبون: ${ord.clientName}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                ),
                                if (ord.clientPhone.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '(${ord.clientPhone})',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isInProgress
                                        ? const Color(0xFFFEF3C7)
                                        : isOrdCompleted
                                            ? AppColors.chipBgGreen
                                            : AppColors.chipBgRed,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    ord.status,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.5,
                                      color: isInProgress
                                          ? const Color(0xFFB45309)
                                          : isOrdCompleted
                                              ? AppColors.successGreen
                                              : AppColors.dangerWaste,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                children: [
                                  Text(
                                    'التاريخ: ${intl.DateFormat("yyyy-MM-dd").format(ord.date)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    'عدد البنود: ${ord.items.length} (${ord.totalArea.fmt} م)',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F766E),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    'الإجمالي: ${ord.grandTotal.fmt} ${ord.currencySymbol}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.orderDepositBoxAccent
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'العربون المعزول: ${ord.depositAmount.fmt} ${ord.currencySymbol}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.orderDepositBoxAccent,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    'المتبقي: ${ord.remainingBalance.fmt} ${ord.currencySymbol}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: ord.remainingBalance > 0
                                          ? AppColors.dangerWaste
                                          : AppColors.successGreen,
                                    ),
                                  ),
                                  if (ord.assignedInvoiceNo.isNotEmpty) ...[
                                    const SizedBox(width: 16),
                                    Text(
                                      'فاتورة: ${ord.assignedInvoiceNo}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            children: [
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Items details
                                    const Text(
                                      'بنود ومواصفات الطلبية:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ...ord.items.asMap().entries.map((entry) {
                                      final it = entry.value;
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 6),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: AppColors.panelBorder,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 12,
                                              backgroundColor:
                                                  AppColors.accentPrimary
                                                      .withValues(alpha: 0.1),
                                              child: Text(
                                                '${entry.key + 1}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      AppColors.accentPrimary,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                it.description,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12.5,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                (it.lengthCm > 0 &&
                                                        it.widthCm > 0)
                                                    ? '${it.lengthCm.fmt} × ${it.widthCm.fmt}${it.heightCm > 5 ? " × ${it.heightCm.fmt}" : ""} سم'
                                                    : '—',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                '${it.calculatedArea.fmt} ${it.heightCm > 5 ? "م³" : "م²"} (${it.quantity.fmt} قطع)',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF15803D),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                '${it.unitPrice.fmt}\$ / م',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            if (it.services.isNotEmpty)
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  'خدمات (${it.services.length}): ${it.servicesTotal.fmt}\$',
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    color: Color(0xFF2563EB),
                                                  ),
                                                ),
                                              ),
                                            Text(
                                              '${it.grandTotal.fmt} \$',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                    const SizedBox(height: 10),

                                    // Delivery and notes info
                                    Row(
                                      children: [
                                        Text(
                                          ord.isGoodsDelivered
                                              ? 'التوصيل: نوصّل نحن (تكلفة: ${ord.shippingFee.fmt} ${ord.currencySymbol})'
                                              : 'التوصيل: الزبون يستلم النقل من أرض المصنع',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                        if (ord.discountAmount > 0) ...[
                                          const SizedBox(width: 20),
                                          Text(
                                            'خصم مبيعات: ${ord.discountAmount.fmt} ${ord.currencySymbol}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.dangerWaste,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                        if (ord.photoPath.isNotEmpty) ...[
                                          const SizedBox(width: 20),
                                          AppImageThumbnail(
                                            imagePath: ord.photoPath,
                                            title: 'مخطط طلبية ${ord.orderNo}',
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 14),

                                    // Action buttons row
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.end,
                                      children: [
                                        // Preview for Printing button
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF2563EB),
                                            foregroundColor: Colors.white,
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                          ),
                                          onPressed: () {
                                            A4InvoicePrintDialog.show(
                                              context,
                                              invoiceData:
                                                  A4InvoiceData
                                                      .fromFactoryOrder(ord),
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.print_rounded,
                                            size: 18,
                                          ),
                                          label: const Text(
                                            'معاينة للطباعة (أمر تشغيل للورشة)',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),

                                        if (isInProgress) ...[
                                          const SizedBox(width: 10),
                                          // Assign to POS invoice button
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.successGreen,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 10,
                                              ),
                                            ),
                                            onPressed: () =>
                                                _showAssignFactoryOrderDialog(
                                              erp,
                                              ord,
                                            ),
                                            icon: const Icon(
                                              Icons.point_of_sale_rounded,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              'إسناد لفاتورة معتمدين',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          // Cancel order button
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  AppColors.dangerWaste,
                                              side: const BorderSide(
                                                color: AppColors.dangerWaste,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 10,
                                              ),
                                            ),
                                            onPressed: () =>
                                                showCancelFactoryOrderDialog(
                                              context,
                                              erp,
                                              ord,
                                            ),
                                            icon: const Icon(
                                              Icons.cancel_outlined,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              'إلغاء الطلب',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
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

  Widget _buildOrderStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.panelBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.brandSecondaryText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddFactoryOrderDialog(ERPProvider erp) {
    showAddFactoryOrderDialog(context, erp);
  }

  void _showAssignFactoryOrderDialog(ERPProvider erp, FactoryOrderModel ord) {
    _showAddPOSInvoiceDialog(erp, initialOrder: ord);
  }

  void _showCancelFactoryOrderDialog(ERPProvider erp, FactoryOrderModel ord) {
    showCancelFactoryOrderDialog(context, erp, ord);
  }

  // DIALOGS & POPUPS HELPERS
  Future<void> _showAddSupplierDialog(ERPProvider erp) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة مورد جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'اسم المورد'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'رقم الهاتف'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: locCtrl,
              decoration: const InputDecoration(labelText: 'الموقع / المدينة'),
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
                erp.addSupplier(
                  SupplierModel(
                    id: 'sup_${DateTime.now().millisecondsSinceEpoch}',
                    name: nameCtrl.text,
                    phone: phoneCtrl.text,
                    location: locCtrl.text,
                  ),
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddClientDialog(ERPProvider erp) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    String type = 'معتمد مصنع';
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة معتمد/زبون جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'الاسم الكامل'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: type,
              items: const [
                DropdownMenuItem(
                  value: 'معتمد مصنع',
                  child: Text('معتمد مصنع'),
                ),
                DropdownMenuItem(value: 'زبون معمل', child: Text('زبون معمل')),
                DropdownMenuItem(
                  value: 'مشروع معمل',
                  child: Text('مشروع معمل'),
                ),
              ],
              onChanged: (v) => type = v!,
              decoration: const InputDecoration(labelText: 'الصفة'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'الهاتف'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: locCtrl,
              decoration: const InputDecoration(labelText: 'الموقع'),
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
                erp.addClient(
                  ClientModel(
                    id: 'cli_${DateTime.now().millisecondsSinceEpoch}',
                    name: nameCtrl.text,
                    phone: phoneCtrl.text,
                    location: locCtrl.text,
                    clientType: type,
                  ),
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddBlockTypeDialog(ERPProvider erp) async {
    await _showUnifiedItemTypeDialog(erp);
  }

  void _showAddSupplierInvoiceDialog(
    ERPProvider erp, {
    bool cashInvoice = false,
  }) {
    if (erp.suppliers.isEmpty ||
        (erp.blockTypes.isEmpty && erp.meterTypes.isEmpty)) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.info_outline_rounded, color: AppColors.dangerWaste),
              SizedBox(width: 8),
              Expanded(child: Text('لا يمكن إضافة فاتورة شراء')),
            ],
          ),
          content: Text(
            'يجب توفر بيانات أساسية أولاً:\n'
            '${erp.suppliers.isEmpty ? "• مورد واحد على الأقل\n" : ""}'
            '${(erp.blockTypes.isEmpty && erp.meterTypes.isEmpty) ? "• نوع مادة أو صنف واحد على الأقل\n" : ""}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
            if (erp.suppliers.isEmpty)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showAddSupplierDialog(erp);
                },
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('إضافة مورد الآن'),
              ),
            if (erp.blockTypes.isEmpty && erp.meterTypes.isEmpty)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showUnifiedItemTypeDialog(erp);
                },
                icon: const Icon(Icons.add_box_outlined),
                label: const Text('إضافة نوع مادة جديد'),
              ),
          ],
        ),
      );
      return;
    }
    // Full multi-item purchase invoice builder (exact spec):
    // searchable supplier (+ inline add) -> item fields (Blocks & Meters) -> shipment Q ->
    // totals -> payment Q -> save to Due/Paid + Supplier Finances.
    String? selectedSupplierId;
    String supplierSearch = '';
    String itemMode = erp.blockTypes.isNotEmpty ? 'block' : 'meter'; // 'block' | 'meter'

    // Block item fields
    String? selectedBlockKey; // '<typeName>||<grade>'
    String blockSearch = '';
    final tonsCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    // Meter item fields
    String? selectedMeterTypeId;
    String meterSearch = '';
    String selectedMeterUnit = 'متر مربع'; // 'متر مربع' | 'متر طولي' | 'متر مكعب'
    final meterQtyCtrl = TextEditingController();
    final meterPriceCtrl = TextEditingController();
    final meterTotalCostCtrl = TextEditingController();

    final shippingFeeCtrl = TextEditingController();
    final downPayCtrl = TextEditingController();
    final discountCtrl = TextEditingController(text: '0');
    bool? isDelivered;
    bool? wantsPay;
    final List<FactoryInvoiceItem> draftItems = [];
    String? formError;
    String invCurrency = AppCurrency.usd;
    String photoPath = '';

    // Unique block-type options organised by Type + Grade.
    List<BlockTypeModel> blockOptions() {
      final seen = <String>{};
      final out = <BlockTypeModel>[];
      for (final b in erp.blockTypes) {
        final key = '${b.typeName}||${b.grade}';
        if (seen.add(key)) out.add(b);
      }
      return out;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final suppliersFiltered = erp.suppliers
              .where(
                (s) =>
                    supplierSearch.isEmpty || s.name.contains(supplierSearch),
              )
              .toList();
          final supplierValue =
              suppliersFiltered.any((s) => s.id == selectedSupplierId)
              ? selectedSupplierId
              : null;

          final optionsFiltered = blockOptions()
              .where(
                (b) =>
                    blockSearch.isEmpty ||
                    '${b.typeName} ${b.grade}'.contains(blockSearch),
              )
              .toList();
          final blockValue =
              optionsFiltered.any(
                (b) => '${b.typeName}||${b.grade}' == selectedBlockKey,
              )
              ? selectedBlockKey
              : null;

          final meterOptionsFiltered = erp.meterTypes
              .where(
                (m) =>
                    meterSearch.isEmpty ||
                    '${m.typeName} ${m.grade} ${m.thicknessCm} ${m.category}'
                        .contains(meterSearch),
              )
              .toList();
          final meterValue =
              meterOptionsFiltered.any((m) => m.id == selectedMeterTypeId)
              ? selectedMeterTypeId
              : null;

          final double draftTons = double.tryParse(tonsCtrl.text) ?? 0.0;
          final double draftPrice = double.tryParse(priceCtrl.text) ?? 0.0;
          final double draftBlockTotal = draftTons * draftPrice;


          final double itemsTotal = draftItems.fold(
            0.0,
            (s, it) => s + (it.quantity * it.unitPrice),
          );
          final double shipping = (isDelivered == false)
              ? (double.tryParse(shippingFeeCtrl.text) ?? 0.0)
              : 0.0;
          final double discount = double.tryParse(discountCtrl.text) ?? 0.0;
          final double grandTotal = (itemsTotal - discount).clamp(
            0.0,
            double.infinity,
          );
          final double downPay = (wantsPay == true)
              ? (double.tryParse(downPayCtrl.text) ?? 0.0)
              : 0.0;

          Future<void> refreshAfterAdd(Future<void> Function() opener) async {
            await opener();
            setSt(() {});
          }

          Widget yesNoOption(
            String label,
            bool value,
            bool? group,
            ValueChanged<bool?> onChanged,
          ) {
            return Expanded(
              child: InkWell(
                onTap: () => onChanged(value),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Radio<bool>(
                        value: value,
                        groupValue: group,
                        onChanged: onChanged,
                      ),
                      Text(label),
                    ],
                  ),
                ),
              ),
            );
          }

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
                      cashInvoice
                          ? 'إنشاء فاتورة شراء نقدية من مورد'
                          : 'إنشاء فاتورة شراء من مورد',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontSize: 18),
                    ),
                    const Divider(height: 20),

                    // 1. Supplier searchable dropdown + inline add.
                    const Text(
                      '1. اختر المورد (قائمة قابلة للبحث):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'بحث عن مورد...',
                              prefixIcon: Icon(Icons.search),
                              isDense: true,
                            ),
                            onChanged: (v) =>
                                setSt(() => supplierSearch = v.trim()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => refreshAfterAdd(
                            () => _showAddSupplierDialog(erp),
                          ),
                          icon: const Icon(Icons.person_add_alt_1, size: 18),
                          label: const Text('مورد جديد +'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: supplierValue,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'المورد'),
                      items: suppliersFiltered
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(s.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setSt(() => selectedSupplierId = v),
                    ),
                    const SizedBox(height: 16),

                    // 2. Item mode selector (Blocks vs Meters) + item inputs
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            '2. أصناف الفاتورة (أضف كل صنف بزر +):',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'الأصناف المضافة: ${draftItems.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Switcher between Blocks purchase item and Meters purchase item
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setSt(() {
                                itemMode = 'block';
                                formError = null;
                              }),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: itemMode == 'block'
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: itemMode == 'block'
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.05,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.view_in_ar_rounded,
                                      size: 18,
                                      color: itemMode == 'block'
                                          ? AppColors.accentPrimary
                                          : AppColors.brandSecondaryText,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'بند شراء بلوكات (Blocks)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: itemMode == 'block'
                                              ? AppColors.accentPrimary
                                              : AppColors.brandSecondaryText,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setSt(() {
                                itemMode = 'meter';
                                formError = null;
                              }),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: itemMode == 'meter'
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: itemMode == 'meter'
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.05,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.straighten_rounded,
                                      size: 18,
                                      color: itemMode == 'meter'
                                          ? AppColors.accentPrimary
                                          : AppColors.brandSecondaryText,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'بند شراء أمتار (Meters)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: itemMode == 'meter'
                                              ? AppColors.accentPrimary
                                              : AppColors.brandSecondaryText,
                                        ),
                                        overflow: TextOverflow.ellipsis,
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
                    const SizedBox(height: 12),

                    if (itemMode == 'block') ...[
                      // Blocks purchase item form
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'بحث نوع البلوك والدرجة...',
                                prefixIcon: Icon(Icons.search),
                                isDense: true,
                              ),
                              onChanged: (v) =>
                                  setSt(() => blockSearch = v.trim()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => refreshAfterAdd(
                              () => _showAddBlockTypeDialog(erp),
                            ),
                            icon: const Icon(Icons.add_box_outlined, size: 18),
                            label: const Text('نوع بلوك جديد +'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: blockValue,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'نوع البلوك حسب النوع والدرجة',
                        ),
                        items: optionsFiltered
                            .map(
                              (b) => DropdownMenuItem(
                                value: '${b.typeName}||${b.grade}',
                                child: Text('${b.typeName} • ${b.grade}'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setSt(() => selectedBlockKey = v),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: tonsCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'عدد الأطنان لهذا النوع والدرجة',
                              ),
                              onChanged: (_) => setSt(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: priceCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText:
                                    'سعر الوحدة (سعر الطن ${AppCurrency.symbol(invCurrency)})',
                              ),
                              onChanged: (_) => setSt(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.chipBgBlue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'الإجمالي: ${draftBlockTotal.fmt} ${AppCurrency.symbol(invCurrency)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accentPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (selectedSupplierId == null) {
                              setSt(
                                () => formError =
                                    'اختر المورد أولاً قبل إضافة الأصناف.',
                              );
                              return;
                            }
                            if (selectedBlockKey == null) {
                              setSt(
                                () => formError = 'اختر نوع البلوك والدرجة.',
                              );
                              return;
                            }
                            if (draftTons <= 0 || draftPrice < 0) {
                              setSt(
                                () => formError =
                                    'أدخل عدد أطنان صحيح وسعر وحدة صحيح.',
                              );
                              return;
                            }
                            final parts = selectedBlockKey!.split('||');
                            final bt = erp.blockTypes.firstWhere(
                              (b) =>
                                  b.typeName == parts[0] &&
                                  b.grade == parts[1],
                              orElse: () => erp.blockTypes.first,
                            );
                            setSt(() {
                              formError = null;
                              draftItems.add(
                                FactoryInvoiceItem(
                                  itemId:
                                      'draft_b_${DateTime.now().millisecondsSinceEpoch}_${draftItems.length}',
                                  description: '${parts[0]} (${parts[1]})',
                                  typeName: parts[0],
                                  grade: parts.length > 1 ? parts[1] : '',
                                  quantity: draftTons,
                                  unitPrice: draftPrice,
                                  unitCost: draftPrice,
                                  isGranite: bt.isGranite,
                                  itemCategory: 'block',
                                ),
                              );
                              tonsCtrl.clear();
                              priceCtrl.clear();
                              selectedBlockKey = null;
                            });
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('إضافة بند البلوك للفاتورة +'),
                        ),
                      ),
                    ] else ...[
                      // Meters purchase item form
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'بحث نوع المتر أو السماكة...',
                                prefixIcon: Icon(Icons.search),
                                isDense: true,
                              ),
                              onChanged: (v) =>
                                  setSt(() => meterSearch = v.trim()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => refreshAfterAdd(
                              () => _showUnifiedItemTypeDialog(erp),
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('نوع مادة جديد +'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: meterValue,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText:
                              'نوع المتر (النوع • الدرجة • السماكة • الفئة)',
                        ),
                        items: meterOptionsFiltered
                            .map(
                              (m) => DropdownMenuItem(
                                value: m.id,
                                child: Text(
                                  '${m.typeName} • ${m.grade} • ${m.thicknessCm.fmt} سم • ${m.category} ${m.isGranite ? "(غرانيت)" : "(رخام)"}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          setSt(() {
                            selectedMeterTypeId = v;
                            if (v != null) {
                              final mt = erp.meterTypes.firstWhere(
                                (m) => m.id == v,
                                orElse: () => erp.meterTypes.first,
                              );
                              selectedMeterUnit = mt.category.isNotEmpty
                                  ? mt.category
                                  : 'متر مربع';
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          const Text(
                            'وحدة القياس: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          ChoiceChip(
                            label: const Text('متر مربع (م²)'),
                            selected: selectedMeterUnit == 'متر مربع',
                            onSelected: (v) {
                              if (v) {
                                setSt(() => selectedMeterUnit = 'متر مربع');
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('متر طولي (م.ط)'),
                            selected: selectedMeterUnit == 'متر طولي',
                            onSelected: (v) {
                              if (v) {
                                setSt(() => selectedMeterUnit = 'متر طولي');
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('متر مكعب (م³)'),
                            selected: selectedMeterUnit == 'متر مكعب',
                            onSelected: (v) {
                              if (v) {
                                setSt(() => selectedMeterUnit = 'متر مكعب');
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
                              controller: meterQtyCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText:
                                    'إجمالي الأمتار المربعة / الطولية ($selectedMeterUnit)',
                              ),
                              onChanged: (v) {
                                final q = double.tryParse(v) ?? 0.0;
                                final p =
                                    double.tryParse(meterPriceCtrl.text) ?? 0.0;
                                if (p > 0) {
                                  meterTotalCostCtrl.text = (q * p).fmt;
                                }
                                setSt(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: meterPriceCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText:
                                    'سعر الوحدة للمتر (${AppCurrency.symbol(invCurrency)})',
                              ),
                              onChanged: (v) {
                                final p = double.tryParse(v) ?? 0.0;
                                final q =
                                    double.tryParse(meterQtyCtrl.text) ?? 0.0;
                                meterTotalCostCtrl.text = (q * p).fmt;
                                setSt(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: meterTotalCostCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText:
                                    'إجمالي التكلفة (${AppCurrency.symbol(invCurrency)})',
                              ),
                              onChanged: (v) {
                                final t = double.tryParse(v) ?? 0.0;
                                final q =
                                    double.tryParse(meterQtyCtrl.text) ?? 0.0;
                                if (q > 0) {
                                  meterPriceCtrl.text = (t / q).fmt;
                                }
                                setSt(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (selectedSupplierId == null) {
                              setSt(
                                () => formError =
                                    'اختر المورد أولاً قبل إضافة الأصناف.',
                              );
                              return;
                            }
                            if (selectedMeterTypeId == null) {
                              setSt(() => formError = 'اختر نوع المتر.');
                              return;
                            }
                            final double q =
                                double.tryParse(meterQtyCtrl.text) ?? 0.0;
                            var p =
                                double.tryParse(meterPriceCtrl.text) ?? 0.0;
                            final t =
                                double.tryParse(meterTotalCostCtrl.text) ?? 0.0;
                            if (p <= 0 && t > 0 && q > 0) {
                              p = t / q;
                            }
                            if (q <= 0 || p < 0) {
                              setSt(
                                () => formError =
                                    'أدخل إجمالي أمتار صحيح وسعر وحدة صحيح.',
                              );
                              return;
                            }
                            final mt = erp.meterTypes.firstWhere(
                              (m) => m.id == selectedMeterTypeId,
                              orElse: () => erp.meterTypes.first,
                            );
                            setSt(() {
                              formError = null;
                              draftItems.add(
                                FactoryInvoiceItem(
                                  itemId: mt.id,
                                  description:
                                      '${mt.typeName} (${mt.grade}) ${mt.thicknessCm.fmt}سم - $selectedMeterUnit',
                                  typeName: mt.typeName,
                                  grade: mt.grade,
                                  thicknessCm: mt.thicknessCm,
                                  quantity: q,
                                  unitPrice: p,
                                  unitCost: p,
                                  isGranite: mt.isGranite,
                                  itemCategory: 'meter',
                                  meterUnit: selectedMeterUnit,
                                ),
                              );
                              meterQtyCtrl.clear();
                              meterPriceCtrl.clear();
                              meterTotalCostCtrl.clear();
                              selectedMeterTypeId = null;
                            });
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('إضافة بند الأمتار للفاتورة +'),
                        ),
                      ),
                    ],
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
                    if (draftItems.isEmpty)
                      const Text(
                        'لم تتم إضافة أصناف بعد.',
                        style: TextStyle(color: AppColors.brandSecondaryText),
                      ),
                    ...draftItems.asMap().entries.map(
                      (e) {
                        final it = e.value;
                        final isMeter = it.isMeterItem;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isMeter
                                    ? AppColors.chipBgBlue
                                    : AppColors.chipBgAmber,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isMeter ? 'أمتار' : 'بلوك',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isMeter
                                      ? AppColors.accentPrimary
                                      : AppColors.partnersEquityAccent,
                                ),
                              ),
                            ),
                            title: Text(
                              it.description,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              isMeter
                                  ? '${it.quantity.fmt} ${it.meterUnit} × ${it.unitPrice.fmt}${AppCurrency.symbol(invCurrency)} = ${(it.quantity * it.unitPrice).fmt}${AppCurrency.symbol(invCurrency)}'
                                  : '${it.quantity.fmt} طن × ${it.unitPrice.fmt}${AppCurrency.symbol(invCurrency)} = ${(it.quantity * it.unitPrice).fmt}${AppCurrency.symbol(invCurrency)}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.dangerWaste,
                              ),
                              onPressed: () =>
                                  setSt(() => draftItems.removeAt(e.key)),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // 3. Shipment question.
                    const Text(
                      '3. هل وصلت هذه الشحنة أم لا؟',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        yesNoOption(
                          'نعم وصلت',
                          true,
                          isDelivered,
                          (v) => setSt(() => isDelivered = v),
                        ),
                        yesNoOption(
                          'لا لم تصل',
                          false,
                          isDelivered,
                          (v) => setSt(() => isDelivered = v),
                        ),
                      ],
                    ),
                    if (isDelivered == false) ...[
                      TextField(
                        controller: shippingFeeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText:
                              'تكاليف الشحن (تُدمج مع رأس مال المواد وتُسجل في المصروفات)',
                        ),
                        onChanged: (_) => setSt(() {}),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'ملاحظة: تكاليف الشحن تُوزّع على التكلفة الرأسمالية للمواد المشتراة وتُسجَّل في صفحة المصروفات كقيد إعلامي، ولا تُحمَّل على حساب المورد أو إجمالي هذه الفاتورة.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.accentPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // 4. Totals + payment question.
                    CurrencySelector(
                      value: invCurrency,
                      dense: true,
                      onChanged: (v) => setSt(() => invCurrency = v),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: discountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'الخصم المكتسب من المورد (اختياري)',
                      ),
                      onChanged: (_) => setSt(() {}),
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
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('إجمالي الفاتورة المستحق للمورد:'),
                              Row(
                                children: [
                                  Text(
                                    '${grandTotal.fmt} ${AppCurrency.symbol(invCurrency)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  CurrencyBadge(currency: invCurrency),
                                ],
                              ),
                            ],
                          ),
                          if (shipping > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'تكاليف الشحن (مرسملة على المواد ومسجلة بالمصروفات):',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.brandSecondaryText,
                                  ),
                                ),
                                Text(
                                  '${shipping.fmt} ${AppCurrency.symbol(invCurrency)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.accentPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                              ),
                              onPressed: () {
                                final currentNet = grandTotal;
                                final truncated = currentNet.truncateToDouble();
                                final diff = currentNet - truncated;
                                if (diff > 0.0001) {
                                  final curDisc =
                                      double.tryParse(discountCtrl.text) ??
                                      0.0;
                                  discountCtrl.text = (curDisc + diff).fmt;
                                  if (cashInvoice) {
                                    downPayCtrl.text = truncated.fmt;
                                  }
                                  setSt(() {});
                                }
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
                          ),
                          const SizedBox(height: 8),
                          if (cashInvoice)
                            Text(
                              'فاتورة نقدية: سيتم دفع كامل مستحقات المورد (${grandTotal.fmt} ${AppCurrency.symbol(invCurrency)}) من الصندوق الرئيسي.',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.accentPrimary,
                              ),
                            )
                          else ...[
                            const Text(
                              'هل نريد الدفع له أم لا؟',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Row(
                              children: [
                                yesNoOption(
                                  'نعم',
                                  true,
                                  wantsPay,
                                  (v) => setSt(() => wantsPay = v),
                                ),
                                yesNoOption(
                                  'لا',
                                  false,
                                  wantsPay,
                                  (v) => setSt(() => wantsPay = v),
                                ),
                              ],
                            ),
                          ],
                          if (!cashInvoice && wantsPay == true)
                            TextField(
                              controller: downPayCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'الدفعة المقدمة (تُخصم من الإجمالي)',
                              ),
                              onChanged: (_) => setSt(() {}),
                            ),
                          if (!cashInvoice && wantsPay == true) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('المتبقي بعد الدفعة:'),
                                Text(
                                  '${(grandTotal - downPay).clamp(0.0, double.infinity).fmt} ${AppCurrency.symbol(invCurrency)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.dangerWaste,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppImageAttachmentPicker(
                      initialPath: photoPath,
                      label: 'صورة فاتورة الشراء من المورد / وصل الاستلام',
                      onImageChanged: (p) => setSt(() => photoPath = p),
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: () {
                        if (selectedSupplierId == null) {
                          setSt(() => formError = 'اختر المورد.');
                          return;
                        }
                        if (draftItems.isEmpty) {
                          setSt(
                            () =>
                                formError = 'أضف صنفاً واحداً على الأقل بزر +.',
                          );
                          return;
                        }
                        if (isDelivered == null) {
                          setSt(() => formError = 'أجب: هل وصلت الشحنة أم لا؟');
                          return;
                        }
                        if (discount < 0 || discount > itemsTotal) {
                          setSt(
                            () => formError =
                                'قيمة الخصم يجب أن تكون بين صفر وإجمالي الفاتورة.',
                          );
                          return;
                        }
                        if (!cashInvoice && wantsPay == null) {
                          setSt(
                            () => formError = 'أجب: هل نريد الدفع له أم لا؟',
                          );
                          return;
                        }
                        double advance = cashInvoice
                            ? grandTotal
                            : wantsPay == true
                            ? (double.tryParse(downPayCtrl.text) ?? 0.0)
                            : 0.0;
                        if (advance < 0) advance = 0.0;
                        if (advance > grandTotal) advance = grandTotal;
                        if (cashInvoice &&
                            erp.cashOf('main', invCurrency) + 0.0001 <
                                grandTotal) {
                          setSt(
                            () => formError =
                                'رصيد الصندوق الرئيسي غير كافٍ لتسديد الفاتورة النقدية بهذه العملة.',
                          );
                          return;
                        }

                        final sup = erp.suppliers.firstWhere(
                          (s) => s.id == selectedSupplierId,
                          orElse: () => erp.suppliers.first,
                        );
                        final created = erp.addSupplierPurchaseInvoice(
                          FactoryInvoiceModel(
                            id: 'fi_${DateTime.now().millisecondsSinceEpoch}',
                            invoiceNo:
                                'FAC-PUR-${erp.factoryInvoices.length + 101}',
                            date: DateTime.now(),
                            partyId: sup.id,
                            partyName: sup.name,
                            invoiceType: 'شراء_مورد',
                            items: List.of(draftItems),
                            isGoodsDelivered: isDelivered == true,
                            shippingFee: shipping,
                            advancePayment: advance,
                            discountAmount: discount,
                            isCashInvoice: cashInvoice,
                            photoUrl: photoPath,
                            currency: invCurrency,
                          ),
                        );
                        if (!created) {
                          setSt(
                            () => formError =
                                'تعذر اعتماد الفاتورة. تحقق من رصيد الصندوق الرئيسي وتسديد كامل الإجمالي.',
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              cashInvoice
                                  ? 'تم حفظ فاتورة الشراء النقدية وتسديدها بالكامل من الصندوق.'
                                  : advance >= grandTotal - 0.01
                                  ? 'تم حفظ الفاتورة مدفوعة بالكامل وتسجيلها في المالية وقسم المدفوعة.'
                                  : 'تم حفظ الفاتورة وتسجيلها في المالية وقسم مستحق الدفع.',
                            ),
                            backgroundColor: AppColors.successGreen,
                          ),
                        );
                      },
                      child: const Text('اعتماد وحفظ الفاتورة'),
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

  void _showEditFactoryDraftItemModal({
    required BuildContext context,
    required FactoryInvoiceItem item,
    required ERPProvider erp,
    required void Function(FactoryInvoiceItem updatedItem) onSave,
  }) {
    String editMeterUnit = item.meterUnit;
    final descCtrl = TextEditingController(text: item.description);
    final lenCtrl = TextEditingController(text: item.lengthCm > 0 ? item.lengthCm.fmt : '');
    final widCtrl = TextEditingController(text: item.widthCm > 0 ? item.widthCm.fmt : '');
    final heiCtrl = TextEditingController(
      text: item.heightCm > 0
          ? item.heightCm.fmt
          : (item.thicknessCm > 0 ? item.thicknessCm.fmt : ''),
    );
    final qtyCtrl = TextEditingController(text: item.quantity.fmt);
    final unitPriceCtrl = TextEditingController(text: item.unitPrice.fmt);

    double lookupPredefinedThickness() {
      final whMatches = erp.factoryWarehouse.where((w) => w.id == item.itemId).toList();
      if (whMatches.isNotEmpty) return whMatches.first.thicknessCm;
      final typeMatches = erp.factoryWarehouse.where((w) => w.typeName == item.typeName).toList();
      if (typeMatches.isNotEmpty) return typeMatches.first.thicknessCm;
      return item.thicknessCm > 0 ? item.thicknessCm : (item.heightCm > 0 ? item.heightCm : 2.0);
    }

    double lookupCubicPrice() {
      final whMatches = erp.factoryWarehouse.where((w) => w.id == item.itemId).toList();
      if (whMatches.isNotEmpty) {
        final wh = whMatches.first;
        if (wh.category == 'متر مكعب' && wh.recommendedSalePrice > 0) return wh.recommendedSalePrice;
        final cMatches = erp.factoryWarehouse.where((w) => w.typeName.trim() == wh.typeName.trim() && w.category == 'متر مكعب' && w.recommendedSalePrice > 0).toList();
        if (cMatches.isNotEmpty) return cMatches.first.recommendedSalePrice;
        return wh.recommendedSalePrice;
      }
      final typeMatches = erp.factoryWarehouse.where((w) => w.typeName.trim() == item.typeName.trim() && w.category == 'متر مكعب' && w.recommendedSalePrice > 0).toList();
      if (typeMatches.isNotEmpty) return typeMatches.first.recommendedSalePrice;
      return item.unitPrice;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final bool isCube = editMeterUnit == 'متر مكعب';
          final double l = double.tryParse(lenCtrl.text) ?? 0.0;
          final double w = double.tryParse(widCtrl.text) ?? 0.0;
          final double h = double.tryParse(heiCtrl.text) ?? 0.0;
          final double q = double.tryParse(qtyCtrl.text) ?? 0.0;
          final double up = double.tryParse(unitPriceCtrl.text) ?? 0.0;

          final double calculatedVolumeOrArea = isCube
              ? ((l > 0 && w > 0 && h > 0 && q > 0) ? (l / 100.0) * (w / 100.0) * (h / 100.0) * q : 0.0)
              : ((l > 0 && w > 0 && q > 0) ? (l / 100.0) * (w / 100.0) * q : q);
          final double lineTotal = calculatedVolumeOrArea * up;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 540,
              padding: const EdgeInsets.all(20),
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
                        const Text('وحدة القياس / البيع:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(width: 12),
                        ChoiceChip(
                          label: const Text('متر مربع (م²)'),
                          selected: editMeterUnit == 'متر مربع',
                          onSelected: (sel) {
                            if (sel) {
                              setSt(() {
                                editMeterUnit = 'متر مربع';
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('متر مكعب (م³)'),
                          selected: editMeterUnit == 'متر مكعب',
                          selectedColor: const Color(0xFFDCFCE7),
                          onSelected: (sel) {
                            if (sel) {
                              setSt(() {
                                editMeterUnit = 'متر مكعب';
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
                      decoration: const InputDecoration(labelText: 'وصف البند', isDense: true),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: lenCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'الطول (سم)', isDense: true),
                            onChanged: (_) => setSt(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: widCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'العرض (سم)', isDense: true),
                            onChanged: (_) => setSt(() {}),
                          ),
                        ),
                        if (isCube) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: heiCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'الارتفاع = السماكة (سم)', isDense: true),
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
                            controller: qtyCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'الكمية (العدد)', isDense: true),
                            onChanged: (_) => setSt(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: unitPriceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'سعر بيع المتر (${isCube ? "م³" : "م²"} \$)',
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
                                'الأمتار المحسوبة: ${calculatedVolumeOrArea.fmt} ${isCube ? "م³" : "م²"}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF166534)),
                              ),
                              if (isCube)
                                Text(
                                  'الحجم = ${(l/100).fmt}م × ${(w/100).fmt}م × ${(h/100).fmt}م × ${q.fmt} قطع',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                                ),
                            ],
                          ),
                          Text(
                            'الإجمالي: ${lineTotal.fmt} \$',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF15803D)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
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
                          ),
                          onPressed: () {
                            final updated = item.copyWith(
                              description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : item.description,
                              lengthCm: l,
                              widthCm: w,
                              heightCm: isCube ? h : 0.0,
                              quantity: q,
                              unitPrice: up,
                              meterUnit: editMeterUnit,
                              thicknessCm: isCube && h > 0 ? h : item.thicknessCm,
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

  void _showAddPOSInvoiceDialog(
    ERPProvider erp, {
    bool cashInvoice = false,
    FactoryOrderModel? initialOrder,
  }) {
    final approvedClients = erp.clients
        .where((c) => c.clientType == 'معتمد مصنع')
        .toList();
    if (approvedClients.isEmpty || erp.factoryWarehouse.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.info_outline_rounded, color: AppColors.dangerWaste),
              SizedBox(width: 8),
              Expanded(child: Text('لا يمكن إضافة فاتورة مصنع')),
            ],
          ),
          content: Text(
            'يجب توفر بيانات أساسية أولاً:\n'
            '${approvedClients.isEmpty ? "• معتمد مصنع واحد على الأقل (شاشة الأشخاص)\n" : ""}'
            '${erp.factoryWarehouse.isEmpty ? "• بضاعة واحدة على الأقل في مستودع المصنع\n" : ""}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
            if (approvedClients.isEmpty)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showAddClientDialog(erp);
                },
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('إضافة معتمد الآن'),
              ),
          ],
        ),
      );
      return;
    }

    FactoryOrderModel? assignedOrder = initialOrder;

    // Multi-item approved-client invoice builder (Factory Warehouse goods).
    String? selectedClientId;
    if (initialOrder != null) {
      final match = approvedClients
          .where(
            (c) =>
                c.id == initialOrder.partyId ||
                c.name == initialOrder.clientName,
          )
          .toList();
      if (match.isNotEmpty) selectedClientId = match.first.id;
    }
    String clientSearch = '';
    String? selectedWhId;
    String goodsSearch = '';
    final lengthCtrl = TextEditingController();
    final widthCtrl = TextEditingController();
    final heightCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final unitPriceCtrl = TextEditingController();
    final downPayCtrl = TextEditingController(
      text: (initialOrder != null && initialOrder.depositAmount > 0)
          ? initialOrder.depositAmount.fmt
          : '',
    );
    final salesDiscountCtrl = TextEditingController(
      text: (initialOrder != null && initialOrder.discountAmount > 0)
          ? initialOrder.discountAmount.fmt
          : '0',
    );
    final shippingCtrl = TextEditingController(
      text: (initialOrder != null && initialOrder.shippingFee > 0)
          ? initialOrder.shippingFee.fmt
          : '',
    );
    final photoCtrl = TextEditingController(
      text: initialOrder?.photoPath ?? '',
    );
    bool? deliverByUs = initialOrder?.isGoodsDelivered;
    String? formError;

    final List<FactoryInvoiceItem> draftItems = initialOrder != null
        ? List.of(initialOrder.items)
        : [];

    // Services attached to the item currently being built.
    String? selectedServiceId;
    String serviceSearch = '';
    final servicePriceCtrl = TextEditingController();
    final serviceNotesCtrl = TextEditingController();
    final List<ServiceAttachment> draftServices = [];
    String posCurrency = initialOrder?.currency ?? AppCurrency.usd;
    String selectedItemMeterUnit = 'متر مربع';

    double getFactoryCubicSellingPrice(FactoryWarehouseModel item) {
      if (item.category == 'متر مكعب' && item.recommendedSalePrice > 0) {
        return item.recommendedSalePrice;
      }
      final matches = erp.factoryWarehouse.where(
        (w) => w.typeName.trim() == item.typeName.trim() && w.category == 'متر مكعب' && w.recommendedSalePrice > 0,
      ).toList();
      if (matches.isNotEmpty) {
        return matches.first.recommendedSalePrice;
      }
      return item.recommendedSalePrice;
    }

    double draftArea(
      FactoryWarehouseModel? wh,
      double l,
      double w,
      double h,
      double q,
      bool isCube,
    ) {
      if (wh == null || l <= 0 || w <= 0 || q <= 0) return 0.0;
      if (isCube) {
        if (h <= 0) return 0.0;
        return (l / 100.0) * (w / 100.0) * (h / 100.0) * q;
      }
      return (l / 100.0) * (w / 100.0) * q;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final clientsFiltered = approvedClients
              .where(
                (c) => clientSearch.isEmpty || c.name.contains(clientSearch),
              )
              .toList();
          final clientValue =
              clientsFiltered.any((c) => c.id == selectedClientId)
              ? selectedClientId
              : null;

          final goodsFiltered = erp.factoryWarehouse
              .where(
                (w) =>
                    goodsSearch.isEmpty ||
                    '${w.typeName} ${w.grade} ${w.thicknessCm}'.contains(
                      goodsSearch,
                    ),
              )
              .toList();
          final goodsValue = goodsFiltered.any((w) => w.id == selectedWhId)
              ? selectedWhId
              : null;
          final matches = erp.factoryWarehouse
              .where((w) => w.id == selectedWhId)
              .toList();
          final FactoryWarehouseModel? wh = matches.isEmpty
              ? null
              : matches.first;
          final bool isCube = selectedItemMeterUnit == 'متر مكعب' || wh?.category == 'متر مكعب';

          // Auto-populate price per meter and height from Factory Warehouse interface if empty
          if (wh != null) {
            if (isCube) {
              if (heightCtrl.text.isEmpty && wh.thicknessCm > 0) {
                heightCtrl.text = wh.thicknessCm.fmt;
              }
              if (unitPriceCtrl.text.isEmpty) {
                final cp = getFactoryCubicSellingPrice(wh);
                if (cp > 0) unitPriceCtrl.text = cp.fmt;
              }
            } else {
              if (unitPriceCtrl.text.isEmpty && wh.recommendedSalePrice > 0) {
                unitPriceCtrl.text = wh.recommendedSalePrice.fmt;
              }
            }
          }

          final double l = double.tryParse(lengthCtrl.text) ?? 0.0;
          final double w = double.tryParse(widthCtrl.text) ?? 0.0;
          final double h = double.tryParse(heightCtrl.text) ?? 0.0;
          final double q = double.tryParse(qtyCtrl.text) ?? 0.0;
          final double price = double.tryParse(unitPriceCtrl.text) ?? 0.0;
          final double area = draftArea(wh, l, w, h, q, isCube);
          final double draftTotal = area * price;
          final double draftServicesTotal = draftServices.fold(
            0.0,
            (s, sv) => s + sv.price,
          );

          void autoCalcServicePrice() {
            if (selectedServiceId == null) return;
            final srvMatches = erp.services.where((s) => s.id == selectedServiceId).toList();
            if (srvMatches.isEmpty) return;
            final srv = srvMatches.first;

            final rawL = double.tryParse(lengthCtrl.text) ?? 0.0;
            final double curLenM = rawL > 0 ? (rawL / 100.0) : 0.0;
            final double curQty = double.tryParse(qtyCtrl.text) ?? 0.0;

            if (curLenM > 0 && curQty > 0) {
              final double calc = curLenM * curQty * srv.unitRate;
              servicePriceCtrl.text = calc.toStringAsFixed(2);
              serviceNotesCtrl.text = 'طول ${curLenM.fmt}م × ${curQty.fmt} قطع × ${srv.unitRate.fmt}\$';
            } else if (curQty > 0) {
              final double calc = curQty * srv.unitRate;
              servicePriceCtrl.text = calc.toStringAsFixed(2);
              serviceNotesCtrl.text = '${curQty.fmt} قطع × ${srv.unitRate.fmt}\$';
            } else {
              servicePriceCtrl.text = srv.unitRate.toStringAsFixed(2);
              serviceNotesCtrl.text = 'سعر الوحدة: ${srv.unitRate.fmt}\$';
            }
          }

          final double itemsTotal = draftItems.fold(
            0.0,
            (s, it) => s + it.totalPrice,
          );
          final double itemsServicesTotal = draftItems.fold(
            0.0,
            (s, it) => s + it.servicesTotal,
          );
          final double shipping = (deliverByUs == true)
              ? (double.tryParse(shippingCtrl.text) ?? 0.0)
              : 0.0;
          final double salesDiscount =
              double.tryParse(salesDiscountCtrl.text) ?? 0.0;
          final double grandTotal =
              (itemsTotal + itemsServicesTotal + shipping - salesDiscount)
                  .clamp(0.0, double.infinity);
          final double downPay = double.tryParse(downPayCtrl.text) ?? 0.0;

          final servicesFiltered = erp.services
              .where(
                (s) => serviceSearch.isEmpty || s.name.contains(serviceSearch),
              )
              .toList();
          final serviceValue =
              servicesFiltered.any((s) => s.id == selectedServiceId)
              ? selectedServiceId
              : null;

          Future<void> refreshAfterAdd(Future<void> Function() opener) async {
            await opener();
            setSt(() {});
          }

          double draftedFor(String whId) => draftItems
              .where((it) => it.itemId == whId)
              .fold(0.0, (s, it) => s + it.calculatedArea);

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
                      'إنشاء فاتورة مصنع لمعتمد',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontSize: 18),
                    ),
                    const Divider(height: 20),

                    // Factory Order Assignment Section
                    Builder(builder: (context) {
                      final pendingOrders = erp.factoryOrders
                          .where((o) => o.status == 'قيد التنفيذ')
                          .toList();

                      if (assignedOrder != null) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF93C5FD)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.link_rounded,
                                          color: Color(0xFF2563EB), size: 22),
                                      const SizedBox(width: 8),
                                      Text(
                                        'تم إسناد طلبية المصنع: ${assignedOrder!.orderNo} للزبون ${assignedOrder!.clientName}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E40AF),
                                        ),
                                      ),
                                    ],
                                  ),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.dangerWaste,
                                    ),
                                    onPressed: () {
                                      setSt(() {
                                        assignedOrder = null;
                                      });
                                    },
                                    icon: const Icon(
                                      Icons.link_off_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('إلغاء الربط بالطلبية'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Text(
                                    'العربون المحجوز في صندوق الطلبيات المعزول: ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF1E3A8A),
                                    ),
                                  ),
                                  Text(
                                    '${assignedOrder!.depositAmount.fmt} ${assignedOrder!.currencySymbol}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppColors.orderDepositBoxAccent,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '• تم استيراد أصناف الطلبية أدناه، ولك كامل الحرية في تعديل المقاسات، والأسعار، أو حذف وإضافة بنود وخدمات.\n'
                                '• عند حفظ الفاتورة، سيتم تحويل العربون تلقائياً إلى الصندوق الرئيسي وتحديث حالة الطلبية إلى "مكتملة ومرحلة".',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF3B82F6),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        );
                      } else if (pendingOrders.isNotEmpty) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.panelBorder),
                          ),
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText:
                                  '📥 إسناد من طلبية مصنع معلقة (اختياري)',
                              prefixIcon: Icon(
                                Icons.file_download_outlined,
                                color: AppColors.orderDepositBoxAccent,
                              ),
                              isDense: true,
                              border: InputBorder.none,
                            ),
                            items: pendingOrders
                                .map((ord) => DropdownMenuItem(
                                      value: ord.id,
                                      child: Text(
                                        '${ord.orderNo} • ${ord.clientName} (${ord.totalArea.fmt} م) • عربون: ${ord.depositAmount.fmt} ${ord.currencySymbol}',
                                      ),
                                    ))
                                .toList(),
                            onChanged: (ordId) {
                              if (ordId == null) return;
                              final ord = pendingOrders
                                  .firstWhere((o) => o.id == ordId);
                              setSt(() {
                                assignedOrder = ord;
                                final matchClient = approvedClients
                                    .where(
                                      (c) =>
                                          c.id == ord.partyId ||
                                          c.name == ord.clientName,
                                    )
                                    .toList();
                                if (matchClient.isNotEmpty) {
                                  selectedClientId = matchClient.first.id;
                                }
                                posCurrency = ord.currency;
                                draftItems.clear();
                                draftItems.addAll(ord.items);
                                deliverByUs = ord.isGoodsDelivered;
                                if (ord.shippingFee > 0) {
                                  shippingCtrl.text = ord.shippingFee.fmt;
                                }
                                if (ord.discountAmount > 0) {
                                  salesDiscountCtrl.text =
                                      ord.discountAmount.fmt;
                                }
                                downPayCtrl.text = ord.depositAmount > 0
                                    ? ord.depositAmount.fmt
                                    : '';
                                if (ord.photoPath.isNotEmpty) {
                                  photoCtrl.text = ord.photoPath;
                                }
                              });
                            },
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }),

                    // 1. Approved client searchable + inline add.
                    const Text(
                      '1. المعتمد (قائمة قابلة للبحث):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'بحث عن معتمد...',
                              prefixIcon: Icon(Icons.search),
                              isDense: true,
                            ),
                            onChanged: (v) =>
                                setSt(() => clientSearch = v.trim()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () =>
                              refreshAfterAdd(() => _showAddClientDialog(erp)),
                          icon: const Icon(Icons.person_add_alt_1, size: 18),
                          label: const Text('معتمد جديد +'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: clientValue,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'المعتمد'),
                      items: clientsFiltered
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setSt(() => selectedClientId = v),
                    ),
                    const SizedBox(height: 16),

                    // 2. Factory Warehouse Goods (بضاعة مستودع المصنع).
                    const Text(
                      '2. أصناف بضاعة مستودع المصنع (بزر +):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'بحث صنف المستودع (النوع والدرجة)...',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                        ),
                        onChanged: (v) => setSt(() => goodsSearch = v.trim()),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: goodsValue,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'نوع البضاعة حسب مستودع المصنع',
                        ),
                        items: goodsFiltered
                            .map(
                              (g) => DropdownMenuItem(
                                value: g.id,
                                child: Text(
                                  '${g.typeName} ${g.grade} ${g.thicknessCm}سم (${g.category}) — المتاح: ${g.availableQty} — سعر بيع المتر: ${g.recommendedSalePrice.fmt} \$',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          setSt(() {
                            selectedWhId = v;
                            if (v != null) {
                              final mList = erp.factoryWarehouse.where((g) => g.id == v).toList();
                              if (mList.isNotEmpty) {
                                final selWh = mList.first;
                                selectedItemMeterUnit = selWh.category == 'متر مكعب' ? 'متر مكعب' : 'متر مربع';
                                if (selectedItemMeterUnit == 'متر مكعب') {
                                  heightCtrl.text = selWh.thicknessCm.fmt;
                                  final cp = getFactoryCubicSellingPrice(selWh);
                                  unitPriceCtrl.text = cp > 0 ? cp.fmt : (selWh.recommendedSalePrice > 0 ? selWh.recommendedSalePrice.fmt : '');
                                } else {
                                  heightCtrl.clear();
                                  if (selWh.recommendedSalePrice > 0) {
                                    unitPriceCtrl.text = selWh.recommendedSalePrice.fmt;
                                  }
                                }
                              }
                            }
                            autoCalcServicePrice();
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      if (wh == null)
                        const Text(
                          'اختر الصنف أولاً.',
                          style: TextStyle(color: AppColors.brandSecondaryText),
                        ),
                      if (wh != null) ...[
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
                                    selectedItemMeterUnit = 'متر مربع';
                                    heightCtrl.clear();
                                    if (wh.recommendedSalePrice > 0) {
                                      unitPriceCtrl.text = wh.recommendedSalePrice.fmt;
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
                                    selectedItemMeterUnit = 'متر مكعب';
                                    heightCtrl.text = wh.thicknessCm.fmt;
                                    final cp = getFactoryCubicSellingPrice(wh);
                                    if (cp > 0) unitPriceCtrl.text = cp.fmt;
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
                                controller: lengthCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'الطول (سم)',
                                ),
                                onChanged: (_) {
                                  autoCalcServicePrice();
                                  setSt(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: widthCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'العرض (سم)',
                                ),
                                onChanged: (_) => setSt(() {}),
                              ),
                            ),
                            if (isCube) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: heightCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'الارتفاع = السماكة (سم)',
                                    helperText: 'سماكة المادة: ${wh.thicknessCm.fmt} سم',
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
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'الكمية (العدد)',
                                ),
                                onChanged: (_) {
                                  autoCalcServicePrice();
                                  setSt(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: unitPriceCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'سعر بيع المتر (${isCube ? "م³" : "م²"} \$)',
                                  helperText: isCube
                                      ? 'سعر المتر المكعب للمادة: ${getFactoryCubicSellingPrice(wh).fmt} \$'
                                      : (wh.recommendedSalePrice > 0
                                          ? 'سعر المستودع: ${wh.recommendedSalePrice.fmt} \$'
                                          : null),
                                ),
                                onChanged: (_) => setSt(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.chipBgBlue,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'إجمالي قيمة البضاعة:',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${draftTotal.fmt} \$',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppColors.accentPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Prominently display calculated number of meters before adding the line item
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.straighten_rounded, color: Color(0xFF15803D), size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'إجمالي عدد الأمتار المحسوبة للبند:',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF166534),
                                          ),
                                        ),
                                        Text(
                                          '${area.fmt} ${isCube ? "متر مكعب (م³)" : "متر مربع (م²)"}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF15803D),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      (l > 0 && w > 0 && q > 0)
                                          ? 'طريقة الحساب: (الطول ${(l / 100.0).fmt}م × العرض ${(w / 100.0).fmt}م ${isCube ? "× الارتفاع ${(h / 100.0).fmt}م " : ""}× العدد ${q.fmt} قطع) = ${area.fmt} ${isCube ? "م³" : "م²"}'
                                          : 'أدخل الطول والعرض والعدد لاحتساب إجمالي الأمتار تلقائياً قبل إضافة الصنف',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: (l > 0 && w > 0 && q > 0) ? const Color(0xFF166534) : const Color(0xFF64748B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Attach services to warehouse item
                        _buildServicesAttachmentSection(
                          setSt: setSt,
                          erp: erp,
                          serviceSearch: serviceSearch,
                          onSearchChanged: (v) => setSt(() => serviceSearch = v),
                          serviceValue: serviceValue,
                          servicesFiltered: servicesFiltered,
                          onServiceChanged: (v) {
                            setSt(() {
                              selectedServiceId = v;
                              autoCalcServicePrice();
                            });
                          },
                          servicePriceCtrl: servicePriceCtrl,
                          serviceNotesCtrl: serviceNotesCtrl,
                          selectedServiceId: selectedServiceId,
                          draftServices: draftServices,
                          draftServicesTotal: draftServicesTotal,
                          curLengthM: l > 0 ? (l / 100.0) : 0.0,
                          curQuantity: q,
                          onError: (err) => setSt(() => formError = err),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (selectedClientId == null) {
                                setSt(() => formError = 'اختر المعتمد أولاً.');
                                return;
                              }
                              if (area <= 0) {
                                setSt(
                                  () => formError = 'أدخل أبعاداً وكمية صحيحة.',
                                );
                                return;
                              }
                              if (price < 0) {
                                setSt(() => formError = 'أدخل سعر وحدة صحيح.');
                                return;
                              }
                              final available =
                                  wh.availableQty - draftedFor(wh.id);
                              if (area > available + 0.0001) {
                                setSt(
                                  () => formError =
                                      'الكمية تتجاوز المتاح في المستودع (${available.fmt}).',
                                );
                                return;
                              }
                              setSt(() {
                                formError = null;
                                draftItems.add(
                                  FactoryInvoiceItem(
                                    itemId: wh.id,
                                    description:
                                        '${wh.typeName} ${wh.grade} ${wh.thicknessCm}سم',
                                    typeName: wh.typeName,
                                    grade: wh.grade,
                                    lengthCm: l,
                                    widthCm: w,
                                    heightCm: isCube ? h : 0.0,
                                    quantity: q,
                                    unitPrice: price,
                                    unitCost: wh.netCostPerUnit,
                                    isGranite: wh.isGranite,
                                    services: List.of(draftServices),
                                    thicknessCm: wh.thicknessCm,
                                    meterUnit: isCube ? 'متر مكعب' : 'متر مربع',
                                  ),
                                );
                                draftServices.clear();
                                lengthCtrl.clear();
                                widthCtrl.clear();
                                heightCtrl.clear();
                                qtyCtrl.clear();
                                unitPriceCtrl.clear();
                                selectedWhId = null;
                              });
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة الصنف للفاتورة +'),
                          ),
                        ),
                      ],
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
                    if (draftItems.isEmpty)
                      const Text(
                        'لم تتم إضافة أصناف بعد.',
                        style: TextStyle(color: AppColors.brandSecondaryText),
                      ),
                    ...draftItems.asMap().entries.map(
                      (e) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ExpansionTile(
                          title: Text(
                            e.value.description,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            '${e.value.calculatedArea.fmt} ${e.value.meterUnit == "متر مكعب" || e.value.heightCm > 0 ? "م³" : "م²"} × ${e.value.unitPrice}\$ + خدمات ${e.value.servicesTotal.fmt}\$ = ${e.value.grandTotal.fmt}\$',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: AppColors.accentPrimary,
                                ),
                                onPressed: () {
                                  _showEditFactoryDraftItemModal(
                                    context: context,
                                    item: e.value,
                                    erp: erp,
                                    onSave: (updated) => setSt(() {
                                      draftItems[e.key] = updated;
                                    }),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.dangerWaste,
                                ),
                                onPressed: () =>
                                    setSt(() => draftItems.removeAt(e.key)),
                              ),
                            ],
                          ),
                          children: [
                            ...e.value.services.map(
                              (s) => ListTile(
                                dense: true,
                                title: Text(s.serviceName),
                                subtitle: Text(s.notes.isEmpty ? '—' : s.notes),
                                trailing: Text(
                                  '${s.price}\$',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 4. Totals, down payment, delivery, photo.
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
                          CurrencySelector(
                            value: posCurrency,
                            dense: true,
                            onChanged: (v) => setSt(() => posCurrency = v),
                          ),
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
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('إجمالي الفاتورة (أصناف + خدمات):'),
                              Row(
                                children: [
                                  Text(
                                    '${grandTotal.fmt} ${AppCurrency.symbol(posCurrency)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  CurrencyBadge(currency: posCurrency),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                              ),
                              onPressed: () {
                                final currentNet = grandTotal;
                                final truncated = currentNet.truncateToDouble();
                                final diff = currentNet - truncated;
                                if (diff > 0.0001) {
                                  final newDisc = salesDiscount + diff;
                                  salesDiscountCtrl.text = newDisc.fmt;
                                  if (cashInvoice) {
                                    downPayCtrl.text = truncated.fmt;
                                  }
                                  setSt(() {});
                                }
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
                          ),
                          const SizedBox(height: 8),
                          if (cashInvoice)
                            Text(
                              'فاتورة بيع نقدية: سيتم تحصيل كامل الإجمالي إلى الصندوق الرئيسي.',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.accentPrimary,
                              ),
                            )
                          else
                            TextField(
                              controller: downPayCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'الدفعة الأولى / المقدمة (إن وجدت)',
                                isDense: true,
                              ),
                              onChanged: (_) => setSt(() {}),
                            ),
                          if (!cashInvoice && downPayCtrl.text.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'المتبقي: ${(grandTotal - downPay).clamp(0.0, double.infinity).fmt} \$',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.dangerWaste,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          const Text(
                            'خيار التوصيل:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setSt(() => deliverByUs = false),
                                  child: Row(
                                    children: [
                                      Radio<bool>(
                                        value: false,
                                        groupValue: deliverByUs,
                                        onChanged: (v) =>
                                            setSt(() => deliverByUs = v),
                                      ),
                                      const Text('الزبون يستلم النقل'),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setSt(() => deliverByUs = true),
                                  child: Row(
                                    children: [
                                      Radio<bool>(
                                        value: true,
                                        groupValue: deliverByUs,
                                        onChanged: (v) =>
                                            setSt(() => deliverByUs = v),
                                      ),
                                      const Text('نوصّل نحن'),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (deliverByUs == true)
                            TextField(
                              controller: shippingCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'تكلفة التوصيل / الشحن (\$)',
                                isDense: true,
                              ),
                              onChanged: (_) => setSt(() {}),
                            ),
                          const SizedBox(height: 12),
                          AppImageAttachmentPicker(
                            initialPath: photoCtrl.text,
                            label: 'صورة الفاتورة / إشعار الاستلام',
                            onImageChanged: (p) =>
                                setSt(() => photoCtrl.text = p),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentPrimary,
                      ),
                      onPressed: () {
                        if (selectedClientId == null) {
                          setSt(() => formError = 'اختر المعتمد.');
                          return;
                        }
                        if (draftItems.isEmpty) {
                          setSt(
                            () =>
                                formError = 'أضف صنفاً واحداً على الأقل بزر +.',
                          );
                          return;
                        }
                        if (deliverByUs == null) {
                          setSt(() => formError = 'اختر خيار التوصيل.');
                          return;
                        }
                        if (salesDiscount < 0 ||
                            salesDiscount >
                                itemsTotal + itemsServicesTotal + shipping) {
                          setSt(
                            () => formError =
                                'قيمة خصم المبيعات يجب أن تكون بين صفر وإجمالي الفاتورة.',
                          );
                          return;
                        }
                        double advance = cashInvoice
                            ? grandTotal
                            : (double.tryParse(downPayCtrl.text) ?? 0.0);
                        if (advance < 0) advance = 0.0;
                        if (advance > grandTotal) {
                          advance = grandTotal;
                        }
                        final client = erp.clients.firstWhere(
                          (c) => c.id == selectedClientId,
                          orElse: () => erp.clients.first,
                        );
                        final newInvoice = FactoryInvoiceModel(
                          id: 'fi_pos_${DateTime.now().millisecondsSinceEpoch}',
                          invoiceNo:
                              'FAC-POS-${erp.factoryInvoices.length + 101}',
                          date: DateTime.now(),
                          partyId: client.id,
                          partyName: client.name,
                          invoiceType: 'بيع_معتمد',
                          items: List.of(draftItems),
                          isGoodsDelivered: deliverByUs == true,
                          shippingFee: shipping,
                          advancePayment: advance,
                          discountAmount: salesDiscount,
                          isCashInvoice: cashInvoice,
                          photoUrl: photoCtrl.text.trim(),
                          currency: posCurrency,
                        );
                        final created = assignedOrder != null
                            ? erp.assignFactoryOrderToPOSInvoice(
                                assignedOrder!,
                                newInvoice,
                              )
                            : erp.addFactoryPOSInvoice(newInvoice);
                        if (!created) {
                          setSt(
                            () => formError =
                                'تعذر اعتماد الفاتورة النقدية؛ تحقق من تسديد كامل الإجمالي.',
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              assignedOrder != null
                                  ? 'تم حفظ الفاتورة وإسناد طلبية المصنع (${assignedOrder!.orderNo}) ونقل العربون إلى الصندوق الرئيسي بنجاح.'
                                  : cashInvoice
                                      ? 'تم إصدار فاتورة البيع النقدية وتحصيلها بالكامل في الصندوق الرئيسي.'
                                      : advance >= grandTotal - 0.01
                                          ? 'تم حفظ الفاتورة مدفوعة بالكامل وتسجيلها في قسم المدفوعة.'
                                          : 'تم حفظ الفاتورة وتسجيلها في قسم التحصيل المعلق.',
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

  Widget _buildServicesAttachmentSection({
    required StateSetter setSt,
    required ERPProvider erp,
    required String serviceSearch,
    required ValueChanged<String> onSearchChanged,
    required String? serviceValue,
    required List<ServiceItemModel> servicesFiltered,
    required ValueChanged<String?> onServiceChanged,
    required TextEditingController servicePriceCtrl,
    required TextEditingController serviceNotesCtrl,
    required String? selectedServiceId,
    required List<ServiceAttachment> draftServices,
    required double draftServicesTotal,
    required double curLengthM,
    required double curQuantity,
    required ValueChanged<String> onError,
  }) {
    final ServiceItemModel? selectedSrv = (selectedServiceId != null &&
            erp.services.any((s) => s.id == selectedServiceId))
        ? erp.services.firstWhere((s) => s.id == selectedServiceId)
        : null;

    return Container(
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
            children: const [
              Text(
                'خدمات ملحقة بهذا الصنف (من شاشة الخدمات):',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
              Text(
                'المعادلة: (الطول × العدد × سعر الخدمة)',
                style: TextStyle(
                  fontSize: 10.5,
                  color: AppColors.accentPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              labelText: 'بحث خدمة...',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) => onSearchChanged(v.trim()),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: serviceValue,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'اختر الخدمة المطلوبة',
              isDense: true,
            ),
            items: servicesFiltered
                .map(
                  (s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(
                      '${s.name} (${s.unitRate}\$ للمتر)',
                    ),
                  ),
                )
                .toList(),
            onChanged: onServiceChanged,
          ),
          if (selectedSrv != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'سعر الخدمة للمتر: ${selectedSrv.unitRate.fmt} \$',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                      if (curLengthM > 0 && curQuantity > 0)
                        Text(
                          'إجمالي الخدمة المحسوب: ${(curLengthM * curQuantity * selectedSrv.unitRate).fmt} \$',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    (curLengthM > 0 && curQuantity > 0)
                        ? 'معادلة الحساب: (الطول ${curLengthM.fmt}م × العدد ${curQuantity.fmt} قطعة × سعر الخدمة ${selectedSrv.unitRate.fmt}\$) = ${(curLengthM * curQuantity * selectedSrv.unitRate).fmt} \$'
                        : 'أدخل الطول والكمية بالصنف ليتم احتساب إجمالي سعر الخدمة تلقائياً',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: (curLengthM > 0 && curQuantity > 0)
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: servicePriceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'سعر الخدمة الإجمالي (\$)',
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
                    labelText: 'وصف أو تفاصيل حساب الخدمة',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  if (selectedServiceId == null) {
                    onError('اختر الخدمة أولاً.');
                    return;
                  }
                  final price =
                      double.tryParse(servicePriceCtrl.text) ?? 0.0;
                  if (price <= 0) {
                    onError('أدخل سعر الخدمة أو تأكد من إدخال الطول والكمية.');
                    return;
                  }
                  final srv = erp.services.firstWhere(
                    (s) => s.id == selectedServiceId,
                  );
                  final autoFormula = (curLengthM > 0 && curQuantity > 0)
                      ? 'طول ${curLengthM.fmt}م × ${curQuantity.fmt} قطع × ${srv.unitRate.fmt}\$'
                      : '';
                  final userNote = serviceNotesCtrl.text.trim();
                  final finalNote = userNote.isNotEmpty
                      ? (userNote.contains('طول') ? userNote : (autoFormula.isNotEmpty ? '$autoFormula • $userNote' : userNote))
                      : autoFormula;

                  setSt(() {
                    draftServices.add(
                      ServiceAttachment(
                        serviceName: srv.name,
                        price: price,
                        notes: finalNote,
                      ),
                    );
                    servicePriceCtrl.clear();
                    serviceNotesCtrl.clear();
                  });
                },
                child: const Text('إرفاق +'),
              ),
            ],
          ),
          if (draftServices.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...draftServices.asMap().entries.map(
              (e) => Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• ${e.value.serviceName}: ${e.value.price.fmt} \$',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          if (e.value.notes.isNotEmpty)
                            Text(
                              'تفاصيل الحساب: ${e.value.notes}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
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
            ),
            const SizedBox(height: 4),
            Text(
              'إجمالي خدمات الصنف: ${draftServicesTotal.fmt} \$',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ],
      ),
    );
  }

}
