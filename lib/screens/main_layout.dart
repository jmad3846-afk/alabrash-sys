import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/database/erp_provider.dart';
import '../widgets/app_header.dart';
import '../widgets/app_sidebar.dart';
import 'dashboard_screen.dart';
import 'factory_workspace_screen.dart';
import 'cutting_calculator_screen.dart';
import 'workshop_workspace_screen.dart';
import 'services_center_screen.dart';
import 'financials_screen.dart';
import 'workforce_screen.dart';
import 'global_orders_screen.dart';
import 'opening_entry_screen.dart';
import 'accounting_screens.dart';
import 'archive_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  void _navigateToIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds only when a full factory reset is executed, so the Opening
    // Entry screen is re-created with a blank, unlocked state.
    final resetTick = context.select<ERPProvider, int>(
      (e) => e.factoryResetTick,
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Row(
          children: [
            // Fixed Sidebar Navigation on the Right (RTL Layout)
            AppSidebar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
            ),

            // Main View Area
            Expanded(
              child: Column(
                children: [
                  // Top Header Bar with active cash badges, printer status & quick actions
                  const AppHeader(),

                  // Screen Content
                  Expanded(
                    child: IndexedStack(
                      // 0-14: sidebar screens, 15: cutting calculator (reached
                      // via "Transfer to Cutting Process", not the sidebar).
                      index: (_selectedIndex >= 0 && _selectedIndex <= 15)
                          ? _selectedIndex
                          : 0,
                      children: [
                        DashboardScreen(
                          onNavigateToIndex: _navigateToIndex,
                        ), // 0: Main Dashboard
                        FactoryWorkspaceScreen(
                          onNavigateToCutting: (idx) {
                            setState(() {
                              _selectedIndex = 15; // Cutting Calculator Screen
                            });
                          },
                        ), // 1: Factory Module
                        const WorkshopWorkspaceScreen(), // 2: Workshop Module
                        const ServicesCenterScreen(), // 3: Services Center
                        const FinancialsScreen(), // 4: General Financials
                        const FinancialsScreen(
                          showOnlyIncomeStatement: true,
                        ), // 5: Income Statement
                        const WorkforceScreen(), // 6: Workforce & Payroll
                        const GlobalOrdersScreen(), // 7: Global Orders Management
                        KeyedSubtree(
                          key: ValueKey('opening_entry_$resetTick'),
                          child: const OpeningEntryScreen(),
                        ), // 8: Opening Entry Setup
                        const ReturnsAllowancesScreen(), // 9: Factory/workshop adjustments
                        const ChartOfAccountsScreen(), // 10: Chart of Accounts
                        const FixedAssetsManagementScreen(), // 11: Fixed assets
                        const ExpensesManagementScreen(), // 12: Expenses
                        const BalanceSheetScreen(), // 13: Balance Sheet
                        const ArchiveScreen(), // 14: Archive Module
                        const CuttingCalculatorScreen(), // 15: Special Cutting Calculator
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
