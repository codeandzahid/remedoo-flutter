import 'package:flutter/material.dart';

/// Remidy form kit (UI redesign 2026-10-21) — ONE shared set of
/// form widgets for every data-entry surface: patient app, admin
/// panel and all partner panels. Presentation only: the kit never
/// changes a field's value, validation or save payload; it gives
/// every form the same elevated Remidy look:
///
///  * stacked label above every field (never a floating label —
///    the profile Language dropdown overlapped its floating label),
///  * a small leading icon inside the field,
///  * rounded (16) inputs with soft borders and a blue focus ring,
///  * error text under the field,
///  * fields grouped in white section cards with icon + heading,
///  * a slim black→blue brand header band with a pink strip,
///  * one filled brand-blue primary pill + one outlined Cancel,
///    both at least 48px tall; long forms pin actions in a
///    sticky bottom bar,
///  * selected states in brand colours, never solid black.
abstract final class RFormBrand {
  static const pink = Color(0xFFFD1A54);
  static const blue = Color(0xFF0E3EFE);
  static const green = Color(0xFF5D8E5E);
  static const canvas = Color(0xFFF5F6F7);
  static const ink = Color(0xFF141414);
  static const muted = Color(0xFF6E737C);
  static const border = Color(0xFFE7E9EC);
  static const lavender = Color(0xFF8A7CA8);

  /// The email-template header: black melting into electric blue.
  static const headerGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF0B0B12), Color(0xFF0E3EFE)],
  );
}

/// '09:30' / '9:05' / '21:05' → '9:30 AM' / '9:05 AM' / '9:05 PM'.
/// Values that are not plain HH:MM pass through untouched, and the
/// stored value is NEVER changed — display only, so booking chips
/// read the same 12-hour format as the doctor profile pages.
String rTime12(String value) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(value.trim());
  if (m == null) return value;
  var h = int.parse(m.group(1)!);
  final min = m.group(2)!;
  final suffix = h >= 12 ? 'PM' : 'AM';
  h = h % 12;
  if (h == 0) h = 12;
  return '$h:$min $suffix';
}

/// Slim brand header band for form screens and dialogs: gradient
/// black→blue with a 3px pink strip along the bottom, an optional
/// icon chip, the title and an optional subtitle.
class RFormHeaderBand extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool roundedTop;

  const RFormHeaderBand({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.roundedTop = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RFormBrand.headerGradient,
        borderRadius: roundedTop
            ? const BorderRadius.vertical(top: Radius.circular(20))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(height: 3, color: RFormBrand.pink),
        ],
      ),
    );
  }
}

/// White section card grouping related fields under a small
/// icon + heading. Children are spaced 16px apart.
class RFormSection extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  const RFormSection({
    super.key,
    this.title,
    this.icon,
    required this.children,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) spaced.add(const SizedBox(height: 16));
      spaced.add(children[i]);
    }
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RFormBrand.border),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: RFormBrand.blue.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, size: 16, color: RFormBrand.blue),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  title!,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          ...spaced,
        ],
      ),
    );
  }
}

/// Shared input decoration for the kit: white fill, radius 16,
/// soft border, blue focus ring, error text under the field.
InputDecoration rKitDecoration(
  BuildContext context, {
  String? hint,
  String? errorText,
  IconData? icon,
  Widget? suffixIcon,
  Widget? prefixIcon,
  String? counterText,
}) {
  final scheme = Theme.of(context).colorScheme;
  OutlineInputBorder side(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    hintText: hint,
    errorText: errorText,
    counterText: counterText,
    hintStyle: const TextStyle(color: RFormBrand.muted, fontSize: 14),
    filled: true,
    // Ambient fill wins (patient theme card colour, or the active
    // admin style's input fill) so the kit sits naturally on every
    // surface; the kit owns the shape, borders and focus ring.
    fillColor:
        Theme.of(context).inputDecorationTheme.fillColor ?? scheme.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    prefixIcon: prefixIcon ??
        (icon != null
            ? Icon(icon, size: 20, color: RFormBrand.blue)
            : null),
    suffixIcon: suffixIcon,
    border: side(RFormBrand.border, 1),
    enabledBorder: side(RFormBrand.border, 1),
    focusedBorder: side(RFormBrand.blue, 1.6),
    errorBorder: side(RFormBrand.pink, 1.2),
    focusedErrorBorder: side(RFormBrand.pink, 1.6),
    disabledBorder: side(RFormBrand.border.withValues(alpha: 0.6), 1),
  );
}

/// The kit text field: STACKED label above (icon + text), then the
/// input. Same value/validation contract as the old RTextField —
/// drop-in presentation upgrade.
class RKitField extends StatelessWidget {
  final String? label;
  final IconData? labelIcon;

  /// Leading icon rendered INSIDE the field.
  final IconData? icon;
  final String? hint;
  final TextEditingController? controller;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final String? errorText;
  final TextInputAction? textInputAction;
  final int? maxLength;
  final bool autofocus;

  const RKitField({
    super.key,
    this.label,
    this.labelIcon,
    this.icon,
    this.hint,
    this.controller,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
    this.onChanged,
    this.suffixIcon,
    this.prefixIcon,
    this.errorText,
    this.textInputAction,
    this.maxLength,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Row(
            children: [
              if (labelIcon != null) ...[
                Icon(labelIcon, size: 14, color: RFormBrand.blue),
                const SizedBox(width: 6),
              ],
              Text(
                label!,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          enabled: enabled,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLines: maxLines,
          minLines: minLines,
          maxLength: maxLength,
          autofocus: autofocus,
          textInputAction: textInputAction,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14.5),
          decoration: rKitDecoration(
            context,
            hint: hint,
            errorText: errorText,
            icon: icon,
            suffixIcon: suffixIcon,
            prefixIcon: prefixIcon,
            // Length-counted fields (OTP, UTR) keep their counter
            // hidden, as the raw fields did before the kit.
            counterText: maxLength != null ? '' : null,
          ),
        ),
      ],
    );
  }
}

/// The kit dropdown: STACKED label above a DropdownButtonFormField
/// wearing the same decoration as RKitField — this replaces the
/// floating-label dropdowns whose labels overlapped the value.
class RKitDropdown<T> extends StatelessWidget {
  final String? label;
  final IconData? labelIcon;
  final IconData? icon;
  final String? hint;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? errorText;
  final bool enabled;

  const RKitDropdown({
    super.key,
    this.label,
    this.labelIcon,
    this.icon,
    this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Row(
            children: [
              if (labelIcon != null) ...[
                Icon(labelIcon, size: 14, color: RFormBrand.blue),
                const SizedBox(width: 6),
              ],
              Text(
                label!,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: enabled ? onChanged : null,
          isExpanded: true,
          style: const TextStyle(fontSize: 14.5, color: RFormBrand.ink),
          decoration: rKitDecoration(
            context,
            hint: hint,
            errorText: errorText,
            icon: icon,
          ),
        ),
      ],
    );
  }
}

/// The one action pair every form ends with: an outlined Cancel
/// (a real button, never a bare text link) beside a filled
/// brand-blue primary pill. Both are at least 48px tall.
class RFormActions extends StatelessWidget {
  final VoidCallback? onCancel;
  final VoidCallback? onPrimary;
  final String primaryLabel;
  final String cancelLabel;
  final Color? primaryColor;
  final bool primaryEnabled;

  const RFormActions({
    super.key,
    this.onCancel,
    required this.onPrimary,
    required this.primaryLabel,
    this.cancelLabel = 'Cancel',
    this.primaryColor,
    this.primaryEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onCancel != null) ...[
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: RFormBrand.ink,
                  side: const BorderSide(color: RFormBrand.border, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  textStyle: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
                child: Text(cancelLabel),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: primaryEnabled ? onPrimary : null,
              style: FilledButton.styleFrom(
                backgroundColor: primaryColor ?? RFormBrand.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                textStyle: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
              child: Text(primaryLabel),
            ),
          ),
        ),
      ],
    );
  }
}

/// Sticky bottom action bar for long forms: white bar, hairline
/// top border, safe-area padding, hosts an RFormActions (or any
/// action row) so Save is always reachable.
class RStickyActionBar extends StatelessWidget {
  final Widget child;

  const RStickyActionBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: const Border(top: BorderSide(color: RFormBrand.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: child,
        ),
      ),
    );
  }
}

/// Label + brand switch row for use inside an RFormSection.
class RFormSwitchTile extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const RFormSwitchTile({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: RFormBrand.blue),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w600)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!,
                    style: const TextStyle(
                        fontSize: 12.5, color: RFormBrand.muted)),
              ],
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: RFormBrand.blue,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: const Color(0xFFD8DBE0),
        ),
      ],
    );
  }
}

/// Quick-pick label chips (Home / Office / Other style): selected
/// chip is brand blue with white text, never solid black.
class RLabelChips extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  const RLabelChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final sel = o == selected;
        return ChoiceChip(
          label: Text(o),
          selected: sel,
          onSelected: (_) => onSelected(o),
          selectedColor: RFormBrand.blue,
          backgroundColor: Colors.white,
          side: BorderSide(
              color: sel ? RFormBrand.blue : RFormBrand.border, width: 1.2),
          labelStyle: TextStyle(
            color: sel ? Colors.white : RFormBrand.ink,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }).toList(),
    );
  }
}
