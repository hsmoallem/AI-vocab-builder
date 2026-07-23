import 'package:flutter/material.dart';
import 'searchable_dropdown.dart';

/// CEFR language proficiency levels (Goethe-Institut / telc standard)
const cefrLevels = {
  'A1': 'A1 — Beginner',
  'A2': 'A2 — Elementary',
  'B1': 'B1 — Intermediate',
  'B2': 'B2 — Upper Intermediate',
  'C1': 'C1 — Advanced',
  'C2': 'C2 — Proficient',
};

/// A compact dropdown for selecting CEFR level. Pass `null` for "no level filter"
/// (AI auto-adjusts). The controller tracks which level is currently active.
class CefrLevelDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?>? onChanged;
  final bool compact;

  const CefrLevelDropdown({
    super.key,
    this.value,
    this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      const DropdownMenuItem<String>(
        value: null,
        child: Text('Auto (all levels)'),
      ),
      ...cefrLevels.entries.map((e) => DropdownMenuItem(
            value: e.key,
            child: Text(e.value),
          )),
    ];

    return SearchableDropdown<String?>(
      value: value,
      labelText: 'CEFR Level',
      items: items,
      itemAsString: (val) {
        if (val == null) return 'Auto (all levels)';
        return cefrLevels[val] ?? val;
      },
      onChanged: onChanged,
    );
  }
}

