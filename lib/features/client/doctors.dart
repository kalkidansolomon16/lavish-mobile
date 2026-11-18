import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';

class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({super.key, this.serviceId});
  final int? serviceId;
  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  String q = '';
  String spec = 'All';
  int? serviceId;
  String? serviceName;

  @override
  void initState() {
    super.initState();
    serviceId = widget.serviceId;
  }

  Future<List<Json>> _load() async {
    final r = await api.get('/catalog/doctors', {'service_id': serviceId});
    if (serviceId != null && serviceName == null) {
      final s = listOf(await api.get('/catalog/services')).where((s) => s['id'] == serviceId).firstOrNull;
      serviceName = s?.str('name');
    }
    return listOf(r);
  }

  @override
  Widget build(BuildContext context) {
    final online = session.config['online_consultation'] is Map ? Map<String, dynamic>.from(session.config['online_consultation']) : null;
    return Scaffold(
      appBar: lvAppBar(context, 'Doctors'),
      body: Loader<List<Json>>(
        key: ValueKey(serviceId),
        load: _load,
        builder: (context, all, reload) {
          final specs = ['All', ...{for (final d in all) d.str('specialty')}.where((s) => s.isNotEmpty)];
          final list = all.where((d) {
            final okSpec = spec == 'All' || d.str('specialty') == spec;
            final okQ = q.isEmpty || d.str('name').toLowerCase().contains(q.toLowerCase()) || d.str('specialty').toLowerCase().contains(q.toLowerCase());
            return okSpec && okQ;
          }).toList();
          return ListView(padding: const EdgeInsets.only(top: 4, bottom: 30), children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (v) => setState(() => q = v),
                decoration: InputDecoration(
                  hintText: 'Search by doctor or specialty',
                  prefixIcon: const Icon(Icons.search_rounded, color: C.muted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: C.line)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: C.line)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: C.dark)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (specs.length > 2) ChipBar<String>(items: [for (final s in specs) (s, s)], value: spec, onChanged: (v) => setState(() => spec = v)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (serviceId != null)
                  Banner2(
                    icon: Icons.filter_alt_rounded,
                    text: Text.rich(TextSpan(children: [const TextSpan(text: 'Doctors who offer '), TextSpan(text: serviceName ?? 'this treatment', style: const TextStyle(fontWeight: FontWeight.w600))])),
                    trailing: LinkText('Clear', size: 13, onTap: () => setState(() {
                      serviceId = null;
                      serviceName = null;
                    })),
                  ),
                const SizedBox(height: 4),
                _DashedCard(
                  icon: Icons.auto_awesome_rounded,
                  gold: true,
                  title: 'Not sure who to see?',
                  text: 'Book a treatment and reception will match you with the best available doctor.',
                  onTap: () => context.push('/book', extra: {'serviceId': serviceId}),
                ),
                if (online != null)
                  _DashedCard(
                    icon: Icons.video_call_rounded,
                    title: 'Consult a doctor online',
                    text: '${online.integer('duration_minutes', 45)}-min video call from home · ${etb(online['price'] as num?)}. Reception confirms your slot.',
                    onTap: () => context.push('/book', extra: {'online': true}),
                  ),
                const SizedBox(height: 8),
                for (final d in list) _DoctorCard(d: d, serviceId: serviceId),
                if (list.isEmpty) const Empty(icon: Icons.person_search_rounded, title: 'No doctors found', text: 'Try another specialty or search.'),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}

class _DashedCard extends StatelessWidget {
  const _DashedCard({required this.icon, required this.title, required this.text, required this.onTap, this.gold = false});
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;
  final bool gold;
  @override
  Widget build(BuildContext context) => LvCard(
        margin: const EdgeInsets.only(top: 8),
        onTap: onTap,
        borderColor: const Color(0xFFD5D3D0),
        child: Row(children: [
          IconBox(icon, tone: gold ? Tone.gold : Tone.teal),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w500)), Muted(text, size: 12.5)])),
          const Icon(Icons.chevron_right_rounded, color: C.muted),
        ]),
      );
}

class _DoctorCard extends StatelessWidget {
  const _DoctorCard({required this.d, this.serviceId});
  final Json d;
  final int? serviceId;
  @override
  Widget build(BuildContext context) {
    final avail = d.enumValue('availability');
    return LvCard(
      margin: const EdgeInsets.only(top: 12),
      onTap: () => context.push('/doctor/${d['id']}'),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Avatar(name: d.str('name'), hue: d['hue'] as num?, size: 62, url: d.str('photo_url'), online: avail == 'available'),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.str('name'), style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
            Muted(d.str('specialty'), size: 12.5),
            const SizedBox(height: 8),
            Wrap(spacing: 14, runSpacing: 4, children: [
              if (d['rating'] != null)
                _Meta(Icons.star_rounded, '${d['rating']} (${d.integer('reviews_count')})', iconColor: C.gold)
              else
                const _Meta(Icons.star_outline_rounded, 'New', iconColor: C.gold),
              if (d.objOrNull('branch') != null) _Meta(Icons.location_on_outlined, d.obj('branch').str('name')),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Pill(d.enumLabel('availability'), tone: Pill.toneOf(avail)),
              const Spacer(),
              LvButton('Book', small: true, expand: false, onTap: () => context.push('/book', extra: {'doctorId': d['id'], 'serviceId': serviceId})),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text, {this.iconColor = C.muted});
  final IconData icon;
  final String text;
  final Color iconColor;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: iconColor), const SizedBox(width: 4), Text(text, style: const TextStyle(color: C.muted, fontSize: 12.5))]);
}

// ---------------------------------------------------------------- doctor detail

class DoctorScreen extends StatelessWidget {
  const DoctorScreen({super.key, required this.id});
  final int id;

  Future<void> _chat(BuildContext context, Json d) async {
    try {
      final c = dataOf(await api.post('/client/chats/${d['id']}'));
      if (context.mounted) context.push('/chat/${c['id']}', extra: {'title': d.str('name')});
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.friendly, error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: StatusBarScrim(child: Loader<Json>(
          load: () async => dataOf(await api.get('/catalog/doctors/$id')),
          builder: (context, d, _) {
            final online = session.config['online_consultation'] is Map ? Map<String, dynamic>.from(session.config['online_consultation']) : null;
            final services = d.list('services').where((s) => !s.flag('is_online')).toList();
            final days = d.str('working_days', 'Mon – Sat');
            return Column(children: [
              Expanded(
                child: ListView(padding: EdgeInsets.zero, children: [
                  TealHeader(
                    padding: EdgeInsets.fromLTRB(12, MediaQuery.paddingOf(context).top + 6, 12, 40),
                    child: Column(children: [
                      Row(children: [CircleIconButton(Icons.arrow_back_rounded, onDark: true, onTap: () => context.pop()), const Spacer()]),
                      Avatar(name: d.str('name'), hue: d['hue'] as num?, size: 96, url: d.str('photo_url'), ring: true),
                      const SizedBox(height: 12),
                      Text(d.str('name'), style: serif(28, color: Colors.white)),
                      Text('${d.str('specialty')} · ${d.obj('branch').str('name', 'Lavish')}', style: const TextStyle(color: C.mint, fontSize: 13.5)),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Transform.translate(
                        offset: const Offset(0, -22),
                        child: LvCard(
                          radius: 18,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: IntrinsicHeight(
                            child: Row(children: [
                              _Stat('${d.integer('years_experience')}+', 'Years'),
                              const VerticalDivider(color: C.line, width: 1),
                              _Stat(d['rating']?.toString() ?? '—', '${d.integer('reviews_count')} reviews'),
                              const VerticalDivider(color: C.line, width: 1),
                              _Stat(days.split(' ').first, 'Working days', small: days),
                            ]),
                          ),
                        ),
                      ),
                      if (d.str('bio').isNotEmpty) ...[
                        SectionTitle('About', top: 0),
                        Text(d.str('bio'), style: const TextStyle(height: 1.55, color: Color(0xFF4A4A4A))),
                      ],
                      const SectionTitle('Treatments'),
                      LvList(children: [
                        for (final s in services)
                          LvTile(
                            icon: iconFor(s.str('icon')),
                            title: s.str('name'),
                            subtitle: '${s.integer('duration_minutes')} min',
                            trailing: Text(etb(s['price'] as num?), style: serif(16)),
                            onTap: () => context.push('/book', extra: {'doctorId': d['id'], 'serviceId': s['id']}),
                          ),
                        if (online != null)
                          LvTile(
                            icon: Icons.video_call_rounded,
                            iconTone: Tone.gold,
                            title: online.str('name', 'Online consultation'),
                            subtitle: '${online.integer('duration_minutes', 45)} min · video call from home',
                            trailing: Text(etb(online['price'] as num?), style: serif(16)),
                            onTap: () => context.push('/book', extra: {'doctorId': d['id'], 'online': true}),
                          ),
                      ]),
                      const SectionTitle('Location & hours'),
                      LvCard(
                        child: Row(children: [
                          const IconBox(Icons.location_on_rounded),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(d.obj('branch').str('name', 'Lavish Medical Spa'), style: const TextStyle(fontWeight: FontWeight.w500)),
                              Muted('$days · 8:30 AM – 5:30 PM', size: 12.5),
                            ]),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 24),
                    ]),
                  ),
                ]),
              ),
              FootBar(
                child: Row(children: [
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: Material(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: C.line)),
                      child: InkWell(borderRadius: BorderRadius.circular(16), onTap: () => _chat(context, d), child: const Icon(Icons.chat_bubble_outline_rounded, color: C.ink)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: LvButton('Book appointment', icon: Icons.calendar_month_rounded, onTap: () => context.push('/book', extra: {'doctorId': d['id']}))),
                ]),
              ),
            ]);
          },
        )),
      );
}

class _Stat extends StatelessWidget {
  const _Stat(this.big, this.label, {this.small});
  final String big;
  final String label;
  final String? small;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(small != null && small!.length <= 12 ? small! : big, style: serif(small != null ? 17 : 22), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          Muted(label, size: 11.5),
        ]),
      );
}
