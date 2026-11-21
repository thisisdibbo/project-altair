import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../motion/motion.dart';
import '../theme/palette.dart';
import 'buttons.dart';

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 7),
    child: Text(text.toUpperCase(), style: T.label(context)),
  );
}

class AltairTextField extends StatelessWidget {
  const AltairTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.validator,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.onChanged,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: c, width: w),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(label),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          maxLines: obscure ? 1 : maxLines,
          minLines: minLines,
          maxLength: maxLength,
          validator: validator,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          onFieldSubmitted: onSubmitted,
          onChanged: onChanged,
          enabled: enabled,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          style: T.strong(context).copyWith(fontWeight: FontWeight.w500),
          cursorColor: p.accent,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: T.body(context).copyWith(color: p.textFaint),
            prefixIcon: icon == null
                ? null
                : Icon(icon, size: 20, color: p.textFaint),
            suffixIcon: suffix,
            counterText: '',
            filled: true,
            fillColor: p.surfaceHigh.withValues(alpha: p.isDark ? 0.55 : 0.9),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            border: border(p.line),
            enabledBorder: border(p.line),
            disabledBorder: border(p.line),
            focusedBorder: border(p.accent, 1.4),
            errorBorder: border(p.ember),
            focusedErrorBorder: border(p.ember, 1.4),
            errorStyle: T.small(context).copyWith(color: p.ember),
            errorMaxLines: 2,
          ),
        ),
      ],
    );
  }
}

/// Looks like a text field but opens a picker when tapped.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.icon,
    this.placeholder = 'Select',
    this.errorText,
    this.onClear,
  });

  final String label;
  final String? value;
  final VoidCallback? onTap;
  final IconData? icon;
  final String placeholder;
  final String? errorText;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final has = value != null && value!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(label),
        PressScale(
          onTap: onTap,
          scale: 0.985,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: p.surfaceHigh.withValues(alpha: p.isDark ? 0.55 : 0.9),
              border: Border.all(color: errorText != null ? p.ember : p.line),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: p.textFaint),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    has ? value! : placeholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: has
                        ? T.strong(
                            context,
                          ).copyWith(fontWeight: FontWeight.w500)
                        : T.body(context).copyWith(color: p.textFaint),
                  ),
                ),
                if (has && onClear != null)
                  GestureDetector(
                    onTap: onClear,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: p.textFaint,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.expand_more_rounded,
                    size: 22,
                    color: p.textFaint,
                  ),
              ],
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 6, top: 6),
            child: Text(
              errorText!,
              style: T.small(context).copyWith(color: p.ember),
            ),
          ),
      ],
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'Search',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        color: p.surfaceHigh.withValues(alpha: p.isDark ? 0.55 : 0.95),
        border: Border.all(color: p.line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: p.textFaint),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              style: T.strong(context).copyWith(fontWeight: FontWeight.w500),
              cursorColor: p.accent,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: T.body(context).copyWith(color: p.textFaint),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      controller.clear();
                      onChanged('');
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: p.textFaint,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = selected ? p.accentText : p.textMuted;
    return PressScale(
      onTap: () {
        Haptics.select();
        onTap();
      },
      haptic: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: selected
              ? p.accent.withValues(alpha: 0.16)
              : p.surfaceHigh.withValues(alpha: p.isDark ? 0.5 : 0.95),
          border: Border.all(
            color: selected ? p.accent.withValues(alpha: 0.7) : p.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 170),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.small(
                    context,
                  ).copyWith(fontWeight: FontWeight.w700, color: fg),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Segmented<V> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<(V, String)> options;
  final V selected;
  final ValueChanged<V> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: p.surfaceHigh.withValues(alpha: p.isDark ? 0.5 : 0.95),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: PressScale(
                scale: 0.97,
                haptic: false,
                onTap: () {
                  Haptics.select();
                  onChanged(option.$1);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: option.$1 == selected
                        ? p.accent
                        : p.accent.withValues(alpha: 0),
                  ),
                  child: Text(
                    option.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: option.$1 == selected ? p.onAccent : p.textMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AltairSwitch extends StatelessWidget {
  const AltairSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null
            ? null
            : () {
                Haptics.select();
                onChanged!(!value);
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 50,
          height: 30,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: value ? p.accent : p.surfaceHigh,
            border: Border.all(color: value ? p.accent : p.line),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? p.onAccent : p.textFaint,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tint = danger ? p.ember : p.accentText;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: tint.withValues(alpha: 0.14),
            ),
            child: Icon(icon, size: 20, color: tint),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: T.strong(
                    context,
                  ).copyWith(color: danger ? p.ember : p.text),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: T.small(context)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing ??
              (onTap == null
                  ? const SizedBox.shrink()
                  : Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: p.textFaint,
                    )),
        ],
      ),
    );
    if (onTap == null) return row;
    return PressScale(onTap: onTap, scale: 0.985, child: row);
  }
}
