import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';

class ArchiveAndClosePeriodModal extends StatefulWidget {
  final VoidCallback? onNavigateToArchive;

  const ArchiveAndClosePeriodModal({super.key, this.onNavigateToArchive});

  @override
  State<ArchiveAndClosePeriodModal> createState() =>
      _ArchiveAndClosePeriodModalState();
}

class _ArchiveAndClosePeriodModalState
    extends State<ArchiveAndClosePeriodModal> {
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;
  bool _confirmed = false;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final periodName = now.month <= 6 ? 'الأول' : 'الثاني';
    _nameController = TextEditingController(
      text: 'أرشيف النصف $periodName ${now.year}',
    );
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final erp = Provider.of<ERPProvider>(context);

    // Calculate closed period figures
    final revUsd = erp.totalRevenuesOf(AppCurrency.usd);
    final revSyp = erp.totalRevenuesOf(AppCurrency.syp);
    final expUsd = erp.totalDirectExpensesOf(AppCurrency.usd);
    final expSyp = erp.totalDirectExpensesOf(AppCurrency.syp);
    final profitUsd = erp.netOperatingProfitOf(AppCurrency.usd);
    final profitSyp = erp.netOperatingProfitOf(AppCurrency.syp);

    // Previews next period Opening Entry & validates Trial Balance
    final proposedEntry = erp.previewNextPeriodOpeningEntry();
    final validation = erp.validateTrialBalanceIntegrity(
      proposedEntry: proposedEntry,
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
        child: Column(
          children: [
            // Header
            _buildHeader(context),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Archive Name & Notes
                    _buildInputsSection(),

                    const SizedBox(height: 18),

                    // Financial Summary of Closing Period
                    _buildPeriodSummaryCard(
                      revUsd: revUsd,
                      revSyp: revSyp,
                      expUsd: expUsd,
                      expSyp: expSyp,
                      profitUsd: profitUsd,
                      profitSyp: profitSyp,
                    ),

                    const SizedBox(height: 18),

                    // Next Period Rolled-over Balances Card
                    _buildRolledBalancesCard(erp, proposedEntry),

                    const SizedBox(height: 18),

                    // Trial Balance Validation Card
                    _buildTrialBalanceValidationCard(validation),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFFDC2626),
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Color(0xFFB91C1C),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),

                    // Confirmation Checkbox
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: CheckboxListTile(
                        value: _confirmed,
                        onChanged: (val) {
                          setState(() {
                            _confirmed = val ?? false;
                          });
                        },
                        activeColor: const Color(0xFFD97706),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'أؤكد فهمي بأن العمليات المنتهية (فواتير، مصروفات، أجور، تقارير) ستنقل إلى قسم "الأرشيف" للقراءة والبحث فقط، وسيتم بدء دورة محاسبية نظيفة بقيد افتتاحي متوازن مدور فيه الأرباح.',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92400E),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1),

            // Footer Actions
            _buildFooterActions(context, erp, validation),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Dark slate
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFD97706).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD97706)),
            ),
            child: const Icon(
              Icons.archive_rounded,
              color: Color(0xFFFBBF24),
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ترحيل وجرد وإغلاق الدورة المحاسبية • برنامج أبعاد',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'أرشفة السجلات التاريخية • تصفير حسابات المصروفات والإيرادات • تدوير الأرباح وتوليد قيد افتتاحي متوازن',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            tooltip: 'إلغاء',
          ),
        ],
      ),
    );
  }

  Widget _buildInputsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'بيانات أرشفة الدورة المالية:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'اسم الأرشيف / الدورة المالية *',
              hintText: 'مثال: أرشيف النصف الأول 2026',
              prefixIcon: const Icon(
                Icons.label_important_rounded,
                color: Color(0xFFD97706),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'ملاحظات ختامية حول الدورة (اختياري)',
              hintText: 'أي ملاحظات إضافية حول الجرد أو التسويات السنوية...',
              prefixIcon: const Icon(Icons.notes_rounded),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSummaryCard({
    required double revUsd,
    required double revSyp,
    required double expUsd,
    required double expSyp,
    required double profitUsd,
    required double profitSyp,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.assessment_rounded, color: Color(0xFF0F766E), size: 20),
              SizedBox(width: 8),
              Text(
                'نتائج الدورة المالية المغلقة (تصفير الحسابات المؤقتة وتدوير الأرباح):',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'إجمالي الإيرادات',
                  usdValue: revUsd,
                  sypValue: revSyp,
                  color: const Color(0xFF16A34A),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  label: 'إجمالي المصروفات',
                  usdValue: expUsd,
                  sypValue: expSyp,
                  color: const Color(0xFFDC2626),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  label: 'صافي الربح المدور',
                  usdValue: profitUsd,
                  sypValue: profitSyp,
                  color: profitUsd >= 0
                      ? const Color(0xFF0D9488)
                      : const Color(0xFFEA580C),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required double usdValue,
    required double sypValue,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${usdValue.fmt} \$',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (sypValue.abs() > 0.01)
            Text(
              '${sypValue.fmt} ل.س',
              style: TextStyle(
                fontSize: 11,
                color: color.withValues(alpha: 0.8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRolledBalancesCard(ERPProvider erp, OpeningEntryModel proposed) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_rounded,
                  color: Color(0xFF2563EB), size: 20),
              SizedBox(width: 8),
              Text(
                'أرصدة القيد الافتتاحي المدورة للدورة الجديدة:',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildPill(
                icon: Icons.point_of_sale_rounded,
                label: 'نقدية الصناديق',
                value:
                    '${(erp.mainCashBox + erp.scrapCashBox + erp.orderCashBox).fmt} \$',
                color: const Color(0xFF16A34A),
              ),
              _buildPill(
                icon: Icons.apartment_rounded,
                label: 'الأصول الثابتة',
                value: '${proposed.totalFixedAssets.fmt} \$',
                color: const Color(0xFF0F766E),
              ),
              _buildPill(
                icon: Icons.inventory_2_rounded,
                label: 'المخزون السلعي',
                value: '${proposed.inventoryValue.fmt} \$',
                color: const Color(0xFF0284C7),
              ),
              _buildPill(
                icon: Icons.people_outline_rounded,
                label: 'ذمم الزبائن',
                value: '${proposed.customerDebtsValue.fmt} \$',
                color: const Color(0xFF6366F1),
              ),
              _buildPill(
                icon: Icons.local_shipping_outlined,
                label: 'ذمم الموردين',
                value: '${proposed.supplierPayablesValue.fmt} \$',
                color: const Color(0xFFE11D48),
              ),
              _buildPill(
                icon: Icons.badge_outlined,
                label: 'أجور مستحقة',
                value: '${proposed.workerSalariesValue.fmt} \$',
                color: const Color(0xFFD97706),
              ),
              _buildPill(
                icon: Icons.pie_chart_rounded,
                label: 'صافي حقوق الملكية',
                value: '${proposed.totalEquity.fmt} \$',
                color: const Color(0xFF7C3AED),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialBalanceValidationCard(AccountingValidationResult val) {
    final isClean = val.isCleanBalanced;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isClean ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isClean ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isClean
                ? Icons.check_circle_rounded
                : Icons.warning_amber_rounded,
            color: isClean ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isClean
                      ? 'ميزان المراجعة متوازن 100% (Trial Balance Integrity Passed)'
                      : 'تنبيه: يوجد اختلال في توازن ميزان المراجعة!',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: isClean
                        ? const Color(0xFF15803D)
                        : const Color(0xFFB91C1C),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isClean
                      ? 'إجمالي الأصول (${val.totalAssetsUsd.fmt} \$) = الخصوم (${val.totalLiabilitiesUsd.fmt} \$) + حقوق الملكية (${val.totalEquityUsd.fmt} \$). الفرق: 0.00 \$'
                      : val.errorMessage ?? 'اختلال في ميزان المراجعة.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isClean
                        ? const Color(0xFF166534)
                        : const Color(0xFF991B1B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterActions(
    BuildContext context,
    ERPProvider erp,
    AccountingValidationResult validation,
  ) {
    final canSubmit =
        _confirmed && validation.isCleanBalanced && !_isProcessing;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          TextButton(
            onPressed:
                _isProcessing ? null : () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 2,
            ),
            onPressed: canSubmit
                ? () async {
                    setState(() {
                      _isProcessing = true;
                      _errorMessage = null;
                    });
                    try {
                      final result = erp.archiveAndClosePeriod(
                        archiveName: _nameController.text.trim().isEmpty
                            ? 'أرشيف غير مسمى'
                            : _nameController.text.trim(),
                        notes: _notesController.text.trim(),
                      );
                      if (!result.isValid) {
                        setState(() {
                          _isProcessing = false;
                          _errorMessage = result.errorMessage;
                        });
                        return;
                      }
                      if (context.mounted) {
                        Navigator.of(context).pop(true);
                        widget.onNavigateToArchive?.call();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'تم ترحيل وجرد الدورة المالية بنجاح (${_nameController.text})، ونقلت السجلات إلى الأرشيف! 🎉',
                            ),
                            backgroundColor: const Color(0xFF16A34A),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    } catch (e) {
                      setState(() {
                        _isProcessing = false;
                        _errorMessage = 'حدث خطأ أثناء تنفيذ الترحيل: $e';
                      });
                    }
                  }
                : null,
            icon: _isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.archive_rounded, size: 20),
            label: Text(
              _isProcessing
                  ? 'جاري الترحيل والجرد وتدوير الأرصدة...'
                  : 'تأكيد الترحيل وجرد الدورة الآن',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
