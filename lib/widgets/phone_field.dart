import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Countries offered in the phone field (Ethiopia first, then neighbours, the Gulf and the diaspora).
const countries = <(String, String, String, String)>[
  ('🇪🇹', 'Ethiopia', '251', '9X XXX XXXX'),
  ('🇰🇪', 'Kenya', '254', '712 345 678'),
  ('🇩🇯', 'Djibouti', '253', '77 12 34 56'),
  ('🇪🇷', 'Eritrea', '291', '7 123 456'),
  ('🇸🇴', 'Somalia', '252', '61 234 5678'),
  ('🇸🇩', 'Sudan', '249', '91 234 5678'),
  ('🇸🇸', 'South Sudan', '211', '912 345 678'),
  ('🇺🇬', 'Uganda', '256', '712 345 678'),
  ('🇹🇿', 'Tanzania', '255', '712 345 678'),
  ('🇷🇼', 'Rwanda', '250', '781 234 567'),
  ('🇪🇬', 'Egypt', '20', '100 123 4567'),
  ('🇿🇦', 'South Africa', '27', '71 234 5678'),
  ('🇳🇬', 'Nigeria', '234', '802 123 4567'),
  ('🇸🇦', 'Saudi Arabia', '966', '51 234 5678'),
  ('🇦🇪', 'United Arab Emirates', '971', '50 123 4567'),
  ('🇶🇦', 'Qatar', '974', '3312 3456'),
  ('🇰🇼', 'Kuwait', '965', '500 12345'),
  ('🇧🇭', 'Bahrain', '973', '3600 1234'),
  ('🇴🇲', 'Oman', '968', '9212 3456'),
  ('🇱🇧', 'Lebanon', '961', '71 123 456'),
  ('🇮🇱', 'Israel', '972', '50 234 5678'),
  ('🇹🇷', 'Turkey', '90', '501 234 5678'),
  ('🇬🇧', 'United Kingdom', '44', '7400 123456'),
  ('🇩🇪', 'Germany', '49', '1512 3456789'),
  ('🇫🇷', 'France', '33', '6 12 34 56 78'),
  ('🇮🇹', 'Italy', '39', '312 345 6789'),
  ('🇳🇱', 'Netherlands', '31', '6 12345678'),
  ('🇸🇪', 'Sweden', '46', '70 123 45 67'),
  ('🇳🇴', 'Norway', '47', '406 12 345'),
  ('🇺🇸', 'United States / Canada', '1', '201 555 0123'),
  ('🇨🇳', 'China', '86', '131 2345 6789'),
  ('🇮🇳', 'India', '91', '81234 56789'),
];

/// Text controller that also remembers the chosen country code. [full] is the international number
/// the API expects (+251911223344); a leading 0 typed by habit is dropped.
class PhoneController extends TextEditingController {
  PhoneController({String? text, this.code = '251'}) : super(text: text == null ? null : _local(text, code));

  String code;

  String get digits => text.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0+'), '');
  String get full => digits.isEmpty ? '' : '+$code$digits';
  bool get looksValid => digits.length >= 7;

  /// "+251911223344" or "0911223344" → local part for the given code.
  static String _local(String v, String code) {
    final d = v.replaceAll(RegExp(r'\D'), '');
    if (v.trim().startsWith('+') && d.startsWith(code)) return d.substring(code.length);
    return d.replaceFirst(RegExp(r'^0+'), '');
  }
}

/// Phone input with a country-code picker in front (same look as [Field]).
class PhoneField extends StatefulWidget {
  const PhoneField({super.key, required this.label, required this.controller, this.onSubmitted, this.textInputAction});
  final String label;
  final PhoneController controller;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  (String, String, String, String) get country => countries.firstWhere((c) => c.$3 == widget.controller.code, orElse: () => countries.first);

  Future<void> _pick() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .7,
        builder: (_, scroll) => Column(children: [
          Text('Country code', style: serif(22)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(controller: scroll, children: [
              for (final c in countries)
                ListTile(
                  leading: Text(c.$1, style: const TextStyle(fontSize: 22)),
                  title: Text(c.$2),
                  trailing: Text('+${c.$3}', style: const TextStyle(color: C.muted, fontWeight: FontWeight.w500)),
                  selected: c.$3 == widget.controller.code,
                  selectedColor: C.dark,
                  onTap: () => Navigator.pop(sheet, c.$3),
                ),
            ]),
          ),
        ]),
      ),
    );
    if (picked != null) setState(() => widget.controller.code = picked);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (widget.label.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(widget.label, style: const TextStyle(fontSize: 12.5, color: C.muted, fontWeight: FontWeight.w500))),
          TextField(
            controller: widget.controller,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            textInputAction: widget.textInputAction,
            onSubmitted: widget.onSubmitted,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: country.$4,
              prefixIcon: InkWell(
                onTap: _pick,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 10),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('${country.$1} +${country.$3}', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                    const Icon(Icons.arrow_drop_down_rounded, color: C.muted),
                    const SizedBox(width: 4),
                    Container(width: 1, height: 22, color: C.line),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      );
}
