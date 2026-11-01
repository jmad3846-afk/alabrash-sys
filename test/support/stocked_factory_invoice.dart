import 'package:abaad/core/database/erp_provider.dart';
import 'package:abaad/core/models/models.dart';

/// Seed real stock for legacy invoice fixtures that only described a sale.
bool postStockedFactoryInvoice(ERPProvider erp, FactoryInvoiceModel invoice) {
  for (var n = 0; n < invoice.items.length; n++) {
    final item = invoice.items[n];
    if (item.isTailoringItem) continue;
    if (!erp.factoryWarehouse.any(
      (w) => w.id == item.itemId && w.currency == invoice.currency,
    )) {
      erp.factoryWarehouse.add(
        FactoryWarehouseModel(
          id: item.itemId,
          typeName: item.description,
          grade: item.grade,
          thicknessCm: item.thicknessCm,
          category: item.isCubicMeter ? 'متر مكعب' : 'متر مربع',
          availableQty: item.calculatedArea + 100,
          netCostPerUnit: item.unitCost,
          recommendedSalePrice: item.unitPrice,
          currency: invoice.currency,
        ),
      );
    }
    invoice.items[n] = item.copyWith(itemCategory: 'meter');
  }
  return erp.addFactoryPOSInvoice(invoice);
}
