# Abaad (أبعاد)

Offline Flutter ERP for marble and granite factory and workshop operations.

## Accounting workflows

- **Opening Entry** records fixed assets by category, dual-currency cash boxes,
  detailed opening stock, and individual historical customer, supplier, and
  employee balances. Its records are saved locally with the entry.
- **Fixed Assets Management** records asset purchases against the main cash
  box and asset sales, distributing sale proceeds equally among the three
  partners with a per-partner choice to retain or withdraw their share.
- **Chart of Accounts** summarizes assets, current liabilities, partner equity,
  revenues, and expenses, including a live USD/SYP balance-sheet view.
- **Old Invoices Financials** is available as a tab in Financials for reviewing
  and settling opening customer, supplier, and employee balances.
- **Returns & Allowances** links factory and workshop adjustments to original
  invoices. Returns capture the item and quantity, update linked invoice
  balances and the relevant stock ledger, and offer debt or cash settlement.
  Supplier cash credits are received into the main box; customer cash refunds
  are paid from it. Sales and supplier discounts are recorded on their invoice
  forms.
- **Expenses** supports expense types, individual amounts, and named
  beneficiaries; an internal employee's share is posted to workforce earnings.

Records are stored locally using `shared_preferences`.

## Development

- Run `flutter analyze` to analyze the application.
- Run `flutter test` to execute the test suite.
