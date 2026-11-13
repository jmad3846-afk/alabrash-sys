/// Session-scoped auto-save store for the invoice/order creation forms.
///
/// Every supported dialog captures its full form state (client selection,
/// draft rows, service pickers, additional fields, controller texts) into
/// this in-memory store on every rebuild. If the user closes the dialog
/// without saving — the X button, the cancel footer, or navigating away —
/// reopening the same dialog later in the same session restores everything
/// instantly. The cached draft is cleared on a successful save or when the
/// user explicitly taps the "تجاهل المسودة" (Discard draft) button.
///
/// It is intentionally NOT persisted to disk: drafts live only for the
/// current app session.
class FormDraftStore {
  FormDraftStore._();

  static final Map<String, Map<String, dynamic>> _drafts = {};

  /// Well-known draft keys, one per creation flow. Flows that can be
  /// opened with different contexts (cash vs credit, editing a specific
  /// order) use [keyFor] to derive a context-qualified variant.
  static const String factoryInvoiceKey = 'form_draft:factory_invoice';
  static const String factoryOrderKey = 'form_draft:factory_order';
  static const String workshopInvoiceKey = 'form_draft:workshop_invoice';
  static const String workshopOrderKey = 'form_draft:workshop_order';

  /// Builds a context-qualified draft key, e.g.
  /// `keyFor(factoryOrderKey, 'edit:fo_123')` or
  /// `keyFor(workshopInvoiceKey, 'cash')`.
  static String keyFor(String base, String? variant) =>
      (variant == null || variant.isEmpty) ? base : '$base@$variant';

  static void save(String key, Map<String, dynamic> Function() capture) {
    try {
      _drafts[key] = capture();
    } catch (_) {
      // A draft must never break the form itself.
    }
  }

  static Map<String, dynamic>? load(String key) => _drafts[key];

  static bool has(String key) => _drafts.containsKey(key);

  static void discard(String key) => _drafts.remove(key);
}
