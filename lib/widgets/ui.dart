import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';

// ---------------------------------------------------------------- buttons

enum BtnKind { primary, gold, ghost, soft, danger }

class LvButton extends StatelessWidget {
  const LvButton(this.label, {super.key, this.onTap, this.icon, this.kind = BtnKind.primary, this.small = false, this.busy = false, this.expand = true});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final BtnKind kind;
  final bool small;
  final bool busy;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (kind) {
      BtnKind.primary => (C.dark, Colors.white, null),
      BtnKind.gold => (C.gold, C.ink, null),
      BtnKind.ghost => (Colors.white, C.ink, C.line),
      BtnKind.soft => (C.mint, C.tealDeep, null),
      BtnKind.danger => (Colors.white, C.bad, const Color(0xFFECC9C5)),
    };
    final disabled = onTap == null || busy;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
        else if (icon != null)
          Icon(icon, size: small ? 17 : 20, color: fg),
        if (busy || icon != null) const SizedBox(width: 8),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontWeight: FontWeight.w500, fontSize: small ? 13 : 15))),
      ],
    );
    return Opacity(
      opacity: disabled && !busy ? .45 : 1,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(small ? 11 : 16), side: border == null ? BorderSide.none : BorderSide(color: border)),
        child: InkWell(
          borderRadius: BorderRadius.circular(small ? 11 : 16),
          onTap: disabled ? null : onTap,
          child: Container(height: small ? 36 : 52, padding: EdgeInsets.symmetric(horizontal: small ? 14 : 20), alignment: Alignment.center, child: child),
        ),
      ),
    );
  }
}

class LinkText extends StatelessWidget {
  const LinkText(this.text, {super.key, this.onTap, this.size = 14});
  final String text;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2), child: Text(text, style: TextStyle(color: C.dark, fontWeight: FontWeight.w500, fontSize: size))),
      );
}

class CircleIconButton extends StatelessWidget {
  const CircleIconButton(this.icon, {super.key, this.onTap, this.onDark = false, this.dot = false, this.count = 0, this.boxed = false});
  final IconData icon;
  final VoidCallback? onTap;
  final bool onDark;
  final bool dot;
  final int count;
  final bool boxed;

  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
        Material(
          color: onDark ? Colors.white.withValues(alpha: .12) : (boxed ? Colors.white : Colors.transparent),
          shape: CircleBorder(side: boxed ? const BorderSide(color: C.line) : BorderSide.none),
          child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: SizedBox(width: 42, height: 42, child: Icon(icon, color: onDark ? Colors.white : C.ink, size: 22))),
        ),
        if (count > 0)
          Positioned(right: -2, top: -2, child: CountBubble(count))
        else if (dot)
          Positioned(right: 10, top: 9, child: Container(width: 9, height: 9, decoration: BoxDecoration(color: C.gold, shape: BoxShape.circle, border: Border.all(color: onDark ? C.dark : Colors.white, width: 2)))),
      ]);
}

class CountBubble extends StatelessWidget {
  const CountBubble(this.n, {super.key});
  final int n;
  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 18),
        height: 18,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white, width: 2)),
        alignment: Alignment.center,
        child: Text(n > 99 ? '99+' : '$n', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: C.ink)),
      );
}

// ---------------------------------------------------------------- surfaces

class LvCard extends StatelessWidget {
  const LvCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color = Colors.white, this.borderColor = C.line, this.radius = 20, this.margin});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color color;
  final Color borderColor;
  final double radius;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) => Padding(
        padding: margin ?? EdgeInsets.zero,
        child: Material(
          color: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: BorderSide(color: borderColor)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
        ),
      );
}

/// White rounded list with dividers (`.list` + `.li`).
class LvList extends StatelessWidget {
  const LvList({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LvCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const Divider(height: 1, color: C.line), children[i]],
        ]),
      );
}

class LvTile extends StatelessWidget {
  const LvTile({super.key, this.icon, this.iconTone = Tone.teal, required this.title, this.subtitle, this.trailing, this.onTap, this.leading});
  final IconData? icon;
  final Tone iconTone;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)] else if (icon != null) ...[IconBox(icon!, tone: iconTone, small: true), const SizedBox(width: 12)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14.5)),
                if (subtitle != null && subtitle!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: const TextStyle(color: C.muted, fontSize: 12.5))),
              ]),
            ),
            if (trailing != null) trailing! else if (onTap != null) const Icon(Icons.chevron_right_rounded, color: Color(0xFFC4C3C0)),
          ]),
        ),
      );
}

enum Tone { teal, gold, grey, ok, warn, bad }

(Color, Color) toneColors(Tone t) => switch (t) {
      Tone.teal => (C.mint, C.tealDeep),
      Tone.gold => (C.goldSoft, C.goldInk),
      Tone.grey => (const Color(0xFFEFEEEC), C.muted),
      Tone.ok => (C.okSoft, C.ok),
      Tone.warn => (C.warnSoft, C.warn),
      Tone.bad => (C.badSoft, C.bad),
    };

class IconBox extends StatelessWidget {
  const IconBox(this.icon, {super.key, this.tone = Tone.teal, this.small = false, this.size});
  final IconData icon;
  final Tone tone;
  final bool small;
  final double? size;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = toneColors(tone);
    final s = size ?? (small ? 36.0 : 42.0);
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(s * .31)),
      child: Icon(icon, color: fg, size: s * .52),
    );
  }
}

/// Status badge — colour follows the status word like the design (`.badge.approved` etc.).
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.tone, this.icon});
  final String text;
  final Tone? tone;
  final IconData? icon;

  static Tone toneOf(String s) {
    const ok = {'approved', 'paid', 'delivered', 'resolved', 'active', 'available', 'completed', 'ordered', 'enrolled', 'issued', 'graded', 'accepted', 'rewarded'};
    const warn = {'pending', 'placed', 'confirmed', 'preparing', 'ready', 'in_review', 'unpaid', 'medium', 'in_surgery', 'submitted', 'pending_payment', 'refund_due'};
    const bad = {'declined', 'open', 'high', 'rejected', 'failed', 'returned', 'void', 'expired'};
    const grey = {'cancelled', 'off_today', 'on_leave', 'low', 'used', 'redeemed', 'refunded', 'withdrawn'};
    final k = s.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
    if (ok.contains(k)) return Tone.ok;
    if (warn.contains(k)) return Tone.warn;
    if (bad.contains(k)) return Tone.bad;
    if (grey.contains(k)) return Tone.grey;
    if (k == 'sent' || k == 'new') return Tone.gold;
    return Tone.teal;
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = toneColors(tone ?? toneOf(text));
    final label = text.replaceAll('_', ' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
        Text(label.isEmpty ? label : label[0].toUpperCase() + label.substring(1), style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class Banner2 extends StatelessWidget {
  const Banner2({super.key, required this.text, this.icon = Icons.info_outline_rounded, this.tone = Tone.teal, this.onTap, this.trailing});
  final Widget text;
  final IconData icon;
  final Tone tone;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      Tone.gold => (C.goldSoft, const Color(0xFF7A5440)),
      Tone.warn => (C.warnSoft, C.warnInk),
      _ => toneColors(tone),
    };
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(width: 12),
            Expanded(child: DefaultTextStyle(style: TextStyle(color: fg, fontSize: 13, height: 1.45), child: text)),
            if (trailing != null) trailing!,
          ]),
        ),
      ),
    );
  }
}

/// Teal radial header with the Lavish pattern (`.teal-head`).
class TealHeader extends StatelessWidget {
  const TealHeader({super.key, required this.child, this.padding, this.radius = 30});
  final Widget child;
  final EdgeInsets? padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ClipRRect(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(radius)),
      child: Container(
        decoration: const BoxDecoration(gradient: tealGradient),
        child: Stack(children: [
          Positioned.fill(child: Opacity(opacity: .12, child: Image.asset('assets/img/pattern.png', repeat: ImageRepeat.repeat, fit: BoxFit.none, scale: 1.6))),
          SizedBox(
            width: double.infinity,
            child: Padding(padding: padding ?? EdgeInsets.fromLTRB(20, top + 14, 20, 22), child: DefaultTextStyle(style: const TextStyle(color: Colors.white), child: child)),
          ),
        ]),
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.size = 46, this.hue, this.url, this.online = false, this.ring = false});
  final String name;
  final double size;
  final num? hue;
  final String? url;
  final bool online;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final h = (hue ?? (name.codeUnits.fold<int>(0, (a, b) => a + b) * 37 % 360)).toDouble();
    final bg = HSLColor.fromAHSL(1, h, .38, .42).toColor();
    final bg2 = HSLColor.fromAHSL(1, h, .45, .30).toColor();
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [bg, bg2], begin: Alignment.topLeft, end: Alignment.bottomRight),
          border: ring ? Border.all(color: C.gold.withValues(alpha: .7), width: 4) : null,
          image: url != null && url!.isNotEmpty ? DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover) : null,
        ),
        alignment: Alignment.center,
        child: url != null && url!.isNotEmpty ? null : Text(initials(name), style: serif(size * .38, color: Colors.white)),
      ),
      if (online)
        Positioned(
          right: 1,
          bottom: 1,
          child: Container(width: size * .28, height: size * .28, decoration: BoxDecoration(color: const Color(0xFF3FBF7F), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
        ),
    ]);
  }
}

// ---------------------------------------------------------------- text bits

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction, this.top = 26});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final double top;
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: top, bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Text(title, style: serif(21))),
          if (action != null) LinkText(action!, onTap: onAction, size: 13),
        ]),
      );
}

class Label extends StatelessWidget {
  const Label(this.text, {super.key, this.color = C.muted});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: color, fontWeight: FontWeight.w500));
}

class Muted extends StatelessWidget {
  const Muted(this.text, {super.key, this.size = 13, this.align, this.maxLines});
  final String text;
  final double size;
  final TextAlign? align;
  final int? maxLines;
  @override
  Widget build(BuildContext context) => Text(text, textAlign: align, maxLines: maxLines, overflow: maxLines == null ? null : TextOverflow.ellipsis, style: TextStyle(color: C.muted, fontSize: size, height: 1.4));
}

class KV extends StatelessWidget {
  const KV(this.k, this.v, {super.key, this.total = false, this.valueColor});
  final String k;
  final String v;
  final bool total;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: const TextStyle(color: C.muted, fontSize: 14)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(v,
                textAlign: TextAlign.right,
                style: total ? serif(22, color: valueColor) : TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: valueColor ?? C.ink)),
          ),
        ]),
      );
}

class DashedDivider extends StatelessWidget {
  const DashedDivider({super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, c) => Row(
          children: List.generate((c.maxWidth / 6).floor(), (i) => Expanded(child: Container(height: 1, color: i.isEven ? C.line : Colors.transparent))),
        ),
      );
}

/// Key–value rows separated by dashed lines.
class KVList extends StatelessWidget {
  const KVList(this.rows, {super.key});
  final List<KV> rows;
  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < rows.length; i++) ...[if (i > 0) const DashedDivider(), rows[i]],
      ]);
}

class Empty extends StatelessWidget {
  const Empty({super.key, required this.icon, required this.title, this.text, this.action, this.onAction});
  final IconData icon;
  final String title;
  final String? text;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 50),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 54, color: const Color(0xFFB9CFCB)),
          const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center, style: serif(21)),
          if (text != null) ...[const SizedBox(height: 4), Muted(text!, align: TextAlign.center, size: 13.5)],
          if (action != null) ...[const SizedBox(height: 18), LvButton(action!, onTap: onAction, expand: false)],
        ]),
      );
}

// ---------------------------------------------------------------- inputs

class Field extends StatelessWidget {
  const Field({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.icon,
    this.prefixText,
    this.obscure = false,
    this.keyboard,
    this.maxLines = 1,
    this.suffix,
    this.onChanged,
    this.inputFormatters,
    this.enabled = true,
    this.textInputAction,
    this.onSubmitted,
    this.autofocus = false,
  });
  final String label;
  final TextEditingController? controller;
  final String? hint;
  final IconData? icon;
  final String? prefixText;
  final bool obscure;
  final TextInputType? keyboard;
  final int maxLines;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (label.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(label, style: const TextStyle(fontSize: 12.5, color: C.muted, fontWeight: FontWeight.w500))),
          TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboard,
            maxLines: obscure ? 1 : maxLines,
            onChanged: onChanged,
            enabled: enabled,
            autofocus: autofocus,
            inputFormatters: inputFormatters,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: prefixText != null
                  ? Padding(
                      padding: const EdgeInsets.only(left: 14, right: 10),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(prefixText!, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                        const SizedBox(width: 10),
                        Container(width: 1, height: 22, color: C.line),
                      ]),
                    )
                  : icon != null
                      ? Icon(icon, color: C.muted, size: 20)
                      : null,
              suffixIcon: suffix,
            ),
          ),
        ]),
      );
}

/// Password field with the eye toggle.
class PasswordField extends StatefulWidget {
  const PasswordField({super.key, required this.label, required this.controller, this.hint, this.onSubmitted});
  final String label;
  final TextEditingController controller;
  final String? hint;
  final ValueChanged<String>? onSubmitted;
  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool hidden = true;
  @override
  Widget build(BuildContext context) => Field(
        label: widget.label,
        controller: widget.controller,
        hint: widget.hint,
        icon: Icons.lock_outline_rounded,
        obscure: hidden,
        onSubmitted: widget.onSubmitted,
        suffix: IconButton(icon: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: C.muted, size: 20), onPressed: () => setState(() => hidden = !hidden)),
      );
}

/// Segmented control (`.seg`).
class Seg<T> extends StatelessWidget {
  const Seg({super.key, required this.items, required this.value, required this.onChanged});
  final List<(T, String)> items;
  final T value;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: C.seg, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          for (final (v, l) in items)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: v == value ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: v == value ? [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 4, offset: const Offset(0, 1))] : null,
                  ),
                  child: Text(l, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5, color: v == value ? C.ink : C.muted)),
                ),
              ),
            ),
        ]),
      );
}

/// Horizontal filter chips (`.chips`).
class ChipBar<T> extends StatelessWidget {
  const ChipBar({super.key, required this.items, required this.value, required this.onChanged});
  final List<(T, String)> items;
  final T value;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final (v, l) = items[i];
            final on = v == value;
            return Material(
              color: on ? C.dark : Colors.white,
              shape: StadiumBorder(side: BorderSide(color: on ? C.dark : C.line)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => onChanged(v),
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9), child: Text(l, style: TextStyle(fontSize: 13, color: on ? Colors.white : C.ink))),
              ),
            );
          },
        ),
      );
}

/// Selectable card with a radio dot (`.radio-card`).
class RadioCard extends StatelessWidget {
  const RadioCard({super.key, required this.selected, required this.title, this.subtitle, this.onTap, this.leading, this.trailing, this.enabled = true});
  final bool selected;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: enabled ? 1 : .5,
        child: Material(
          color: selected ? const Color(0xFFF2F8F7) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: selected ? C.dark : C.line, width: 1.5)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected ? C.dark : const Color(0xFFCFCDCA), width: selected ? 6 : 2)),
                ),
                const SizedBox(width: 12),
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                    if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: const TextStyle(color: C.muted, fontSize: 12))),
                  ]),
                ),
                if (trailing != null) trailing!,
              ]),
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------------- page scaffolding

/// App bar matching the design: serif title, optional subtitle, back arrow on pushed screens.
PreferredSizeWidget lvAppBar(BuildContext context, String title, {String? subtitle, List<Widget>? actions, bool white = false}) => AppBar(
      backgroundColor: white ? Colors.white : C.bg,
      shape: white ? const Border(bottom: BorderSide(color: C.line)) : null,
      titleSpacing: Navigator.of(context).canPop() ? 0 : 20,
      toolbarHeight: subtitle == null ? 60 : 68,
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: serif(Navigator.of(context).canPop() ? 25 : 30), overflow: TextOverflow.ellipsis),
        if (subtitle != null) Text(subtitle, style: GoogleFonts.roboto(fontSize: 12, color: C.muted)),
      ]),
      actions: [...?actions, const SizedBox(width: 8)],
    );

/// Bottom action bar (`.foot`).
class FootBar extends StatelessWidget {
  const FootBar({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.line))),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
        child: child,
      );
}

/// Loads data with a spinner, an error card with Retry, and pull-to-refresh.
class Loader<T> extends StatefulWidget {
  const Loader({super.key, required this.load, required this.builder, this.empty});
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;
  final Widget? empty;

  @override
  State<Loader<T>> createState() => LoaderState<T>();
}

class LoaderState<T> extends State<Loader<T>> {
  T? data;
  Object? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final d = await widget.load();
      if (!mounted) return;
      setState(() {
        data = d;
        error = null;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading && data == null) return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: C.dark, strokeWidth: 2.4)));
    if (error != null && data == null) {
      return ErrorBox(error: error!, onRetry: () {
        setState(() => loading = true);
        reload();
      });
    }
    return RefreshIndicator(color: C.dark, onRefresh: reload, child: widget.builder(context, data as T, reload));
  }
}

class ErrorBox extends StatelessWidget {
  const ErrorBox({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Empty(
          icon: error is ApiException && (error as ApiException).code == 'offline' ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
          title: error is ApiException && (error as ApiException).code == 'offline' ? 'You’re offline' : 'Couldn’t load this',
          text: error.toString(),
          action: onRetry == null ? null : 'Try again',
          onAction: onRetry,
        ),
      );
}

// ---------------------------------------------------------------- feedback

void toast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline_rounded : Icons.check_circle_rounded, color: error ? const Color(0xFFF2B8B2) : C.gold, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ]),
    ));
}

/// Shows an API error (or any error) as a toast.
void showError(BuildContext context, Object e) => toast(context, e is ApiException ? e.friendly : 'Something went wrong. Please try again.', error: true);

/// Confirmation dialog — every action that changes something asks first.
Future<bool> confirm(BuildContext context, {required String title, String? body, String ok = 'Confirm', bool danger = false, String cancel = 'Cancel'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: Icon(danger ? Icons.warning_amber_rounded : Icons.help_outline_rounded, color: danger ? C.bad : C.dark, size: 30),
      title: Text(title, textAlign: TextAlign.center, style: serif(22)),
      content: body == null ? null : Text(body, textAlign: TextAlign.center, style: const TextStyle(color: C.muted, height: 1.45)),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        // Stacked full-width buttons so longer labels ("Continue to pay") never get cut off.
        Column(mainAxisSize: MainAxisSize.min, children: [
          LvButton(ok, kind: danger ? BtnKind.danger : BtnKind.primary, onTap: () => Navigator.pop(c, true)),
          const SizedBox(height: 8),
          LvButton(cancel, kind: BtnKind.ghost, onTap: () => Navigator.pop(c, false)),
        ]),
      ],
    ),
  );
  return r == true;
}

/// Asks for a short text (reason, review…). Returns null when cancelled.
Future<String?> promptText(BuildContext context, {required String title, String? hint, String ok = 'Send', int maxLines = 3}) async {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title, style: serif(22)),
      content: TextField(controller: ctrl, maxLines: maxLines, autofocus: true, decoration: InputDecoration(hintText: hint)),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        Row(children: [
          Expanded(child: LvButton('Cancel', kind: BtnKind.ghost, onTap: () => Navigator.pop(c))),
          const SizedBox(width: 10),
          Expanded(child: LvButton(ok, onTap: () => Navigator.pop(c, ctrl.text.trim()))),
        ]),
      ],
    ),
  );
}

/// On screens whose teal header runs under the phone's status bar: once the page is scrolled past the
/// header, a light strip appears behind the clock/battery so content never shows through it.
class StatusBarScrim extends StatefulWidget {
  const StatusBarScrim({super.key, required this.child, this.after = 120});
  final Widget child;
  final double after;
  @override
  State<StatusBarScrim> createState() => _StatusBarScrimState();
}

class _StatusBarScrimState extends State<StatusBarScrim> {
  bool on = false;
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: on ? SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent) : SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Stack(children: [
        NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.depth == 0) {
              final v = n.metrics.pixels > widget.after;
              if (v != on) setState(() => on = v);
            }
            return false;
          },
          child: widget.child,
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: on ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: Container(height: top, decoration: const BoxDecoration(color: C.bg, border: Border(bottom: BorderSide(color: C.line)))),
            ),
          ),
        ),
      ]),
    );
  }
}
