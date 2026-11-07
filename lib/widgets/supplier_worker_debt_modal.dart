import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';

class SupplierWorkerDebtModal extends StatefulWidget {
  const SupplierWorkerDebtModal({super.key});

  @override
  State<SupplierWorkerDebtModal> createState() =>
      _SupplierWorkerDebtModalState();
}

class _SupplierWorkerDebtModalState extends State<SupplierWorkerDebtModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final erp = Provider.of<ERPProvider>(context);
    final historicalSuppliers = erp.legacyFinancialRecordsFor('suppliers');
    final historicalEmployees = erp.legacyFinancialRecordsFor('employees');
    final unmatchedSuppliers = historicalSuppliers
        .where(
          (record) => !erp.suppliers.any(
            (supplier) => record.belongsTo(supplier.id, supplier.name),
          ),
        )
        .toList();
    final unmatchedEmployees = historicalEmployees
        .where(
          (record) => !erp.staffList.any(
            (staff) => record.belongsTo(staff.id, staff.name),
          ),
        )
        .toList();
    final supplierHistoricalUsd = historicalSuppliers
        .where((record) => record.currency == AppCurrency.usd)
        .fold<double>(0, (sum, record) => sum + record.amount);
    final supplierHistoricalSyp = historicalSuppliers
        .where((record) => record.currency == AppCurrency.syp)
        .fold<double>(0, (sum, record) => sum + record.amount);
    final employeeHistoricalUsd = historicalEmployees
        .where((record) => record.currency == AppCurrency.usd)
        .fold<double>(0, (sum, record) => sum + record.amount);
    final employeeHistoricalSyp = historicalEmployees
        .where((record) => record.currency == AppCurrency.syp)
        .fold<double>(0, (sum, record) => sum + record.amount);

    return Dialog(
      child: Container(
        width: 700,
        height: 560,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.outbox_rounded,
                      color: AppColors.dangerWaste,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'تفاصيل المستحقات والديون التي علينا (عمال وموردين)',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontSize: 18),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  text:
                      'ديون الموردين (${AppCurrency.dual(erp.suppliersTotalDebts + supplierHistoricalUsd, erp.suppliersTotalDebtsSyp + supplierHistoricalSyp)})',
                ),
                Tab(
                  text:
                      'مستحقات العمالة (${AppCurrency.dual(erp.workersTotalDebts + employeeHistoricalUsd, erp.workersTotalDebtsSyp + employeeHistoricalSyp)})',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Supplier Debts
                  ListView.separated(
                    itemCount: erp.suppliers.length + unmatchedSuppliers.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      if (idx >= erp.suppliers.length) {
                        final record =
                            unmatchedSuppliers[idx - erp.suppliers.length];
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.chipBgAmber,
                            child: Icon(
                              Icons.history,
                              color: AppColors.partnersEquityAccent,
                            ),
                          ),
                          title: Text(
                            record.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'رصيد افتتاحي للمورد • ${record.phone}${record.description.isEmpty ? '' : ' • ${record.description}'}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${record.amount.fmt} ${AppCurrency.symbol(record.currency)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.dangerWaste,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: record.amount <= 0
                                    ? null
                                    : () => _settleLegacy(context, erp, record),
                                child: const Text('دفع'),
                              ),
                            ],
                          ),
                        );
                      }
                      final supplier = erp.suppliers[idx];
                      final linkedRecords = historicalSuppliers
                          .where(
                            (record) =>
                                record.belongsTo(supplier.id, supplier.name),
                          )
                          .toList();
                      final balanceUsd =
                          supplier.debtBalance +
                          erp.legacyBalanceForParty(
                            'suppliers',
                            supplier.id,
                            supplier.name,
                            AppCurrency.usd,
                          );
                      final balanceSyp =
                          supplier.debtBalanceSyp +
                          erp.legacyBalanceForParty(
                            'suppliers',
                            supplier.id,
                            supplier.name,
                            AppCurrency.syp,
                          );
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.partnersEquityAccent
                              .withValues(alpha: 0.1),
                          child: Text(
                            supplier.name[0],
                            style: const TextStyle(
                              color: AppColors.partnersEquityAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          supplier.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${supplier.phone} • ${supplier.location}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppCurrency.dual(balanceUsd, balanceSyp),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.dangerWaste,
                              ),
                            ),
                            if (linkedRecords.isNotEmpty)
                              IconButton(
                                tooltip:
                                    'تسوية رصيد افتتاحي باسم ${supplier.name}',
                                onPressed: () => _settleLegacy(
                                  context,
                                  erp,
                                  linkedRecords.first,
                                ),
                                icon: const Icon(Icons.history, size: 20),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  // Tab 2: Worker Debts
                  ListView.separated(
                    itemCount: erp.staffList.length + unmatchedEmployees.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      if (idx >= erp.staffList.length) {
                        final record =
                            unmatchedEmployees[idx - erp.staffList.length];
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.chipBgBlue,
                            child: Icon(
                              Icons.history,
                              color: AppColors.accentPrimary,
                            ),
                          ),
                          title: Text(
                            record.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'رصيد افتتاحي للموظف • ${record.phone}${record.description.isEmpty ? '' : ' • ${record.description}'}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${record.amount.fmt} ${AppCurrency.symbol(record.currency)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.dangerWaste,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: record.amount <= 0
                                    ? null
                                    : () => _settleLegacy(context, erp, record),
                                child: const Text('دفع'),
                              ),
                            ],
                          ),
                        );
                      }
                      final staff = erp.staffList[idx];
                      final linkedRecords = historicalEmployees
                          .where(
                            (record) => record.belongsTo(staff.id, staff.name),
                          )
                          .toList();
                      final legacyUsd = erp.legacyBalanceForParty(
                        'employees',
                        staff.id,
                        staff.name,
                        AppCurrency.usd,
                      );
                      final legacySyp = erp.legacyBalanceForParty(
                        'employees',
                        staff.id,
                        staff.name,
                        AppCurrency.syp,
                      );
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.accentPrimary.withValues(
                            alpha: 0.1,
                          ),
                          child: Text(
                            staff.name[0],
                            style: const TextStyle(
                              color: AppColors.accentPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          staff.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'الفئة: ${staff.category} • المكتسب: ${AppCurrency.dual(staff.totalEarned, staff.totalEarnedSyp)} • السُلف: ${AppCurrency.dual(staff.cashAdvancesDisbursed, staff.cashAdvancesDisbursedSyp)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppCurrency.dual(
                                staff.netRemainingBalance + legacyUsd,
                                staff.netRemainingBalanceSyp + legacySyp,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.dangerWaste,
                              ),
                            ),
                            if (linkedRecords.isNotEmpty)
                              IconButton(
                                tooltip:
                                    'تسوية رصيد افتتاحي باسم ${staff.name}',
                                onPressed: () => _settleLegacy(
                                  context,
                                  erp,
                                  linkedRecords.first,
                                ),
                                icon: const Icon(Icons.history, size: 20),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimaryText,
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _settleLegacy(
    BuildContext context,
    ERPProvider erp,
    LegacyFinancialRecordModel record,
  ) async {
    final controller = TextEditingController(text: record.amount.fmt);
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('تسديد ${record.name}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText:
                'المبلغ (حد أقصى ${record.amount.fmt} ${AppCurrency.symbol(record.currency)})',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null && value > 0 && value <= record.amount) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: const Text('تأكيد الدفع'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null) return;
    final settled = erp.settleLegacyFinancialRecord(record.id, amount, 'main');
    if (!settled && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رصيد الصندوق لا يكفي لإتمام عملية الدفع.'),
        ),
      );
    }
  }
}
