import 'package:flutter/material.dart';

import '../../../models/file_category.dart';

class CategoryFilterRow extends StatelessWidget {
  final FileCategory? selected;
  final void Function(FileCategory? category) onSelected;

  const CategoryFilterRow({super.key, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chip(context, label: 'All', isSelected: selected == null, onTap: () => onSelected(null)),
          const SizedBox(width: 8),
          for (final category in FileCategory.values) ...[
            _chip(
              context,
              label: category.label,
              isSelected: selected == category,
              onTap: () => onSelected(selected == category ? null : category),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
    );
  }
}
