import 'package:flutter/material.dart';

import 'theme.dart';

Palette paletteOf(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? AppColors.dark
    : AppColors.light;

/// Layout and card spacing follow Kikoeta's dictation translation page.
class KtPage extends StatelessWidget {
  final String title;
  final String? description;
  final List<Widget> actions;
  final List<Widget> children;
  final List<Widget>? secondaryChildren;
  final Widget? footer;
  final bool columns;

  const KtPage({
    super.key,
    required this.title,
    this.description,
    this.actions = const [],
    required this.children,
    this.secondaryChildren,
    this.footer,
    this.columns = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final allChildren = [...children, ...?secondaryChildren];
        final wide =
            columns && constraints.maxWidth >= 900 && allChildren.length > 1;
        Widget column(Iterable<Widget> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, item) in items.indexed) ...[
              if (index != 0) const SizedBox(height: 14),
              item,
            ],
          ],
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: ListView(
                primary: false,
                padding: EdgeInsets.zero,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: p.text,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (actions.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 6,
                            runSpacing: 6,
                            children: actions,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      description!,
                      style: TextStyle(
                        color: p.muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: column(
                            secondaryChildren != null
                                ? children
                                : [
                                    for (var i = 0; i < children.length; i += 2)
                                      children[i],
                                  ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: column(
                            secondaryChildren ??
                                [
                                  for (var i = 1; i < children.length; i += 2)
                                    children[i],
                                ],
                          ),
                        ),
                      ],
                    )
                  else
                    for (final (index, item) in allChildren.indexed) ...[
                      if (index != 0) const SizedBox(height: 14),
                      item,
                    ],
                  if (footer != null) ...[const SizedBox(height: 14), footer!],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class KtSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? action;

  const KtSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return Material(
      color: p.surface,
      animationDuration: Duration.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 19, color: p.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

InputDecoration ktInputDecoration(
  BuildContext context,
  String label, {
  String? hint,
}) {
  final p = paletteOf(context);
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(11),
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(
      fontFamily: 'SarasaUI',
      fontSize: 11.5,
      color: p.muted,
    ),
    hintText: hint,
    hintStyle: TextStyle(fontFamily: 'SarasaUI', fontSize: 12, color: p.dim),
    filled: true,
    fillColor: p.surface2,
    border: border(p.line),
    enabledBorder: border(p.line),
    disabledBorder: border(p.line),
    focusedBorder: border(p.accent),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  );
}

class KtRow extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? sub;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  const KtRow({
    super.key,
    this.icon,
    required this.title,
    this.sub,
    this.trailing,
    this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final content = Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: showDivider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: p.line)),
            )
          : null,
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: p.surface2,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 17, color: p.accent),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(sub!, style: TextStyle(fontSize: 11, color: p.dim)),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

class KtSwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;
  final bool enabled;

  const KtSwitchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.sub,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return KtRow(
      icon: icon,
      title: title,
      sub: sub,
      showDivider: showDivider,
      onTap: enabled ? () => onChanged(!value) : null,
      trailing: Switch(
        value: value,
        onChanged: enabled ? onChanged : null,
        activeTrackColor: p.accent,
      ),
    );
  }
}

class KtField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  final int maxLines;

  const KtField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscure = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        maxLines: obscure ? 1 : maxLines,
        style: TextStyle(fontFamily: 'SarasaUI', fontSize: 13, color: p.text),
        decoration: ktInputDecoration(context, label, hint: hint),
      ),
    );
  }
}

class KtChoiceRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final bool selected;
  final VoidCallback onTap;
  final bool showDivider;

  const KtChoiceRow({
    super.key,
    required this.icon,
    required this.title,
    required this.sub,
    required this.selected,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return KtRow(
      icon: icon,
      title: title,
      sub: sub,
      showDivider: showDivider,
      onTap: onTap,
      trailing: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        size: 20,
        color: selected ? p.accent : p.dim,
      ),
    );
  }
}

class KtComboField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final List<String> options;
  final Map<String, String>? labels;
  final ValueChanged<String>? onChanged;

  const KtComboField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.options = const [],
    this.labels,
    this.onChanged,
  });

  @override
  State<KtComboField> createState() => _KtComboFieldState();
}

class _KtComboFieldState extends State<KtComboField> {
  final MenuController _menu = MenuController();

  List<String> _visible() {
    final text = widget.controller.text.trim();
    if (text.isEmpty || widget.options.contains(text)) {
      return widget.options;
    }
    final query = text.toLowerCase();
    return [
      for (final option in widget.options)
        if (_match(option, query)) option,
    ];
  }

  bool _match(String option, String query) {
    final label = widget.labels?[option] ?? option;
    return option.toLowerCase().contains(query) ||
        label.toLowerCase().contains(query);
  }

  String _labelOf(String option) => widget.labels?[option] ?? option;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final visible = _visible();
    final hasOptions = widget.options.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: MenuAnchor(
        controller: _menu,
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(p.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shadowColor: WidgetStatePropertyAll(
            Colors.black.withValues(alpha: .28),
          ),
          elevation: const WidgetStatePropertyAll(14),
          minimumSize: const WidgetStatePropertyAll(Size(280, 0)),
          maximumSize: const WidgetStatePropertyAll(Size(420, 360)),
          side: WidgetStatePropertyAll(BorderSide(color: p.border)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          ),
        ),
        menuChildren: [
          for (final option in visible)
            MenuItemButton(
              style: ButtonStyle(
                minimumSize: const WidgetStatePropertyAll(Size(0, 42)),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 12),
                ),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                foregroundColor: WidgetStatePropertyAll(p.text),
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(
                    fontFamily: 'SarasaUI',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                overlayColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.pressed)) {
                    return p.accent.withValues(alpha: .18);
                  }
                  if (states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.focused)) {
                    return p.accent.withValues(alpha: .10);
                  }
                  return Colors.transparent;
                }),
              ),
              onPressed: () {
                widget.controller.text = option;
                widget.onChanged?.call(option);
                _menu.close();
                setState(() {});
              },
              child: SizedBox(
                width: 320,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _labelOf(option),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.controller.text.trim() == option)
                      Icon(Icons.check_rounded, size: 18, color: p.accent),
                  ],
                ),
              ),
            ),
        ],
        builder: (_, menuController, _) => TextField(
          controller: widget.controller,
          style: TextStyle(fontFamily: 'SarasaUI', color: p.text, fontSize: 13),
          onChanged: (value) {
            widget.onChanged?.call(value);
            if (menuController.isOpen) setState(() {});
          },
          decoration:
              ktInputDecoration(
                context,
                widget.label,
                hint: widget.hint ?? (hasOptions ? '输入或从列表选择' : null),
              ).copyWith(
                suffixIcon: IconButton(
                  tooltip: hasOptions ? '打开列表' : '暂无预置选项，可直接输入',
                  iconSize: 21,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  onPressed: hasOptions
                      ? () {
                          if (menuController.isOpen) {
                            menuController.close();
                          } else {
                            menuController.open();
                          }
                          setState(() {});
                        }
                      : null,
                  icon: Icon(
                    menuController.isOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: hasOptions ? p.muted : p.dim,
                  ),
                ),
              ),
        ),
      ),
    );
  }
}

class KtSelectField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) labelOf;
  final ValueChanged<T> onChanged;

  const KtSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final current = values.contains(value) ? value : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InputDecorator(
        decoration: ktInputDecoration(context, label).copyWith(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            isExpanded: true,
            value: current,
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: p.muted),
            iconSize: 21,
            dropdownColor: p.surface,
            focusColor: Colors.transparent,
            elevation: 12,
            borderRadius: BorderRadius.circular(11),
            itemHeight: 48,
            menuMaxHeight: 360,
            style: TextStyle(
              fontFamily: 'SarasaUI',
              fontSize: 13,
              color: p.text,
            ),
            items: [
              for (final item in values)
                DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    labelOf(item),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'SarasaUI',
                      color: p.text,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ),
      ),
    );
  }
}
