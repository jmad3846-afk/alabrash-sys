import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';
import 'customer_collection_dialog.dart';
import 'customer_credit_payout_dialog.dart';

class ClientDebtModal extends StatelessWidget {
  final String
  titleFilter; // 'الكل' | 'معتمد مصنع' | 'زبون معمل' | 'مشروع معمل'
  const ClientDebtModal({super.key, required this.titleFilter});

  @override
  Widget build(BuildContext context) {
    final erp = Provider.of<ERPProvider>(context);

    final filteredClients = titleFilter == 'الكل'
        ? erp.clients
        : erp.clients.where((c) => c.clientType == titleFilter).toList();
    final historicalRecords = erp.legacyFinancialRecordsFor(
      'clients',
      clientType: titleFilter == 'الكل' ? null : titleFilter,
    );
    final unmatchedHistoricalRecords = historicalRecords
        .where(
          (record) => !filteredClients.any(
            (client) => record.belongsTo(client.id, client.name),
          ),
        )
        .toList();

    double totalDebts =
        filteredClients.fold(0.0, (s, c) => s + c.debtBalance) +
        historicalRecords
            .where((r) => r.currency == AppCurrency.usd)
            .fold<double>(0, (sum, r) => sum + r.amount);
    double totalDebtsSyp =
        filteredClients.fold(0.0, (s, c) => s + c.debtBalanceSyp) +
        historicalRecords
            .where((r) => r.currency == AppCurrency.syp)
            .fold<double>(0, (sum, r) => sum + r.amount);

    return Dialog(
      child: Container(
        width: 650,
        height: 520,
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
                      Icons.account_balance_wallet_rounded,
                      color: AppColors.accentPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'تفاصيل الديون المستحقة لنا ($titleFilter)',
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
            const Divider(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.chipBgBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'إجمالي الديون المستحقة لنا في هذا القسم ($titleFilter):',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    AppCurrency.dual(totalDebts, totalDebtsSyp),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.accentPrimary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount:
                    filteredClients.length + unmatchedHistoricalRecords.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  if (idx >= filteredClients.length) {
                    final record =
                        unmatchedHistoricalRecords[idx -
                            filteredClients.length];
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
                        'رصيد افتتاحي • ${record.phone}${record.description.isEmpty ? '' : ' • ${record.description}'}',
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
                            child: const Text('تحصيل'),
                          ),
                        ],
                      ),
                    );
                  }
                  final client = filteredClients[idx];
                  final legacyRecords = historicalRecords
                      .where(
                        (record) => record.belongsTo(client.id, client.name),
                      )
                      .toList();
                  final balanceUsd =
                      client.debtBalance +
                      erp.legacyBalanceForParty(
                        'clients',
                        client.id,
                        client.name,
                        AppCurrency.usd,
                      );
                  final balanceSyp =
                      client.debtBalanceSyp +
                      erp.legacyBalanceForParty(
                        'clients',
                        client.id,
                        client.name,
                        AppCurrency.syp,
                      );
                  final hasCredit = balanceUsd < -0.01 || balanceSyp < -0.01;
                  final hasDebt = balanceUsd > 0.01 || balanceSyp > 0.01;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.accentPrimary.withValues(
                        alpha: 0.1,
                      ),
                      child: Text(
                        client.name[0],
                        style: const TextStyle(
                          color: AppColors.accentPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            client.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CustomerClassificationBadge(
                          client: client,
                          compact: true,
                        ),
                      ],
                    ),
                    subtitle: Text(
                      '${client.clientType} • ${client.phone} • ${client.location}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hasCredit
                              ? AppCurrency.dual(
                                  (-balanceUsd).clamp(0.0, double.infinity),
                                  (-balanceSyp).clamp(0.0, double.infinity),
                                )
                              : AppCurrency.dual(balanceUsd, balanceSyp),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: hasCredit
                                ? AppColors.brandPrimaryText
                                : AppColors.dangerWaste,
                          ),
                        ),
                        if (legacyRecords.isNotEmpty) ...[
                          IconButton(
                            tooltip: 'تسوية رصيد افتتاحي باسم ${client.name}',
                            onPressed: () => _settleLegacy(
                              context,
                              erp,
                              legacyRecords.first,
                            ),
                            icon: const Icon(Icons.history, size: 20),
                          ),
                        ],
                        if (hasCredit && client.hasCredit) ...[
                          const SizedBox(width: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.dangerWaste,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              minimumSize: const Size(50, 30),
                            ),
                            onPressed: () => CustomerCreditPayoutDialog.show(
                              context,
                              client: client,
                              erp: erp,
                            ),
                            child: Text(
                              client.clientType == 'معتمد مصنع'
                                  ? 'دفع للمعتمد'
                                  : 'دفع للزبون',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ] else if (hasDebt && client.hasDebt) ...[
                          const SizedBox(width: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.successGreen,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              minimumSize: const Size(50, 30),
                            ),
                            onPressed: () => CustomerCollectionDialog.show(
                              context,
                              client: client,
                              erp: erp,
                            ),
                            child: const Text(
                              'تحصيل',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ] else if (hasDebt && legacyRecords.isNotEmpty) ...[
                          ElevatedButton(
                            onPressed: () => _settleLegacy(
                              context,
                              erp,
                              legacyRecords.first,
                            ),
                            child: const Text('تحصيل'),
                          ),
                        ],
                      ],
                    ),
                  );
                },
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
        title: Text('تحصيل من ${record.name}'),
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
            child: const Text('تأكيد التحصيل'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null) return;
    final settled = erp.settleLegacyFinancialRecord(record.id, amount, 'main');
    if (!settled && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تسجيل التحصيل. تحقق من المبلغ.')),
      );
    }
  }
}
