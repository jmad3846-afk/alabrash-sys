import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/database/erp_provider.dart';
import '../core/models/models.dart';
import '../core/theme/app_theme.dart';

/// Drill-down breakdown behind the Home-screen totals cards.
/// Shows EVERY Supplier and Distributor/Agent whose remaining NET balance
/// sits on the selected side:
///  • receivableSide == true  → إجمالي المستحقات لنا (they owe the company)
///  • receivableSide == false → إجمالي المستحقات علينا (the company owes them)
/// Workers and retail/regular customers are never listed (strict scope of
/// the unified metrics).
class PartyBalancesModal extends StatelessWidget {
  final bool receivableSide;

  const PartyBalancesModal({super.key, required this.receivableSide});

  static Future<void> show(BuildContext context, {required bool receivableSide}) {
    return showDialog(
      context: context,
      builder: (_) => PartyBalancesModal(receivableSide: receivableSide),
    );
  }

  @override
  Widget build(BuildContext context) {
    final erp = Provider.of<ERPProvider>(context);
    final lists = erp.partyBalances();
    final rows = receivableSide ? lists.receivables : lists.payables;

    final accent = receivableSide
        ? AppColors.successGreen
        : AppColors.dangerWaste;
    final title = receivableSide
        ? 'إجمالي المستحقات لنا (Total Receivables)'
        : 'إجمالي المستحقات علينا (Total Payables)';
    final totalUsd = rows.fold<double>(0.0, (s, r) => s + r.usdAmount);
    final totalSyp = rows.fold<double>(0.0, (s, r) => s + r.sypAmount);

    return Dialog(
      child: Container(
        width: 720,
        height: 560,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          receivableSide
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          color: accent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              receivableSide
                  ? 'كل مورد أو معتمد له رصيد net في ذمته لنا — لا يشمل العمال أو الزبائن الجزافيين.'
                  : 'كل مورد أو معتمد لنا عليه رصيد net — لا يشمل العمال أو الزبائن الجزافيين.',
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.brandSecondaryText,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.balance_rounded,
                            size: 42,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'لا توجد أرصدة في هذا الاتجاه حالياً.',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final row = rows[idx];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: accent.withValues(alpha: 0.12),
                            child: Icon(
                              row.isSupplier
                                  ? Icons.local_shipping_outlined
                                  : Icons.badge_outlined,
                              size: 18,
                              color: accent,
                            ),
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  row.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _RoleBadge(roleLabel: row.roleLabel, isSupplier: row.isSupplier),
                            ],
                          ),
                          subtitle: row.role == 'مورد — قيد افتتاحي'
                              ? const Text(
                                  'رصيد افتتاحي مدور من القيد الافتتاحي',
                                  style: TextStyle(fontSize: 11),
                                )
                              : null,
                          trailing: Text(
                            row.dualText,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: accent,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'الإجمالي المعروض:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  AppCurrency.dual(totalUsd, totalSyp),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: accent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Displays the REMAINING BALANCE from a counterparty's account statement
/// (كشف الحساب) with an explicit direction label:
///  • 'لنا' (Receivable — the counterparty owes the company) in green.
///  • 'علينا' (Payable — the company owes the counterparty) in red.
/// [agentSide] selects the balance convention: for distributors/agents a
/// positive net means THEY owe us; for suppliers (agentSide == false) a
/// positive net means WE owe them. Each currency is labelled independently,
/// so a mixed-direction account is still shown truthfully.
class StatementBalanceLabel extends StatelessWidget {
  final double netUsd;
  final double netSyp;
  final bool agentSide;

  const StatementBalanceLabel({
    super.key,
    required this.netUsd,
    required this.netSyp,
    this.agentSide = false,
  });

  @override
  Widget build(BuildContext context) {
    final parts = <Widget>[];

    void addPart(double value, String symbol) {
      if (value.abs() <= 0.01) return;
      // Direction: agent positive = لنا; supplier negative = لنا.
      final forUs = agentSide ? value > 0 : value < 0;
      if (parts.isNotEmpty) {
        parts.add(
          const Text(
            '  •  ',
            style: TextStyle(color: AppColors.brandSecondaryText),
          ),
        );
      }
      parts.add(
        Text(
          '${value.abs().fmt} $symbol ${forUs ? 'لنا' : 'علينا'}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: forUs ? AppColors.successGreen : AppColors.dangerWaste,
          ),
        ),
      );
    }

    addPart(netUsd, '\$');
    addPart(netSyp, 'ل.س');

    if (parts.isEmpty) {
      parts.add(
        const Text(
          'رصيد منتهٍ (خالص)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.brandSecondaryText,
          ),
        ),
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'الرصيد المتبقي من كشف الحساب: ',
          style: TextStyle(fontSize: 12, color: AppColors.brandSecondaryText),
        ),
        ...parts,
      ],
    );
  }
}

/// Small pill badge marking the counterparty role in the drill-down list.
class _RoleBadge extends StatelessWidget {
  final String roleLabel;
  final bool isSupplier;

  const _RoleBadge({required this.roleLabel, required this.isSupplier});

  @override
  Widget build(BuildContext context) {
    final color = isSupplier
        ? const Color(0xFFB45309) // supplier — amber
        : const Color(0xFF1D4ED8); // agent — blue
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        roleLabel,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
