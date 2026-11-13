import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data/models.dart';
import 'measure/scan_screen.dart';

void main() => runApp(const FitCraftApp());

const brand = Color(0xFF065F46);

class FitCraftApp extends StatelessWidget {
  const FitCraftApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FitCraft',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: brand, useMaterial3: true, scaffoldBackgroundColor: const Color(0xFFF7F6F3)),
        home: const BoardScreen(),
        // On a wide screen (a computer browser) show the app in a phone-sized frame so it looks and
        // behaves like the phone app; on a phone it fills the screen.
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          if (mq.size.width < 600) return child!;
          final h = (mq.size.height - 48).clamp(560.0, 900.0);
          return ColoredBox(
            color: const Color(0xFF0B1F1A),
            child: Center(child: Container(
              width: 412, height: h,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(40), border: Border.all(color: const Color(0xFF111827), width: 10),
                  boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 40, offset: Offset(0, 20))]),
              child: ClipRRect(borderRadius: BorderRadius.circular(30),
                  child: MediaQuery(data: mq.copyWith(size: Size(392, h - 20)), child: child!)),
            )),
          );
        },
      );
}

const stageColor = {
  Stage.notMeasured: Colors.grey, Stage.measured: Colors.blue, Stage.cutting: Colors.amber, Stage.sewing: Colors.orange,
  Stage.readyForFitting: Colors.purple, Stage.fitted: Colors.green, Stage.collected: Colors.teal,
};

Widget stagePill(Stage s) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: stageColor[s]!.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(stageLabel[s]!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: stageColor[s]!.shade800)),
    );

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});
  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  GroupOrder? order;
  bool loaded = false;
  String filter = 'All';

  @override
  void initState() {
    super.initState();
    Store.load().then((o) => setState(() { order = o; loaded = true; }));
  }

  void changed() {
    setState(() {});
    Store.save(order!);
  }

  Future<void> shareUpdate() async {
    final o = order!;
    final notMeasured = o.guests.where((g) => g.stage == Stage.notMeasured).map((g) => g.name).join(', ');
    final text = '*${o.event}* update\n'
        'Measured: ${o.guests.where((g) => g.stage != Stage.notMeasured).length}/${o.guests.length}\n'
        'Ready or collected: ${o.guests.where((g) => g.stage.index >= Stage.fitted.index).length}/${o.guests.length}\n'
        'Paid: ${naira(o.paid)} of ${naira(o.total)}\n'
        'Still to be measured: ${notMeasured.isEmpty ? 'none' : notMeasured}';
    await launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final o = order;
    if (!loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (o == null) return WelcomeScreen(onStart: (created) { setState(() => order = created); Store.save(created); });
    final shown = o.guests.where((g) => filter == 'All' ? true : filter == 'Owing' ? g.owed > 0 : stageLabel[g.stage] == filter).toList();
    final measured = o.guests.where((g) => g.stage != Stage.notMeasured).length;
    final ready = o.guests.where((g) => g.stage.index >= Stage.fitted.index).length;
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true, expandedHeight: 210, backgroundColor: brand, foregroundColor: Colors.white,
          actions: [
            IconButton(tooltip: 'Coordinator view', icon: const Icon(Icons.groups), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CoordinatorScreen(order: o)))),
            PopupMenuButton<String>(
              iconColor: Colors.white,
              onSelected: (v) async {
                if (v != 'new') return;
                final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
                  title: const Text('Start a new order?'),
                  content: const Text('This removes the current order and its guests from this phone.'),
                  actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Start new'))],
                ));
                if (ok == true) { await Store.clear(); setState(() => order = null); }
              },
              itemBuilder: (_) => const [PopupMenuItem(value: 'new', child: Text('Start a new order'))],
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(background: Container(
            padding: const EdgeInsets.fromLTRB(16, 72, 16, 12),
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [brand, Color(0xFF022C22)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('GROUP ORDER · ${o.daysToGo} DAYS TO GO', style: const TextStyle(color: Color(0xFFA7F3D0), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              const SizedBox(height: 4),
              Text(o.event, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Row(children: [_stat('$measured/${o.guests.length}', 'Measured'), _stat('$ready/${o.guests.length}', 'Ready'), _stat(o.total == 0 ? '—' : '${(100 * o.paid / o.total).round()}%', 'Paid')]),
              const SizedBox(height: 6),
              Text('${naira(o.paid)} received · ${naira(o.total - o.paid)} owed', style: const TextStyle(color: Color(0xFFD1FAE5), fontSize: 12)),
            ]),
          )),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 52, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), children: [
          for (final f in ['All', 'Owing', ...stageLabel.values])
            Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(f), selected: filter == f, onSelected: (_) => setState(() => filter = f))),
        ]))),
        SliverList.builder(
          itemCount: shown.length,
          itemBuilder: (_, i) {
            final g = shown[i];
            return Card(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: const Color(0xFFECFDF5), child: Text(g.name[0], style: const TextStyle(color: brand, fontWeight: FontWeight.w900))),
                title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${templateOf(g.templateId).name} · ${g.fabric}'),
                  const SizedBox(height: 4),
                  Row(children: [stagePill(g.stage), if (g.owed > 0) Padding(padding: const EdgeInsets.only(left: 6), child: Text('owes ${naira(g.owed)}', style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w700)))]),
                ]),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => GuestScreen(guest: g, onChanged: changed)));
                  changed();
                },
              ),
            );
          },
        ),
        if (o.guests.isEmpty) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(24, 32, 24, 0), child: Column(children: [
          const Icon(Icons.person_add_alt_1, size: 48, color: brand),
          const SizedBox(height: 12),
          const Text('No guests yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Add each guest with their outfit, fabric and price. Then measure them with photos, record payments and fittings.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: addGuest, icon: const Icon(Icons.person_add), label: const Text('Add your first guest')),
        ]))),
        const SliverToBoxAdapter(child: SizedBox(height: 90)),
      ]),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Expanded(child: FilledButton.icon(onPressed: shareUpdate, style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366), minimumSize: const Size.fromHeight(48)),
            icon: const Icon(Icons.chat), label: const Text('Update coordinator'))),
        const SizedBox(width: 8),
        FilledButton.icon(onPressed: addGuest, style: FilledButton.styleFrom(minimumSize: const Size(0, 48)), icon: const Icon(Icons.person_add), label: const Text('Guest')),
      ]))),
    );
  }

  Widget _stat(String v, String k) => Expanded(child: Container(
        margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Column(children: [Text(v, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)), Text(k.toUpperCase(), style: const TextStyle(color: Color(0xFFD1FAE5), fontSize: 10, fontWeight: FontWeight.w700))]),
      ));

  Future<void> addGuest() async {
    final name = TextEditingController(), fabric = TextEditingController(text: 'Green ankara'), price = TextEditingController(text: '30000');
    var tpl = 'senator';
    final ok = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (c) => StatefulBuilder(builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(c).viewInsets.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Add a guest', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(initialValue: tpl, decoration: const InputDecoration(labelText: 'Outfit', border: OutlineInputBorder()),
                items: [for (final t in templates) DropdownMenuItem(value: t.id, child: Text(t.name))], onChanged: (v) => set(() => tpl = v!)),
            const SizedBox(height: 8),
            TextField(controller: fabric, decoration: const InputDecoration(labelText: 'Fabric', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price (₦)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => Navigator.pop(c, name.text.trim().isNotEmpty), child: const Text('Add guest')),
          ]),
        )));
    if (ok == true) {
      order!.guests.add(Guest(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name.text.trim(), templateId: tpl, fabric: fabric.text.trim(), price: int.tryParse(price.text) ?? 0));
      changed();
    }
  }
}

class GuestScreen extends StatefulWidget {
  final Guest guest;
  final VoidCallback onChanged;
  const GuestScreen({super.key, required this.guest, required this.onChanged});
  @override
  State<GuestScreen> createState() => _GuestScreenState();
}

class _GuestScreenState extends State<GuestScreen> {
  Guest get g => widget.guest;
  void changed() {
    setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final tpl = templateOf(g.templateId);
    final next = g.stage.index < Stage.values.length - 1 ? Stage.values[g.stage.index + 1] : null;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(g.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text('${tpl.name} · ${g.fabric} · ${naira(g.price)}', style: const TextStyle(fontSize: 12)),
          ]),
          bottom: const TabBar(tabs: [Tab(icon: Icon(Icons.straighten), text: 'Measure'), Tab(icon: Icon(Icons.payments), text: 'Payments'), Tab(icon: Icon(Icons.content_cut), text: 'Fit Record')]),
        ),
        body: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Row(children: [
            stagePill(g.stage),
            const Spacer(),
            if (next != null) TextButton.icon(onPressed: () { g.stage = next; changed(); }, icon: const Icon(Icons.arrow_forward), label: Text('Move to ${stageLabel[next]}')),
          ])),
          Expanded(child: TabBarView(children: [_measure(tpl), _payments(), _fits()])),
        ]),
      ),
    );
  }

  Widget _measure(Template tpl) => ListView(padding: const EdgeInsets.all(16), children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          icon: const Icon(Icons.photo_camera), label: const Text('Measure with photos (AI)'),
          onPressed: () async {
            final r = await Navigator.push<Map<String, String>>(context, MaterialPageRoute(builder: (_) => ScanScreen(template: tpl, customer: g.name)));
            if (r != null) {
              g.measurements = {...g.measurements, ...r};
              g.measuredBy = 'photo, tailor confirmed';
              if (g.stage == Stage.notMeasured) g.stage = Stage.measured;
              changed();
            }
          },
        ),
        const SizedBox(height: 6),
        Text(g.measuredBy == null ? 'Or type them in below (inches).' : 'Source: ${g.measuredBy}. Edit any value below.', style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 12),
        for (final f in tpl.fields)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: TextFormField(
            key: ValueKey('${g.id}-$f-${g.measurements[f]}'),
            initialValue: g.measurements[f] ?? '',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: f, suffixText: 'in', border: const OutlineInputBorder(), isDense: true),
            onChanged: (v) {
              g.measurements[f] = v;
              g.measuredBy ??= 'hand';
              if (g.stage == Stage.notMeasured && v.isNotEmpty) g.stage = Stage.measured;
              widget.onChanged();
            },
          )),
      ]);

  final amt = TextEditingController();

  Widget _payments() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      ListTile(title: const Text('Paid'), trailing: Text(naira(g.paid), style: const TextStyle(fontWeight: FontWeight.w800))),
      ListTile(title: const Text('Balance'), trailing: Text(g.owed > 0 ? naira(g.owed) : 'Fully paid', style: TextStyle(fontWeight: FontWeight.w800, color: g.owed > 0 ? Colors.red : Colors.green))),
      const Divider(),
      for (final p in g.payments) ListTile(dense: true, title: Text('${p.date} · ${p.method}'), trailing: Text(naira(p.amount))),
      if (g.owed > 0) Row(children: [
        Expanded(child: TextField(controller: amt, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₦)', border: OutlineInputBorder(), isDense: true))),
        const SizedBox(width: 8),
        FilledButton(onPressed: () {
          final n = int.tryParse(amt.text) ?? 0;
          if (n > 0) { g.payments.add(Payment(today(), n > g.owed ? g.owed : n, 'Transfer')); amt.clear(); changed(); }
        }, child: const Text('Record')),
      ]),
    ]);
  }

  static const areas = ['Shoulder', 'Sleeve', 'Chest / bust', 'Waist', 'Hip', 'Length', 'Neck'];
  String? area;
  double cm = -1;

  Widget _fits() => ListView(padding: const EdgeInsets.all(16), children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size.fromHeight(48)),
          icon: const Icon(Icons.check), label: const Text('Fits: customer approved'),
          onPressed: () { g.fits.add(FitRecord(today(), true)); if (g.stage.index < Stage.fitted.index) g.stage = Stage.fitted; changed(); },
        ),
        const SizedBox(height: 16),
        const Text('Or: what needs altering?', style: TextStyle(fontWeight: FontWeight.w700)),
        Wrap(spacing: 6, children: [for (final a in areas) ChoiceChip(label: Text(a), selected: area == a, onSelected: (_) => setState(() => area = a))]),
        if (area != null) Row(children: [
          IconButton.filledTonal(onPressed: () => setState(() => cm -= 0.5), icon: const Icon(Icons.remove)),
          SizedBox(width: 80, child: Text('${cm > 0 ? '+' : ''}$cm cm', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800))),
          IconButton.filledTonal(onPressed: () => setState(() => cm += 0.5), icon: const Icon(Icons.add)),
          const Spacer(),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.orange), onPressed: () {
            g.fits.add(FitRecord(today(), false, area: area, changeCm: cm, note: '${cm < 0 ? 'Take in' : 'Let out'} ${cm.abs()} cm at ${area!.toLowerCase()}'));
            g.stage = Stage.readyForFitting;
            area = null; cm = -1;
            changed();
          }, child: const Text('Save')),
        ]),
        const Divider(height: 32),
        const Text('Fit history', style: TextStyle(fontWeight: FontWeight.w700)),
        if (g.fits.isEmpty) const Text('No fittings yet. Each one recorded here builds this customer\'s fit profile.', style: TextStyle(color: Colors.black54)),
        for (final f in g.fits) ListTile(dense: true, leading: Icon(f.approved ? Icons.check_circle : Icons.content_cut, color: f.approved ? Colors.green : Colors.orange),
            title: Text(f.approved ? 'Approved' : f.note ?? ''), subtitle: Text(f.date)),
      ]);
}

class CoordinatorScreen extends StatelessWidget {
  final GroupOrder order;
  const CoordinatorScreen({super.key, required this.order});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('What the coordinator sees')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text(order.event, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          Text('${order.date} · ${order.daysToGo} days to go'),
          const SizedBox(height: 12),
          for (final g in order.guests) ListTile(
            title: Text(g.name), subtitle: Text(templateOf(g.templateId).name), leading: stagePill(g.stage),
            trailing: Text(g.owed > 0 ? 'owes ${naira(g.owed)}' : 'paid', style: TextStyle(color: g.owed > 0 ? Colors.red : Colors.green, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          const Text('Measurements are never shown here: they stay between each guest and the tailor.', style: TextStyle(color: Colors.black54, fontSize: 12)),
        ]),
      );
}


/// First launch: create a real group order, or explore the sample wedding.
class WelcomeScreen extends StatefulWidget {
  final void Function(GroupOrder) onStart;
  const WelcomeScreen({super.key, required this.onStart});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final event = TextEditingController(), coordinator = TextEditingController();
  DateTime? date;

  @override
  Widget build(BuildContext context) {
    final ready = event.text.trim().isNotEmpty && date != null;
    return Scaffold(
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerLeft, child: Container(width: 56, height: 56, decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.content_cut, color: Colors.white))),
        const SizedBox(height: 16),
        const Text('Welcome to FitCraft', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('Run your next Aso-ebi or group order in one place: guests, measurements, payments and fittings.', style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 24),
        const Text('Create your first group order', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        TextField(controller: event, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Event (e.g. Ade & Tolu wedding)', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          icon: const Icon(Icons.event),
          label: Text(date == null ? 'Event date' : '${date!.day}/${date!.month}/${date!.year}'),
          onPressed: () async {
            final now = DateTime.now();
            final d = await showDatePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 730)), initialDate: now.add(const Duration(days: 30)));
            if (d != null) setState(() => date = d);
          },
        ),
        const SizedBox(height: 10),
        TextField(controller: coordinator, decoration: const InputDecoration(labelText: 'Coordinator (optional)', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          onPressed: ready ? () => widget.onStart(GroupOrder(event.text.trim(), date!.toIso8601String().substring(0, 10), coordinator.text.trim().isEmpty ? '—' : coordinator.text.trim(), [])) : null,
          child: const Text('Create order'),
        ),
        const SizedBox(height: 28),
        const Divider(),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          icon: const Icon(Icons.play_circle_outline),
          label: const Text('Explore with sample data'),
          onPressed: () => widget.onStart(sampleOrder()),
        ),
        const SizedBox(height: 6),
        const Text('Loads a made-up wedding with 8 guests so you can try every screen. You can start a real order later from the menu.', style: TextStyle(fontSize: 12, color: Colors.black54)),
      ])),
    );
  }
}
