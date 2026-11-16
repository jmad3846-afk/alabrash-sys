import 'package:flutter/material.dart';

/// Visual enhancement for the material / meter item pickers used by the
/// Factory Invoice, Workshop Invoice, Factory Order and Workshop Order
/// forms.
///
/// The opened menu rows alternate a subtle background tint, are separated by
/// hairline dividers and start with a cycling tinted icon so neighbouring
/// entries are easy to tell apart. The stripes are semi-transparent on
/// purpose: the menu's ink feedback (hover / pressed / selected highlight)
/// stays visible underneath.
///
/// This is purely presentational — values, labels, validation and callbacks
/// are untouched, and the closed button keeps showing the plain label through
/// `selectedItemBuilder`.
class StyledItemDropdownRow extends StatelessWidget {
  const StyledItemDropdownRow({
    super.key,
    required this.index,
    required this.child,
    this.icon = Icons.category_outlined,
  });

  /// Position of the row inside the opened menu (drives the alternation and
  /// the icon tint cycle).
  final int index;

  /// The original label widget (a [Text]) — kept as-is so the row inherits
  /// the dropdown's own text style.
  final Widget child;

  /// Leading icon of the row.
  final IconData icon;

  /// Icon tints cycled through the rows.
  static const List<Color> tints = <Color>[
    Color(0xFF2563EB), // blue
    Color(0xFF0D9488), // teal
    Color(0xFFB45309), // amber
    Color(0xFF7C3AED), // violet
  ];

  Color get tint => tints[index % tints.length];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: index.isEven ? const Color(0x00000000) : const Color(0x120F172A),
        border: const Border(
          bottom: BorderSide(color: Color(0x140F172A), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 15, color: tint),
          ),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Drop-in replacement for the `DropdownButtonFormField<String>` item
/// pickers of the four forms above: same value/label/onChanged contract,
/// but the opened menu renders [StyledItemDropdownRow] rows instead of plain
/// text, while the closed button keeps its current plain label.
class StyledItemDropdown<M> extends StatelessWidget {
  const StyledItemDropdown({
    super.key,
    required this.items,
    required this.valueOf,
    required this.labelOf,
    this.selectedValue,
    this.isExpanded = true,
    this.decoration,
    this.onChanged,
    this.icon = Icons.category_outlined,
  });

  /// Source entries (already filtered / searched by the caller).
  final Iterable<M> items;

  /// Extracts the dropdown value of one entry (usually its id).
  final String Function(M item) valueOf;

  /// Builds the label of one entry — used identically by the opened menu
  /// rows and by the closed button, so they can never drift apart.
  final String Function(M item) labelOf;

  /// Currently selected value (maps to `DropdownButtonFormField.value` /
  /// `initialValue`).
  final String? selectedValue;

  final bool isExpanded;
  final InputDecoration? decoration;
  final ValueChanged<String?>? onChanged;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final options = items.toList(growable: false);
    return DropdownButtonFormField<String>(
      initialValue: selectedValue,
      isExpanded: isExpanded,
      decoration: decoration,
      items: <DropdownMenuItem<String>>[
        for (var i = 0; i < options.length; i++)
          DropdownMenuItem<String>(
            value: valueOf(options[i]),
            child: StyledItemDropdownRow(
              index: i,
              icon: icon,
              child: Text(labelOf(options[i])),
            ),
          ),
      ],
      // Closed button: plain label (no stripes / icon inside the field).
      selectedItemBuilder: (BuildContext context) => <Widget>[
        for (final option in options) Text(labelOf(option)),
      ],
      onChanged: onChanged,
    );
  }
}
