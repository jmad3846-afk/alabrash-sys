import 'package:abaad/widgets/styled_item_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Purely visual enhancement of the material / meter item dropdowns used by
/// the Factory Invoice, Workshop Invoice, Factory Order and Workshop Order
/// forms:
///  - opened menu rows alternate a background tint + hairline divider,
///  - every row starts with a cycling tinted icon,
///  - the closed button keeps its plain label (no stripes inside the field),
///  - selection behaviour is unchanged.
void main() {
  group('StyledItemDropdown', () {
    testWidgets('opened menu shows alternating styled rows, closed field stays plain', (
      tester,
    ) async {
      String? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StyledItemDropdown<String>(
              items: const ['block-a', 'block-b', 'block-c'],
              valueOf: (v) => v,
              labelOf: (v) => 'صنف $v',
              decoration: const InputDecoration(labelText: 'اختر الصنف'),
              icon: Icons.inventory_2_outlined,
              onChanged: (v) => selected = v,
            ),
          ),
        ),
      );

      // Closed field: plain label only — no styled rows rendered inside it.
      expect(find.byType(StyledItemDropdownRow), findsNothing);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

      // Open the menu.
      await tester.tap(find.text('اختر الصنف'));
      await tester.pumpAndSettle();

      // One styled row per entry, each with the leading icon.
      final rowFinder = find.byType(StyledItemDropdownRow);
      expect(rowFinder, findsNWidgets(3));
      expect(
        find.descendant(
          of: rowFinder,
          matching: find.byIcon(Icons.inventory_2_outlined),
        ),
        findsNWidgets(3),
      );

      // Alternating row backgrounds: even = transparent, odd = tinted.
      Color? rowColor(int index) {
        final containerFinder = find
            .descendant(of: rowFinder.at(index), matching: find.byType(Container))
            .first;
        final container = tester.widget<Container>(containerFinder);
        return (container.decoration as BoxDecoration).color;
      }

      expect(rowColor(0), const Color(0x00000000));
      expect(rowColor(1), const Color(0x120F172A));
      expect(rowColor(2), const Color(0x00000000));

      // Rows are separated by a hairline divider.
      BoxDecoration decorationOf(int index) {
        final containerFinder = find
            .descendant(of: rowFinder.at(index), matching: find.byType(Container))
            .first;
        return tester.widget<Container>(containerFinder).decoration
            as BoxDecoration;
      }

      expect(decorationOf(0).border?.bottom.width, 1.0);

      // Selecting still works exactly as before.
      await tester.tap(find.text('صنف block-b'));
      await tester.pumpAndSettle();

      expect(selected, 'block-b');
      expect(find.byType(StyledItemDropdownRow), findsNothing);
      expect(find.text('صنف block-b'), findsWidgets);
    });

    testWidgets('selected label of the closed field comes from the same labelOf closure', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StyledItemDropdown<String>(
              items: const ['meter-a', 'meter-b'],
              valueOf: (v) => v,
              labelOf: (v) => 'نوع $v',
              selectedValue: 'meter-b',
              decoration: const InputDecoration(labelText: 'نوع المتر'),
              onChanged: (_) {},
            ),
          ),
        ),
      );

      // The closed field shows the selected entry's label, plain.
      expect(find.text('نوع meter-b'), findsWidgets);
      expect(find.byType(StyledItemDropdownRow), findsNothing);
    });
  });
}
