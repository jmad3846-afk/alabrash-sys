import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';
import 'customer_collection_dialog.dart';

class ClientDebtModal extends StatelessWidget {
  final String titleFilter; // 'الكل' | 'معتمد مصنع' | 'زبون معمل' | 'مشروع معمل'
  const ClientDebtModal({super.key, required this.titleFilter});

  @override
  Widget build(BuildContext context) {
    final erp = Provider.of<ERPProvider>(context);

    final filteredClients = titleFilter == 'الكل'
        ? erp.clients
        : erp.clients.where((c) => c.clientType == titleFilter).toList();

    double totalDebts = filteredClients.fold(0.0, (s, c) => s + c.debtBalance);
    double totalDebtsSyp =
        filteredClients.fold(0.0, (s, c) => s + c.debtBalanceSyp);

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
                    const Icon(Icons.account_balance_wallet_rounded, color: AppColors.accentPrimary),
                    const SizedBox(width: 8),
                    Text(
                      'تفاصيل الديون المستحقة لنا ($titleFilter)',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
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
                  Text('إجمالي الديون المستحقة لنا في هذا القسم ($titleFilter):', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(AppCurrency.dual(totalDebts, totalDebtsSyp), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentPrimary, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: filteredClients.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final client = filteredClients[idx];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.accentPrimary.withValues(alpha: 0.1),
                      child: Text(client.name[0], style: const TextStyle(color: AppColors.accentPrimary, fontWeight: FontWeight.bold)),
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(client.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        CustomerClassificationBadge(client: client, compact: true),
                      ],
                    ),
                    subtitle: Text('${client.clientType} • ${client.phone} • ${client.location}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          client.dualDebt,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.dangerWaste),
                        ),
                        if (client.debtBalance > 0.01 || client.debtBalanceSyp > 0.01) ...[
                          const SizedBox(width: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.successGreen,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: const Size(50, 30),
                            ),
                            onPressed: () => CustomerCollectionDialog.show(
                              context,
                              client: client,
                              erp: erp,
                            ),
                            child: const Text('تحصيل', style: TextStyle(fontSize: 11)),
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
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandPrimaryText),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }
}
