import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';

/// One thickness conversion draft inside a type plan.
class _CutDraft {
  double tons;
  double thicknessCm;
  double factor;
  double feePercent;
  final TextEditingController metersCtrl;

  _CutDraft({
    required this.tons,
    required this.thicknessCm,
    required this.factor,
    required this.feePercent,
    required double meters,
  }) : metersCtrl = TextEditingController(text: meters.fmt);

  void dispose() => metersCtrl.dispose();
}

/// Working plan for a single aggregated type+grade coming from inventory.
class _TypePlan {
  final CuttingBatchInput batch;
  final List<_CutDraft> conversions = [];
  String convOptionId = '3cm';
  double thicknessCm = 3.0;
  double feePercent = 0.08;
  final TextEditingController tonsCtrl;
  final TextEditingController factorCtrl;
  final TextEditingController thickCtrl;
  final TextEditingController metersCtrl;

  _TypePlan(this.batch)
      : tonsCtrl = TextEditingController(),
        factorCtrl = TextEditingController(text: '5.5'),
        thickCtrl = TextEditingController(text: '3'),
        metersCtrl = TextEditingController();

  void dispose() {
    tonsCtrl.dispose();
    factorCtrl.dispose();
    thickCtrl.dispose();
    metersCtrl.dispose();
    for (final c in conversions) {
      c.dispose();
    }
  }
}

class CuttingCalculatorScreen extends StatefulWidget {
  const CuttingCalculatorScreen({super.key});

  @override
  State<CuttingCalculatorScreen> createState() => _CuttingCalculatorScreenState();
}

class _CuttingCalculatorScreenState extends State<CuttingCalculatorScreen> {
  List<_TypePlan> _plans = [];
  String? _loadedKey;
  final TextEditingController _wasteCtrl =
      TextEditingController(text: '45');

  @override
  void dispose() {
    _wasteCtrl.dispose();
    for (final p in _plans) {
      p.dispose();
    }
    super.dispose();
  }

  static const Map<String, Map<String, dynamic>> _convOptions = {
    '2cm': {'label': 'سماكة 2 سم (1 طن = 8 م²)', 'thickness': 2.0, 'factor': 8.0, 'm3': false},
    '3cm': {'label': 'سماكة 3 سم (1 طن = 5.5 م²)', 'thickness': 3.0, 'factor': 5.5, 'm3': false},
    '4cm': {'label': 'سماكة 4 سم (1 طن = 3.5 م²)', 'thickness': 4.0, 'factor': 3.5, 'm3': false},
    '5cm': {'label': 'سماكة 5 سم (1 طن = 3.5 م²)', 'thickness': 5.0, 'factor': 3.5, 'm3': false},
    'cube': {'label': 'سماكة > 5 سم (تحويل م³ — علاقة مخصصة)', 'thickness': 10.0, 'factor': 0.45, 'm3': true},
  };

  void _applyOption(_TypePlan plan, String optionId) {
    final opt = _convOptions[optionId]!;
    plan.convOptionId = optionId;
    plan.thicknessCm = (opt['thickness'] as num).toDouble();
    plan.factorCtrl.text = (opt['factor'] as num).toString();
    plan.thickCtrl.text = (opt['thickness'] as num).toString();
    final tons = double.tryParse(plan.tonsCtrl.text) ?? 0.0;
    final factor = double.tryParse(plan.factorCtrl.text) ?? 0.0;
    plan.metersCtrl.text = (tons * factor).fmt;
  }

  @override
  Widget build(BuildContext context) {
    final erp = Provider.of<ERPProvider>(context);

    // Rebuild working plans whenever a new aggregated batch arrives.
    final key = erp.pendingCuttingBatch
        .map((b) =>
            '${b.typeName}|${b.grade}|${b.totalTons.toStringAsFixed(3)}|${b.avgTonCost.toStringAsFixed(3)}')
        .join(';');
    if (key != _loadedKey) {
      for (final p in _plans) {
        p.dispose();
      }
      _loadedKey = key;
      _plans = erp.pendingCuttingBatch.map((b) => _TypePlan(b)).toList();
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('واجهة القص والتحويل (Cutting Process)',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontSize: 22)),
            const SizedBox(height: 4),
            const Text(
                'الوجبات المرحلة من المخزون حسب النوع والدرجة مع الوسط الحسابي المحسوب',
                style: TextStyle(color: AppColors.brandSecondaryText)),
            const SizedBox(height: 24),

            if (_plans.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                        'لا توجد دفعة قص مرحلة. حدد الأطنان المطلوبة من صفحة المخزون (حسب النوع والدرجة وسعر المورد) ثم اضغط تجميع ثم نقل إلى عملية القص.'),
                  ),
                ),
              ),

            ..._plans.map((plan) => _buildTypePlanCard(erp, plan)),

            if (_plans.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _wasteCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'قيمة الهدر المصنعي (\$)'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.successGreen,
                            padding: const EdgeInsets.all(16),
                          ),
                          onPressed: () =>
                              _showWarehouseTransferPopup(erp),
                          icon: const Icon(Icons.drive_file_move_rounded),
                          label: const Text(
                              '[نقل إلى مستودع المصنع]',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTypePlanCard(ERPProvider erp, _TypePlan plan) {
    final b = plan.batch;
    final usedTons =
        plan.conversions.fold(0.0, (s, c) => s + c.tons);
    final remaining = (b.totalTons - usedTons).clamp(0.0, double.infinity);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text('${b.typeName} (${b.grade})',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: AppColors.chipBgBlue,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(
                      'المحدد: ${b.totalTons.fmt} طن • المتبقي: ${remaining.fmt}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentPrimary)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
                'سعر الطن قبل القص (الوسط الحسابي): ${b.avgTonCost.fmt} \$',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.partnersEquityAccent)),
            const Divider(height: 20),

            const Text('إضافة تحويل (سماكة) جديد:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: plan.tonsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText:
                            'الأطنان المطلوبة لهذا التحويل'),
                    onChanged: (_) {
                      final tons =
                          double.tryParse(plan.tonsCtrl.text) ?? 0.0;
                      final factor =
                          double.tryParse(plan.factorCtrl.text) ?? 0.0;
                      setState(() => plan.metersCtrl.text =
                          (tons * factor).fmt);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue: plan.convOptionId,
                    decoration: const InputDecoration(
                        labelText: 'اختر التحويل'),
                    items: _convOptions.entries
                        .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value['label'] as String),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _applyOption(plan, v));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<double>(
                    initialValue: plan.feePercent,
                    decoration: const InputDecoration(
                        labelText: 'أجرة القص %'),
                    items: const [
                      DropdownMenuItem(
                          value: 0.09, child: Text('9%')),
                      DropdownMenuItem(
                          value: 0.08, child: Text('8%')),
                      DropdownMenuItem(
                          value: 0.07, child: Text('7%')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => plan.feePercent = v);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: plan.factorCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText:
                            'معامل التحويل (م²/طن أو م³/طن — قابل للتعديل)'),
                    onChanged: (_) {
                      final tons =
                          double.tryParse(plan.tonsCtrl.text) ?? 0.0;
                      final factor =
                          double.tryParse(plan.factorCtrl.text) ?? 0.0;
                      setState(() => plan.metersCtrl.text =
                          (tons * factor).fmt);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                if (plan.convOptionId == 'cube')
                  Expanded(
                    child: TextField(
                      controller: plan.thickCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'السماكة > 5 سم (تحدد م³)'),
                      onChanged: (v) => setState(() =>
                          plan.thicknessCm =
                              double.tryParse(v) ?? 10.0),
                    ),
                  ),
                if (plan.convOptionId == 'cube')
                  const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: plan.metersCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'الأمتار الناتجة (قابلة للتعديل)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ElevatedButton.icon(
                onPressed: () => _addConversion(plan),
                icon: const Icon(Icons.add),
                label: const Text('إضافة التحويل'),
              ),
            ),

            if (plan.conversions.isNotEmpty) ...[
              const Divider(height: 20),
              const Text('نتائج تحويلات هذا النوع:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...plan.conversions.asMap().entries.map((e) {
                final c = e.value;
                final meters =
                    double.tryParse(c.metersCtrl.text) ?? 0.0;
                final net = (c.tons > 0 && meters > 0)
                    ? (c.tons *
                            b.avgTonCost *
                            (1.0 + c.feePercent)) /
                        meters
                    : 0.0;
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: AppColors.panelBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                                'سماكة ${c.thicknessCm} سم • ${c.tons.fmt} طن • أجرة ${(c.feePercent * 100).fmt}%',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                                'سعر المتر بعد القص: ${net.fmt} \$',
                                style: const TextStyle(
                                    color: AppColors.successGreen,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: c.metersCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'الأمتار', isDense: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.dangerWaste),
                        onPressed: () => setState(() {
                          c.dispose();
                          plan.conversions.removeAt(e.key);
                        }),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  void _addConversion(_TypePlan plan) {
    final tons = double.tryParse(plan.tonsCtrl.text) ?? 0.0;
    final factor = double.tryParse(plan.factorCtrl.text) ?? 0.0;
    final meters = double.tryParse(plan.metersCtrl.text) ?? 0.0;
    double thickness = plan.thicknessCm;
    if (plan.convOptionId == 'cube') {
      thickness = double.tryParse(plan.thickCtrl.text) ?? 10.0;
    } else {
      thickness = (_convOptions[plan.convOptionId]!['thickness'] as num)
          .toDouble();
    }
    final used =
        plan.conversions.fold(0.0, (s, c) => s + c.tons);
    final remaining = plan.batch.totalTons - used;

    if (tons <= 0 || tons > remaining + 0.0001) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('أدخل أطناناً ضمن المتبقي لهذا النوع والدرجة.'),
        backgroundColor: AppColors.dangerWaste,
      ));
      return;
    }
    if (factor <= 0 || meters <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('أدخل معامل تحويل وأمتاراً ناتجة صحيحة.'),
        backgroundColor: AppColors.dangerWaste,
      ));
      return;
    }
    setState(() {
      plan.conversions.add(_CutDraft(
        tons: tons,
        thicknessCm: thickness,
        factor: factor,
        feePercent: plan.feePercent,
        meters: meters,
      ));
      plan.tonsCtrl.clear();
      plan.metersCtrl.clear();
    });
  }

  void _showWarehouseTransferPopup(ERPProvider erp) {
    final all = <Map<String, dynamic>>[];
    for (final plan in _plans) {
      for (final c in plan.conversions) {
        final meters = double.tryParse(c.metersCtrl.text) ?? 0.0;
        if (meters <= 0 || c.tons <= 0) continue;
        final net = (c.tons *
                plan.batch.avgTonCost *
                (1.0 + c.feePercent)) /
            meters;
        all.add({
          'plan': plan,
          'draft': c,
          'meters': meters,
          'netCtrl': TextEditingController(
              text: net.fmt),
          'saleCtrl': TextEditingController(),
        });
      }
    }
    if (all.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('أضف تحويلاً واحداً على الأقل قبل النقل.'),
        backgroundColor: AppColors.dangerWaste,
      ));
      return;
    }

    List<Map<String, dynamic>> section(bool m3) => all
        .where((e) {
          final c = e['draft'] as _CutDraft;
          return m3 ? c.thicknessCm > 5.0 : c.thicknessCm <= 5.0;
        })
        .toList();

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
                  Text('تصنيف ناتج القص (م² / م³)',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontSize: 18)),
                  const Divider(height: 20),
                  const Text('قسم المتر المربع (السماكة ≤ 5 سم):',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...section(false).map((e) =>
                      _buildTransferRow(e, 'م²')),
                  const SizedBox(height: 12),
                  const Text('قسم المتر المكعب (السماكة > 5 سم):',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...section(true).map((e) =>
                      _buildTransferRow(e, 'م³')),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.successGreen,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () {
                      final conversions = <StagedCutConversion>[];
                      for (final e in all) {
                        final plan = e['plan'] as _TypePlan;
                        final c = e['draft'] as _CutDraft;
                        final meters =
                            double.tryParse(c.metersCtrl.text) ?? 0.0;
                        final net = double.tryParse(
                                (e['netCtrl'] as TextEditingController)
                                    .text) ??
                            0.0;
                        final sale = double.tryParse(
                                (e['saleCtrl'] as TextEditingController)
                                    .text) ??
                            0.0;
                        if (meters <= 0) continue;
                        conversions.add(StagedCutConversion(
                          typeName: plan.batch.typeName,
                          grade: plan.batch.grade,
                          isGranite: plan.batch.isGranite,
                          inputTons: c.tons,
                          avgTonCost: plan.batch.avgTonCost,
                          feePercent: c.feePercent,
                          thicknessCm: c.thicknessCm,
                          category: c.thicknessCm <= 5.0
                              ? 'متر مربع'
                              : 'متر مكعب',
                          outputQty: meters,
                          netCost: net,
                          salePrice: sale,
                        ));
                      }
                      if (conversions.isEmpty) return;
                      final waste =
                          double.tryParse(_wasteCtrl.text) ?? 0.0;
                      erp.executeStagedCutting(
                          conversions: conversions,
                          wasteValue: waste);
                      for (final e in all) {
                        (e['netCtrl'] as TextEditingController)
                            .dispose();
                        (e['saleCtrl'] as TextEditingController)
                            .dispose();
                      }
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'تم النقل إلى مستودع المصنع وحفظ عملية القص بتاريخ التحويل.'),
                          backgroundColor: AppColors.successGreen,
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_circle),
                    label: const Text(
                        '[تأكيد النقل لمستودع المصنع]',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransferRow(Map<String, dynamic> e, String unit) {
    final plan = e['plan'] as _TypePlan;
    final c = e['draft'] as _CutDraft;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
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
              '${plan.batch.typeName} (${plan.batch.grade}) — سماكة ${c.thicknessCm} سم — ${(e['meters'] as double).fmt} $unit',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: e['netCtrl'] as TextEditingController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'سعر المتر بعد القص', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: e['saleCtrl'] as TextEditingController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'سعر البيع للوحدة', isDense: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


