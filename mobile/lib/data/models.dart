// Group orders, guests, payments and fit records, saved on the phone so the app works offline.
// Sample data only: every name and amount is fictional.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum Stage { notMeasured, measured, cutting, sewing, readyForFitting, fitted, collected }

const stageLabel = {
  Stage.notMeasured: 'Not measured', Stage.measured: 'Measured', Stage.cutting: 'Cutting', Stage.sewing: 'Sewing',
  Stage.readyForFitting: 'Ready for fitting', Stage.fitted: 'Fitted', Stage.collected: 'Collected',
};

class Template {
  final String id, name;
  final List<String> fields;
  const Template(this.id, this.name, this.fields);
}

const templates = [
  Template('agbada', 'Agbada (3-piece)', ['Chest', 'Shoulder', 'Sleeve', 'Agbada length', 'Top length', 'Trouser waist', 'Trouser length', 'Thigh', 'Cap']),
  Template('buba-iro', 'Buba and iro', ['Bust', 'Waist', 'Hip', 'Shoulder', 'Sleeve', 'Blouse length', 'Wrapper length']),
  Template('senator', 'Senator', ['Chest', 'Shoulder', 'Sleeve', 'Top length', 'Neck', 'Trouser waist', 'Trouser length']),
  Template('gown', 'Gown', ['Bust', 'Waist', 'Hip', 'Shoulder', 'Gown length']),
];
Template templateOf(String id) => templates.firstWhere((t) => t.id == id);

class Payment {
  final String date, method;
  final int amount;
  Payment(this.date, this.amount, this.method);
  Map<String, dynamic> toJson() => {'date': date, 'amount': amount, 'method': method};
  factory Payment.fromJson(Map<String, dynamic> j) => Payment(j['date'], j['amount'], j['method']);
}

class FitRecord {
  final String date;
  final bool approved;
  final String? area, note;
  final double? changeCm;
  FitRecord(this.date, this.approved, {this.area, this.changeCm, this.note});
  Map<String, dynamic> toJson() => {'date': date, 'approved': approved, 'area': area, 'changeCm': changeCm, 'note': note};
  factory FitRecord.fromJson(Map<String, dynamic> j) =>
      FitRecord(j['date'], j['approved'], area: j['area'], changeCm: (j['changeCm'] as num?)?.toDouble(), note: j['note']);
}

class Guest {
  String id, name, templateId, fabric;
  int price;
  Stage stage;
  Map<String, String> measurements; // inches, as text the tailor can edit
  String? measuredBy; // 'hand' or 'photo, tailor confirmed'
  List<Payment> payments;
  List<FitRecord> fits;
  Guest({required this.id, required this.name, required this.templateId, required this.fabric, required this.price,
      this.stage = Stage.notMeasured, Map<String, String>? measurements, this.measuredBy, List<Payment>? payments, List<FitRecord>? fits})
      : measurements = measurements ?? {}, payments = payments ?? [], fits = fits ?? [];

  int get paid => payments.fold(0, (a, p) => a + p.amount);
  int get owed => price - paid;

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'templateId': templateId, 'fabric': fabric, 'price': price, 'stage': stage.name,
        'measurements': measurements, 'measuredBy': measuredBy,
        'payments': payments.map((p) => p.toJson()).toList(), 'fits': fits.map((f) => f.toJson()).toList(),
      };
  factory Guest.fromJson(Map<String, dynamic> j) => Guest(
        id: j['id'], name: j['name'], templateId: j['templateId'], fabric: j['fabric'], price: j['price'],
        stage: Stage.values.byName(j['stage']), measurements: Map<String, String>.from(j['measurements'] ?? {}),
        measuredBy: j['measuredBy'],
        payments: (j['payments'] as List).map((p) => Payment.fromJson(p)).toList(),
        fits: (j['fits'] as List).map((f) => FitRecord.fromJson(f)).toList(),
      );
}

class GroupOrder {
  String event, date, coordinator;
  List<Guest> guests;
  GroupOrder(this.event, this.date, this.coordinator, this.guests);
  int get total => guests.fold(0, (a, g) => a + g.price);
  int get paid => guests.fold(0, (a, g) => a + g.paid);
  int get daysToGo => DateTime.parse(date).difference(DateTime.now()).inDays + 1;
  Map<String, dynamic> toJson() => {'event': event, 'date': date, 'coordinator': coordinator, 'guests': guests.map((g) => g.toJson()).toList()};
  factory GroupOrder.fromJson(Map<String, dynamic> j) =>
      GroupOrder(j['event'], j['date'], j['coordinator'], (j['guests'] as List).map((g) => Guest.fromJson(g)).toList());
}

String naira(int n) {
  final s = n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  return '₦$s';
}

String today() => DateTime.now().toIso8601String().substring(0, 10);

const _sampleInches = {
  'Chest': '41', 'Bust': '38', 'Waist': '34', 'Hip': '42', 'Shoulder': '18', 'Sleeve': '24', 'Agbada length': '57',
  'Top length': '30', 'Blouse length': '24', 'Wrapper length': '41', 'Gown length': '56', 'Trouser waist': '34',
  'Trouser length': '40', 'Thigh': '24', 'Neck': '16', 'Cap': '22',
};

GroupOrder sampleOrder() {
  Guest g(String id, String name, String t, String fabric, int price, Stage stage, List<int> paid, {List<FitRecord>? fits}) => Guest(
        id: id, name: name, templateId: t, fabric: fabric, price: price, stage: stage, fits: fits,
        measurements: stage == Stage.notMeasured ? {} : {for (final f in templateOf(t).fields) if (_sampleInches[f] != null) f: _sampleInches[f]!},
        measuredBy: stage == Stage.notMeasured ? null : 'hand',
        payments: [for (var i = 0; i < paid.length; i++) Payment('2026-11-0${i + 2}', paid[i], i == 0 ? 'Transfer' : 'Cash')],
      );
  return GroupOrder('Bisi & Kunle wedding (sample)', '2026-12-19', 'Aunty Funke (sample)', [
    g('1', 'Kunle (groom)', 'agbada', 'Gold aso-oke', 85000, Stage.sewing, [85000]),
    g('2', 'Bisi (bride)', 'gown', 'Gold aso-oke', 120000, Stage.readyForFitting, [60000, 60000]),
    g('3', 'Mama Bisi', 'buba-iro', 'Gold aso-oke', 65000, Stage.fitted, [65000],
        fits: [FitRecord('2026-11-28', false, area: 'Waist', changeCm: -2, note: 'Take in 2 cm at waist'), FitRecord('2026-11-30', true)]),
    g('4', 'Baba Kunle', 'agbada', 'Gold aso-oke', 85000, Stage.cutting, [40000]),
    g('5', 'Tolu', 'buba-iro', 'Green ankara', 35000, Stage.notMeasured, [35000]),
    g('6', 'Emeka', 'senator', 'Green ankara', 30000, Stage.notMeasured, [15000]),
    g('7', 'Zainab', 'gown', 'Green ankara', 40000, Stage.notMeasured, []),
    g('8', 'Ngozi', 'buba-iro', 'Green ankara', 35000, Stage.collected, [35000], fits: [FitRecord('2026-11-20', true)]),
  ]);
}

class Store {
  static const _key = 'fitcraft_order_v1';
  static Future<GroupOrder> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_key);
    if (s == null) return sampleOrder();
    try {
      return GroupOrder.fromJson(jsonDecode(s));
    } catch (_) {
      return sampleOrder();
    }
  }

  static Future<void> save(GroupOrder o) async => (await SharedPreferences.getInstance()).setString(_key, jsonEncode(o.toJson()));
}
