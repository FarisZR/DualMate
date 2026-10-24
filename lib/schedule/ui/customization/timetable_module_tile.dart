import 'package:flutter/material.dart';

class TimetableModuleTile extends StatelessWidget {
  final String title;
  final bool selected;
  final ValueChanged<bool> onChanged;
  const TimetableModuleTile({
    super.key,
    required this.title,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: title,
      checked: selected,
      enabled: true,
      child: Material(
        color: selected
            ? colors.primary.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? .20
                    : .08,
              )
            : colors.onSurface.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onChanged(!selected),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Expanded(
                  child: ExcludeSemantics(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ExcludeSemantics(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      key: ValueKey(selected),
                      color: selected
                          ? colors.primary
                          : colors.onSurfaceVariant,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
