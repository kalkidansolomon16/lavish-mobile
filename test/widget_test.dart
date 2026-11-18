import 'package:flutter_test/flutter_test.dart';
import 'package:lavish/core/api.dart';
import 'package:lavish/core/format.dart';
import 'package:lavish/core/reminders.dart';
import 'package:lavish/widgets/phone_field.dart';

void main() {
  test('money and points are formatted like the web portal', () {
    expect(etb(4500), 'ETB 4,500');
    expect(pts(12000), '12,000 pts');
  });

  test('phone numbers typed by the user are sent in a form the API accepts', () {
    expect(phoneForApi('911 22 33 44'), '0911223344');
    expect(phoneForApi('0911223344'), '0911223344');
    expect(phoneForApi('+251 911 22 33 44'), '+251911223344');
  });

  test('initials skip the Dr. title', () {
    expect(initials('Dr. Meron Alemu'), 'MA');
    expect(initials('Tigist Worku'), 'TW');
  });

  test('JSON helpers read enums and nested objects', () {
    final Json j = {
      'availability': {'value': 'available', 'label': 'Available'},
      'branch': {'name': 'Adama'},
      'n': '12',
    };
    expect(j.enumValue('availability'), 'available');
    expect(j.enumLabel('availability'), 'Available');
    expect(j.obj('branch').str('name'), 'Adama');
    expect(j.integer('n'), 12);
    expect(j.obj('missing').str('name', '—'), '—');
  });

  test('phone field builds the international number for any country', () {
    expect(PhoneController(text: '0911 22 33 44').full, '+251911223344');
    expect((PhoneController(text: '712345678')..code = '254').full, '+254712345678');
    expect(PhoneController(text: '+251911223344').text, '911223344');
    expect(PhoneController().looksValid, isFalse);
  });

  test('medicine reminders: doses only between the first and last day, earliest first, switch-off respected', () {
    final r = MedReminders.instance;
    r.items = [
      {'id': 1, 'name': 'Vitamin C serum', 'instructions': 'Every morning', 'reminder': {'times': ['20:00', '08:00'], 'starts_on': '2026-11-19', 'ends_on': '2026-12-02', 'active': true}},
      {'id': 2, 'name': 'Old cream', 'instructions': '', 'reminder': {'times': ['09:00'], 'starts_on': '2026-10-01', 'ends_on': '2026-10-14', 'active': false}},
    ];
    r.off = {};
    final day = r.dosesOn(DateTime(2026, 11, 25));
    expect(day.map((d) => d.time).toList(), ['08:00', '20:00']);
    expect(day.first.name, 'Vitamin C serum');
    expect(r.dosesOn(DateTime(2026, 11, 18)), isEmpty); // before the start
    expect(r.dosesOn(DateTime(2026, 12, 3)), isEmpty);  // after the last day
    r.off = {1};
    expect(r.dosesOn(DateTime(2026, 11, 25)), isEmpty);
  });
}
