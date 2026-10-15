import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';
import '../widgets/currency_selector.dart';
import '../widgets/thermal_receipt_dialog.dart';
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
                                    'المورد ${b.supplierName} — ${b.weightTons.fmt} طن — سعر الطن ${b.tonCost.fmt}\$',
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

          OpeningStockItemsPanel(
            items: erp.openingEntry.openingStock,
            category: 'بلوكات خام المصنع',
          ),

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
                // Tab 1: m² Warehouse
                Column(
                  children: [
                    Expanded(
                      child: _buildWarehouseGrid(
                        erp.factoryWarehouse
                            .where((w) => w.category == 'متر مربع')
                            .toList(),
                        isM2: true,
                      ),
                    ),
                    OpeningStockItemsPanel(
                      items: erp.openingEntry.openingStock,
                      category: 'أمتار المصنع',
                    ),
                  ],
                ),
                // Tab 2: m³ Warehouse
                Column(
                  children: [
                    Expanded(
                      child: _buildWarehouseGrid(
                        erp.factoryWarehouse
                            .where((w) => w.category == 'متر مكعب')
                            .toList(),
                        isM2: false,
                      ),
                    ),
                    OpeningStockItemsPanel(
                      items: erp.openingEntry.openingStock,
                      category: 'أمتار المصنع',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarehouseGrid(
    List<FactoryWarehouseModel> items, {
    required bool isM2,
  }) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.6,
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
                      '${item.availableQty} ${isM2 ? "م²" : "م³"}',
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
              ],
            ),
          ),
        );
      },
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
              const Text(
                'تعريف أنواع البلوكات والأمتار المربعة والتكعيبية',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddBlockTypeDialog(erp),
                icon: const Icon(Icons.add),
                label: const Text('إضافة نوع صنف جديد'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: erp.blockTypes.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final bt = erp.blockTypes[idx];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: bt.isGranite
                        ? AppColors.chipBgBlue
                        : AppColors.chipBgAmber,
                    child: Icon(
                      bt.isGranite ? Icons.grid_on : Icons.view_comfy,
                      color: bt.isGranite
                          ? AppColors.accentPrimary
                          : AppColors.partnersEquityAccent,
                    ),
                  ),
                  title: Text(
                    bt.typeName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'الدرجة: ${bt.grade} • النوع الخامي: ${bt.isGranite ? "غرانيت مستورد" : "رخام محلي/مستورد"}',
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'أنواع الأمتار والمقاسات المتاحة في المستودع',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              FilledButton.icon(
                onPressed: () => _showAddMeterTypeDialog(erp),
                icon: const Icon(Icons.add),
                label: const Text('إضافة نوع متر'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: erp.meterTypes.isEmpty
                ? const ListTile(title: Text('لا توجد أنواع أمتار معرفة.'))
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: erp.meterTypes.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final type = erp.meterTypes[index];
                      return ListTile(
                        leading: const Icon(Icons.straighten),
                        title: Text(
                          '${type.typeName} • ${type.grade}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${type.thicknessCm.fmt} سم • ${type.category} • ${type.isGranite ? 'غرانيت' : 'رخام'}',
                        ),
                        trailing: IconButton(
                          tooltip: 'تعديل نوع المتر',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () =>
                              _showAddMeterTypeDialog(erp, existing: type),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddMeterTypeDialog(
    ERPProvider erp, {
    MeterTypeModel? existing,
  }) async {
    final nameController = TextEditingController(
      text: existing?.typeName ?? '',
    );
    final gradeController = TextEditingController(
      text: existing?.grade ?? 'درجة أولى',
    );
    final thicknessController = TextEditingController(
      text: existing?.thicknessCm.fmt ?? '2',
    );
    var isGranite = existing?.isGranite ?? false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'إضافة نوع متر' : 'تعديل نوع متر'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'اسم النوع'),
                ),
                TextField(
                  controller: gradeController,
                  decoration: const InputDecoration(labelText: 'الدرجة'),
                ),
                TextField(
                  controller: thicknessController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'السماكة (سم)'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('غرانيت'),
                  value: isGranite,
                  onChanged: (value) =>
                      setDialogState(() => isGranite = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final thickness = double.tryParse(thicknessController.text);
                if (nameController.text.trim().isEmpty ||
                    gradeController.text.trim().isEmpty ||
                    thickness == null ||
                    thickness <= 0) {
                  return;
                }
                final type = MeterTypeModel(
                  id: existing?.id ??
                      'meter_${DateTime.now().microsecondsSinceEpoch}',
                  typeName: nameController.text.trim(),
                  grade: gradeController.text.trim(),
                  thicknessCm: thickness,
                  category: thickness <= 5 ? 'متر مربع' : 'متر مكعب',
                  isGranite: isGranite,
                );
                if (existing == null) {
                  erp.addMeterType(type);
                } else {
                  erp.updateMeterType(type);
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    gradeController.dispose();
    thicknessController.dispose();
    if (saved == true && mounted) setState(() {});
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
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: inv.isDue ? AppColors.chipBgRed : AppColors.chipBgGreen,
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
            children: [
              ...inv.items.map(
                (it) => ListTile(
                  dense: true,
                  title: Text(
                    '${it.typeName.isNotEmpty ? it.typeName : it.description} ${it.grade}',
                  ),
                  subtitle: Text(
                    '${it.quantity} طن × ${it.unitPrice}${inv.currencySymbol} = ${(it.quantity * it.unitPrice).fmt}${inv.currencySymbol}',
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
                  child: Row(
                    children: [
                      const Icon(Icons.attach_file_rounded, size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text(inv.photoUrl)),
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
  // SUB-TAB 9: FACTORY CUSTOM ORDERS (In Progress -> Completed on assign)
  // -------------------------------------------------------------
  Widget _buildSubTab9FactoryOrders(ERPProvider erp) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'طلبيات المصنع (Factory Orders)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'الطلبية "قيد التنفيذ" وحين إسنادها لفاتورة تصبح "مكتملة". العربون في صندوق الطلبيات المعزول.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.orderDepositBoxAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orderDepositBoxAccent,
                ),
                onPressed: () => _showAddFactoryOrderDialog(erp),
                icon: const Icon(Icons.post_add_rounded),
                label: const Text('إضافة طلبية مصنع'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: erp.factoryOrders.isEmpty
                  ? const Center(child: Text('لا توجد طلبيات مصنع بعد.'))
                  : ListView.separated(
                      itemCount: erp.factoryOrders.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final ord = erp.factoryOrders[idx];
                        return ListTile(
                          title: Text(
                            '${ord.orderNo} • الزبون: ${ord.clientName}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'الصنف: ${ord.itemDescription} • السعر: ${ord.agreedPrice}\$ • العربون: ${ord.depositAmount}\$${ord.photoPath.isEmpty ? "" : " • مرفق صورة"}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (ord.status == 'قيد التنفيذ') ...[
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.successGreen,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                  ),
                                  onPressed: () =>
                                      _showAssignFactoryOrderDialog(erp, ord),
                                  child: const Text('إسناد لفاتورة'),
                                ),
                                const SizedBox(width: 6),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.dangerWaste,
                                  ),
                                  onPressed: () =>
                                      _showCancelFactoryOrderDialog(erp, ord),
                                  child: const Text('إلغاء'),
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

  void _showAddFactoryOrderDialog(ERPProvider erp) {
    if (erp.factoryWarehouse.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('مستودع المصنع فارغ. انقل ناتج قص أولاً.'),
          backgroundColor: AppColors.dangerWaste,
        ),
      );
      return;
    }
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String? selectedWhId;
    String goodsSearch = '';
    final lenCtrl = TextEditingController();
    final widCtrl = TextEditingController();
    final heiCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final depositCtrl = TextEditingController();
    final photoCtrl = TextEditingController();
    String? formError;
    String orderCurrency = AppCurrency.usd;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final goodsFiltered = erp.factoryWarehouse
              .where(
                (w) =>
                    goodsSearch.isEmpty ||
                    '${w.typeName} ${w.grade}'.contains(goodsSearch),
              )
              .toList();
          final goodsValue = goodsFiltered.any((w) => w.id == selectedWhId)
              ? selectedWhId
              : null;
          final m = erp.factoryWarehouse
              .where((w) => w.id == selectedWhId)
              .toList();
          final wh = m.isEmpty ? null : m.first;
          final bool isCube = wh?.category == 'متر مكعب';
          final double l = double.tryParse(lenCtrl.text) ?? 0.0;
          final double w = double.tryParse(widCtrl.text) ?? 0.0;
          final double h = double.tryParse(heiCtrl.text) ?? 0.0;
          final double q = double.tryParse(qtyCtrl.text) ?? 0.0;
          final double price = double.tryParse(priceCtrl.text) ?? 0.0;
          double area = 0.0;
          if (wh != null && l > 0 && w > 0 && q > 0) {
            area = isCube && h > 0
                ? (l / 100.0) * (w / 100.0) * (h / 100.0) * q
                : (l / 100.0) * (w / 100.0) * q;
          }

          return Dialog(
            child: Container(
              width: 620,
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'إضافة طلبية مصنع (قيد التنفيذ)',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontSize: 18),
                    ),
                    const Divider(height: 20),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اسم الزبون',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'بحث صنف المستودع...',
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
                        labelText: 'الصنف من المستودع',
                      ),
                      items: goodsFiltered
                          .map(
                            (g) => DropdownMenuItem(
                              value: g.id,
                              child: Text(
                                '${g.typeName} ${g.grade} ${g.thicknessCm}سم — المتاح: ${g.availableQty}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setSt(() => selectedWhId = v),
                    ),
                    if (wh != null) ...[
                      const SizedBox(height: 8),
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
                          if (isCube) ...[
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
                              onChanged: (_) => setSt(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'الإجمالي: ${(area * price).fmt} \$ • المتاح: ${wh.availableQty}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                    const SizedBox(height: 8),
                    CurrencySelector(
                      value: orderCurrency,
                      dense: true,
                      onChanged: (v) => setSt(() => orderCurrency = v),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: depositCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'العربون (صندوق الطلبيات)',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: photoCtrl,
                            decoration: const InputDecoration(
                              labelText: 'صورة الطلبية (مسار — اختياري)',
                              prefixIcon: Icon(Icons.attach_file_rounded),
                              isDense: true,
                            ),
                          ),
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
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orderDepositBoxAccent,
                      ),
                      onPressed: () {
                        if (nameCtrl.text.isEmpty) {
                          setSt(() => formError = 'أدخل اسم الزبون.');
                          return;
                        }
                        if (wh == null || area <= 0) {
                          setSt(
                            () => formError = 'اختر الصنف وأدخل أبعاداً صحيحة.',
                          );
                          return;
                        }
                        if (area > wh.availableQty + 0.0001) {
                          setSt(() => formError = 'الكمية تتجاوز المتاح.');
                          return;
                        }
                        final deposit =
                            double.tryParse(depositCtrl.text) ?? 0.0;
                        erp.createFactoryOrder(
                          FactoryOrderModel(
                            id: 'fo_${DateTime.now().millisecondsSinceEpoch}',
                            orderNo: 'FORD-${erp.factoryOrders.length + 101}',
                            date: DateTime.now(),
                            clientName: nameCtrl.text,
                            clientPhone: phoneCtrl.text,
                            warehouseItemId: wh.id,
                            itemDescription:
                                '${wh.typeName} ${wh.grade} ${wh.thicknessCm}سم',
                            lengthCm: l,
                            widthCm: w,
                            heightCm: isCube ? h : 0.0,
                            quantity: q,
                            unitPrice: price,
                            agreedPrice: area * price,
                            depositAmount: deposit,
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
          );
        },
      ),
    );
  }

  void _showAssignFactoryOrderDialog(ERPProvider erp, FactoryOrderModel ord) {
    final cashCtrl = TextEditingController(
      text: (ord.agreedPrice - ord.depositAmount)
          .clamp(0.0, double.infinity)
          .fmt,
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إسناد الطلبية لفاتورة (مكتملة)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${ord.orderNo} • ${ord.clientName} • الإجمالي ${ord.agreedPrice}\$ • العربون ${ord.depositAmount}\$',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cashCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'النقد المدفوع الآن (\$)',
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.successGreen,
            ),
            onPressed: () {
              final cash = double.tryParse(cashCtrl.text) ?? 0.0;
              erp.assignFactoryOrderToInvoice(ord, cash);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'تم إسناد الطلبية لفاتورة ونقل العربون للصندوق الرئيسي!',
                  ),
                  backgroundColor: AppColors.successGreen,
                ),
              );
            },
            child: const Text('تأكيد الإسناد'),
          ),
        ],
      ),
    );
  }

  void _showCancelFactoryOrderDialog(ERPProvider erp, FactoryOrderModel ord) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء طلبية المصنع'),
        content: const Text(
          'العربون غير قابل للاسترداد إلا في الحالات الخاصة.',
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
              erp.cancelFactoryOrder(ord, false);
              Navigator.pop(ctx);
            },
            child: const Text('إلغاء مع الاحتفاظ بالعربون'),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.dangerWaste,
            ),
            onPressed: () {
              erp.cancelFactoryOrder(ord, true);
              Navigator.pop(ctx);
            },
            child: const Text('إلغاء مع رد العربون (خاص)'),
          ),
        ],
      ),
    );
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
    final nameCtrl = TextEditingController();
    bool isGranite = false;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('إضافة نوع صنف جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'اسم الصنف (مثال: رخام كاردينال)',
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('هل هو غرانيت؟ (يخضع لأرباح المحاسب 50%)'),
                value: isGranite,
                onChanged: (v) => setSt(() => isGranite = v),
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
                  erp.addBlockType(
                    BlockTypeModel(
                      id: 'bt_${DateTime.now().millisecondsSinceEpoch}',
                      typeName: nameCtrl.text,
                      grade: 'درجة أولى',
                      isGranite: isGranite,
                    ),
                  );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSupplierInvoiceDialog(
    ERPProvider erp, {
    bool cashInvoice = false,
  }) {
    if (erp.suppliers.isEmpty || erp.blockTypes.isEmpty) {
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
            '${erp.blockTypes.isEmpty ? "• نوع بلوك واحد على الأقل\n" : ""}',
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
            if (erp.blockTypes.isEmpty)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showAddBlockTypeDialog(erp);
                },
                icon: const Icon(Icons.add_box_outlined),
                label: const Text('إضافة نوع بلوك'),
              ),
          ],
        ),
      );
      return;
    }
    // Full multi-item purchase invoice builder (exact spec):
    // searchable supplier (+ inline add) -> item fields + -> shipment Q ->
    // totals -> payment Q -> save to Due/Paid + Supplier Finances.
    String? selectedSupplierId;
    String supplierSearch = '';
    String? selectedBlockKey; // '<typeName>||<grade>'
    String blockSearch = '';
    final tonsCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final shippingFeeCtrl = TextEditingController();
    final downPayCtrl = TextEditingController();
    final discountCtrl = TextEditingController(text: '0');
    bool? isDelivered;
    bool? wantsPay;
    final List<FactoryInvoiceItem> draftItems = [];
    String? formError;
    String invCurrency = AppCurrency.usd;

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

          final double draftTons = double.tryParse(tonsCtrl.text) ?? 0.0;
          final double draftPrice = double.tryParse(priceCtrl.text) ?? 0.0;
          final double draftTotal = draftTons * draftPrice;

          final double itemsTotal = draftItems.fold(
            0.0,
            (s, it) => s + (it.quantity * it.unitPrice),
          );
          final double shipping = (isDelivered == false)
              ? (double.tryParse(shippingFeeCtrl.text) ?? 0.0)
              : 0.0;
          final double discount = double.tryParse(discountCtrl.text) ?? 0.0;
          final double grandTotal = (itemsTotal + shipping - discount).clamp(
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
              width: 720,
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'إنشاء فاتورة شراء من مورد',
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

                    // 2. Item fields + add.
                    const Text(
                      '2. أصناف الفاتورة (أضف كل صنف بزر +):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'بحث نوع البلوك والدرجة...',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                      onChanged: (v) => setSt(() => blockSearch = v.trim()),
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
                            keyboardType: TextInputType.number,
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
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'سعر الوحدة (سعر الطن \$)',
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
                              'الإجمالي: ${draftTotal.fmt} \$',
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
                            setSt(() => formError = 'اختر نوع البلوك والدرجة.');
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
                                b.typeName == parts[0] && b.grade == parts[1],
                            orElse: () => erp.blockTypes.first,
                          );
                          setSt(() {
                            formError = null;
                            draftItems.add(
                              FactoryInvoiceItem(
                                itemId:
                                    'draft_${DateTime.now().millisecondsSinceEpoch}_${draftItems.length}',
                                description: '${parts[0]} (${parts[1]})',
                                typeName: parts[0],
                                grade: parts.length > 1 ? parts[1] : '',
                                quantity: draftTons,
                                unitPrice: draftPrice,
                                unitCost: draftPrice,
                                isGranite: bt.isGranite,
                              ),
                            );
                            tonsCtrl.clear();
                            priceCtrl.clear();
                            selectedBlockKey = null;
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة الصنف للفاتورة +'),
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
                    if (draftItems.isEmpty)
                      const Text(
                        'لم تتم إضافة أصناف بعد.',
                        style: TextStyle(color: AppColors.brandSecondaryText),
                      ),
                    ...draftItems.asMap().entries.map(
                      (e) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(
                            e.value.description,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${e.value.quantity} طن × ${e.value.unitPrice}\$ = ${(e.value.quantity * e.value.unitPrice).fmt}\$',
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
                      ),
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
                              'تكاليف الشحن (تُدمج مع رأس مال الأحجار وتُوزع على الأصناف)',
                        ),
                        onChanged: (_) => setSt(() {}),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'تُجمع تكاليف الشحن مع إجمالي الفاتورة وتُوزع على التكلفة الرأسمالية لكل صنف.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.brandSecondaryText,
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
                              const Text('إجمالي الفاتورة:'),
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
                          const SizedBox(height: 8),
                          if (cashInvoice)
                            Text(
                              'فاتورة نقدية: سيتم دفع كامل الإجمالي (${grandTotal.fmt} ${AppCurrency.symbol(invCurrency)}) من الصندوق الرئيسي.',
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
                                  '${(grandTotal - downPay).clamp(0.0, double.infinity).fmt} \$',
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
                        if (discount < 0 || discount > itemsTotal + shipping) {
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

  void _showAddPOSInvoiceDialog(
    ERPProvider erp, {
    bool cashInvoice = false,
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
            '${erp.factoryWarehouse.isEmpty ? "• صنف واحد على الأقل في مستودع الألواح\n" : ""}',
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

    // Multi-item approved-client invoice builder (exact spec).
    String? selectedClientId;
    String clientSearch = '';
    String? selectedWhId;
    String goodsSearch = '';
    final lengthCtrl = TextEditingController();
    final widthCtrl = TextEditingController();
    final heightCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final unitPriceCtrl = TextEditingController();
    final downPayCtrl = TextEditingController();
    final salesDiscountCtrl = TextEditingController(text: '0');
    final shippingCtrl = TextEditingController();
    final photoCtrl = TextEditingController();
    bool? deliverByUs;
    String? formError;

    final List<FactoryInvoiceItem> draftItems = [];

    // Services attached to the item currently being built.
    String? selectedServiceId;
    String serviceSearch = '';
    final servicePriceCtrl = TextEditingController();
    final serviceNotesCtrl = TextEditingController();
    final List<ServiceAttachment> draftServices = [];
    String posCurrency = AppCurrency.usd;

    double draftArea(
      FactoryWarehouseModel? wh,
      double l,
      double w,
      double h,
      double q,
    ) {
      if (wh == null || l <= 0 || w <= 0 || q <= 0) return 0.0;
      if (wh.category == 'متر مكعب') {
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
          final bool isCube = wh?.category == 'متر مكعب';

          final double l = double.tryParse(lengthCtrl.text) ?? 0.0;
          final double w = double.tryParse(widthCtrl.text) ?? 0.0;
          final double h = double.tryParse(heightCtrl.text) ?? 0.0;
          final double q = double.tryParse(qtyCtrl.text) ?? 0.0;
          final double price = double.tryParse(unitPriceCtrl.text) ?? 0.0;
          final double area = draftArea(wh, l, w, h, q);
          final double draftTotal = area * price;
          final double draftServicesTotal = draftServices.fold(
            0.0,
            (s, sv) => s + sv.price,
          );

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

                    // 2. Goods line-item fields.
                    const Text(
                      '2. أصناف الفاتورة (بزر +):',
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
                                '${g.typeName} ${g.grade} ${g.thicknessCm}سم (${g.category}) — المتاح: ${g.availableQty}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setSt(() => selectedWhId = v),
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
                          Expanded(
                            child: TextField(
                              controller: lengthCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'الطول (سم)',
                              ),
                              onChanged: (_) => setSt(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: widthCtrl,
                              keyboardType: TextInputType.number,
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
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'الارتفاع (سم) لحساب الحجم',
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
                              ),
                              onChanged: (_) => setSt(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: unitPriceCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'سعر الوحدة للمتر (مربع/مكعب \$)',
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
                                'الإجمالي: ${draftTotal.fmt} \$',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accentPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 3. Attach services to this line item.
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
                              'خدمات ملحقة بهذا الصنف (من شاشة الخدمات):',
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
                                      child: Text(
                                        '${s.name} (${s.unitRate}\$)',
                                      ),
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
                                      labelText: 'وصف تفصيلي للخدمة',
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    if (selectedServiceId == null) {
                                      setSt(
                                        () => formError = 'اختر الخدمة أولاً.',
                                      );
                                      return;
                                    }
                                    final price =
                                        double.tryParse(
                                          servicePriceCtrl.text,
                                        ) ??
                                        0.0;
                                    if (price <= 0) {
                                      setSt(
                                        () => formError = 'أدخل سعر الخدمة.',
                                      );
                                      return;
                                    }
                                    final srv = erp.services.firstWhere(
                                      (s) => s.id == selectedServiceId,
                                    );
                                    setSt(() {
                                      formError = null;
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
                            if (draftServices.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              ...draftServices.asMap().entries.map(
                                (e) => Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '• ${e.value.serviceName}: ${e.value.price}\$ ${e.value.notes}',
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
                              Text(
                                'إجمالي خدمات الصنف: ${draftServicesTotal.fmt} \$',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
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
                            '${e.value.calculatedArea.fmt} ${e.value.heightCm > 5 ? "م³" : "م²"} × ${e.value.unitPrice}\$ + خدمات ${e.value.servicesTotal.fmt}\$ = ${e.value.grandTotal.fmt}\$',
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.dangerWaste,
                            ),
                            onPressed: () =>
                                setSt(() => draftItems.removeAt(e.key)),
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
                          const SizedBox(height: 8),
                          TextField(
                            controller: photoCtrl,
                            decoration: const InputDecoration(
                              labelText: 'إرفاق صورة (مسار أو رابط — اختياري)',
                              prefixIcon: Icon(Icons.attach_file_rounded),
                              isDense: true,
                            ),
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
                        final created = erp.addFactoryPOSInvoice(
                          FactoryInvoiceModel(
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
                          ),
                        );
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
                              cashInvoice
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
}
