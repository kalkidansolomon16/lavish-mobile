import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/phone_field.dart';
import '../../widgets/ui.dart';
import 'appointments.dart' show Steps, StepItem;

/// The cart lives on the phone; the server re-prices at checkout.
class Cart extends ChangeNotifier {
  Cart._();
  static final Cart instance = Cart._();

  final Map<int, (Json, int)> lines = {};
  int? prescriptionId;

  int get count => lines.values.fold(0, (a, l) => a + l.$2);
  int get subtotal => lines.values.fold(0, (a, l) => a + l.$1.integer('price') * l.$2);

  void add(Json p, [int qty = 1]) {
    final id = p['id'] as int;
    final have = lines[id]?.$2 ?? 0;
    final max = p.integer('available', 99);
    lines[id] = (p, (have + qty).clamp(1, max < 1 ? 1 : max));
    notifyListeners();
  }

  void set(int id, int qty) {
    if (qty <= 0) {
      lines.remove(id);
    } else if (lines[id] != null) {
      lines[id] = (lines[id]!.$1, qty);
    }
    notifyListeners();
  }

  void clear() {
    lines.clear();
    prescriptionId = null;
    notifyListeners();
  }
}

final cart = Cart.instance;

/// Product picture, or a soft coloured bottle when there is no photo (`.art`).
class ProductArt extends StatelessWidget {
  const ProductArt({super.key, required this.product, this.height = 140, this.radius = 16});
  final Json product;
  final double height;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final url = product.str('image_url');
    final hue = (product['hue'] as num?)?.toDouble() ?? 30;
    final c = HSLColor.fromAHSL(1, hue, .35, .45).toColor();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(gradient: LinearGradient(colors: [HSLColor.fromAHSL(1, hue, .45, .9).toColor(), HSLColor.fromAHSL(1, hue, .35, .8).toColor()], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Stack(alignment: Alignment.center, children: [
          if (url.isNotEmpty)
            Positioned.fill(child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()))
          else
            FractionallySizedBox(
              widthFactor: .3,
              heightFactor: .58,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.white.withValues(alpha: .96), Colors.white.withValues(alpha: .7)]),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10), bottom: Radius.circular(16)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 18, offset: const Offset(0, 10))],
                ),
                alignment: Alignment.center,
                child: Text('L', style: serif(height * .14, color: c)),
              ),
            ),
          if (product['in_stock'] == false)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: C.ink.withValues(alpha: .82), borderRadius: BorderRadius.circular(99)),
                child: const Text('Out of stock', style: TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ),
        ]),
      ),
    );
  }
}

class CartButton extends StatelessWidget {
  const CartButton({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: cart,
        builder: (_, _) => CircleIconButton(Icons.shopping_bag_outlined, boxed: true, count: cart.count, onTap: () => context.push('/cart')),
      );
}

// ---------------------------------------------------------------- shop

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  String cat = 'All';
  String q = '';

  @override
  Widget build(BuildContext context) {
    final cats = ['All', ...((session.config['product_categories'] as List?) ?? []).map((e) => e.toString())];
    return Scaffold(
      appBar: lvAppBar(context, 'Shop', actions: [
        CircleIconButton(Icons.receipt_long_outlined, onTap: () => context.push('/orders')),
        const SizedBox(width: 4),
        const CartButton(),
      ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: TextField(
            onSubmitted: (v) => setState(() => q = v.trim()),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search skincare, haircare…',
              prefixIcon: const Icon(Icons.search_rounded, color: C.muted),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: C.line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: C.line)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: C.dark)),
            ),
          ),
        ),
        if (cats.length > 1) ChipBar<String>(items: [for (final c in cats) (c, c)], value: cat, onChanged: (v) => setState(() => cat = v)),
        const SizedBox(height: 12),
        Expanded(
          child: Loader<List<Json>>(
            key: ValueKey('$cat|$q'),
            load: () async => listOf(await api.get('/catalog/products', {'category': cat == 'All' ? null : cat, 'q': q, 'per_page': 60})),
            builder: (context, list, _) => list.isEmpty
                ? ListView(children: const [Empty(icon: Icons.inventory_2_outlined, title: 'Nothing found', text: 'Try another category or search.')])
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .64),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _ProductCard(p: list[i]),
                  ),
          ),
        ),
      ]),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.p});
  final Json p;
  @override
  Widget build(BuildContext context) => LvCard(
        padding: const EdgeInsets.all(8),
        onTap: () => context.push('/product/${p['id']}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ProductArt(product: p, height: 140, radius: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Muted('${p.str('category')}${p.str('size').isNotEmpty ? ' · ${p.str('size')}' : ''}', size: 11.5, maxLines: 1),
              const SizedBox(height: 2),
              SizedBox(height: 36, child: Text(p.str('name'), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5, height: 1.3))),
            ]),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 0, 2),
            child: Row(children: [
              Expanded(child: Text(etb(p['price'] as num?), style: serif(18))),
              SizedBox(
                width: 34,
                height: 34,
                child: Material(
                  color: p['in_stock'] == false ? const Color(0xFFE6E5E2) : C.dark,
                  borderRadius: BorderRadius.circular(11),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(11),
                    onTap: p['in_stock'] == false
                        ? null
                        : () {
                            cart.add(p);
                            toast(context, '${p.str('name')} added to your bag');
                          },
                    child: Icon(Icons.add_rounded, color: p['in_stock'] == false ? const Color(0xFFAAAAAA) : Colors.white, size: 20),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      );
}

// ---------------------------------------------------------------- product

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key, required this.id});
  final int id;
  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  int qty = 1;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(actions: const [CartButton(), SizedBox(width: 12)]),
        body: Loader<Json>(
          load: () async => dataOf(await api.get('/catalog/products/${widget.id}')),
          builder: (context, p, _) {
            final inStock = p['in_stock'] != false;
            return Column(children: [
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
                  ProductArt(product: p, height: 280, radius: 24),
                  const SizedBox(height: 18),
                  Label('${p.str('category')}${p.str('size').isNotEmpty ? ' · ${p.str('size')}' : ''}'),
                  const SizedBox(height: 4),
                  Text(p.str('name'), style: serif(28)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Text(etb(p['price'] as num?), style: serif(24, color: C.dark)),
                    const Spacer(),
                    Pill(inStock ? (p.integer('available') <= 5 ? 'Only ${p.integer('available')} left' : 'In stock') : 'Out of stock', tone: inStock ? (p.integer('available') <= 5 ? Tone.warn : Tone.ok) : Tone.grey),
                  ]),
                  if (p.str('description').isNotEmpty) ...[const SectionTitle('About', top: 22), Text(p.str('description'), style: const TextStyle(height: 1.55, color: Color(0xFF4A4A4A)))],
                  if (p.str('usage').isNotEmpty) ...[
                    const SectionTitle('How to use', top: 22),
                    Banner2(icon: Icons.tips_and_updates_outlined, text: Text(p.str('usage'))),
                  ],
                  const SizedBox(height: 16),
                  const Banner2(tone: Tone.gold, icon: Icons.local_shipping_outlined, text: Text('Delivered in Addis Ababa, Adama and Dire Dawa. Pay on delivery or pay first and upload your receipt.')),
                ]),
              ),
              FootBar(
                child: inStock
                    ? Row(children: [
                        Container(
                          decoration: BoxDecoration(border: Border.all(color: C.line), borderRadius: BorderRadius.circular(12)),
                          child: Row(children: [
                            IconButton(onPressed: qty > 1 ? () => setState(() => qty--) : null, icon: const Icon(Icons.remove_rounded, color: C.dark, size: 18)),
                            Text('$qty', style: const TextStyle(fontWeight: FontWeight.w500)),
                            IconButton(onPressed: qty < p.integer('available', 99) ? () => setState(() => qty++) : null, icon: const Icon(Icons.add_rounded, color: C.dark, size: 18)),
                          ]),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: LvButton('Add to bag · ${etb(p.integer('price') * qty)}', onTap: () {
                            cart.add(p, qty);
                            toast(context, 'Added to your bag');
                          }),
                        ),
                      ])
                    : LvButton('Notify me when it’s back', kind: BtnKind.soft, icon: Icons.notifications_active_outlined, onTap: () async {
                        try {
                          await api.post('/client/products/${p['id']}/notify-me');
                          if (context.mounted) toast(context, 'We’ll let you know when it’s back in stock');
                        } catch (e) {
                          if (context.mounted) showError(context, e);
                        }
                      }),
              ),
            ]);
          },
        ),
      );
}

// ---------------------------------------------------------------- cart & checkout

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: cart,
        builder: (context, _) {
          final fee = (session.config['delivery_fee'] as num?)?.toInt() ?? 0;
          return Scaffold(
            appBar: lvAppBar(context, 'Your bag', subtitle: cart.count == 0 ? null : '${cart.count} item${cart.count == 1 ? '' : 's'}'),
            body: cart.lines.isEmpty
                ? Empty(icon: Icons.shopping_bag_outlined, title: 'Your bag is empty', text: 'Add aftercare products from the shop.', action: 'Go to shop', onAction: () => context.go('/shop'))
                : ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
                    LvCard(
                      child: Column(children: [
                        for (final (i, e) in cart.lines.entries.indexed) ...[
                          if (i > 0) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: C.line)),
                          Row(children: [
                            SizedBox(width: 64, child: ProductArt(product: e.value.$1, height: 64, radius: 12)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(e.value.$1.str('name'), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                                Text(etb(e.value.$1['price'] as num?), style: serif(16)),
                              ]),
                            ),
                            Container(
                              decoration: BoxDecoration(border: Border.all(color: C.line), borderRadius: BorderRadius.circular(12)),
                              child: Row(children: [
                                _QtyBtn(Icons.remove_rounded, () => cart.set(e.key, e.value.$2 - 1)),
                                SizedBox(width: 22, child: Text('${e.value.$2}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w500))),
                                _QtyBtn(Icons.add_rounded, () => cart.set(e.key, e.value.$2 + 1)),
                              ]),
                            ),
                          ]),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 12),
                    LvCard(
                      child: KVList([
                        KV('Subtotal', etb(cart.subtotal)),
                        KV('Delivery', etb(fee)),
                        KV('Total', etb(cart.subtotal + fee), total: true),
                      ]),
                    ),
                  ]),
            bottomNavigationBar: cart.lines.isEmpty ? null : FootBar(child: LvButton('Checkout', onTap: () => context.push('/checkout'))),
          );
        },
      );
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn(this.icon, this.onTap);
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, child: SizedBox(width: 34, height: 34, child: Icon(icon, size: 18, color: C.dark)));
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final address = TextEditingController();
  final note = TextEditingController();
  final phone = PhoneController(text: session.user?['phone']?.toString() ?? '');
  String method = 'pay_on_delivery';
  bool busy = false;

  List<(String, String, String)> get methods => [
        ('pay_on_delivery', 'Pay on delivery', 'Cash or Telebirr to the courier'),
        ('telebirr', session.onlinePayments ? 'Telebirr' : 'Pay now · Telebirr', session.onlinePayments ? 'Pay in the app' : 'Pay, then upload your receipt'),
        ('cbe_birr', session.onlinePayments ? 'CBE Birr' : 'Pay now · CBE / bank', session.onlinePayments ? 'Pay in the app' : 'Pay, then upload your receipt'),
        if (session.onlinePayments) ('card', 'Card', 'Visa or Mastercard'),
      ];

  Future<void> _place() async {
    if (address.text.trim().length < 5) return toast(context, 'Enter your delivery address', error: true);
    final fee = (session.config['delivery_fee'] as num?)?.toInt() ?? 0;
    final ok = await confirm(context, title: 'Place this order?', body: '${cart.count} item${cart.count == 1 ? '' : 's'} · ${etb(cart.subtotal + fee)}\n${methods.firstWhere((m) => m.$1 == method).$2}', ok: 'Place order');
    if (!ok || !mounted) return;
    setState(() => busy = true);
    try {
      final o = dataOf(await api.post('/client/orders', {
        'items': [for (final e in cart.lines.entries) {'product_id': e.key, 'quantity': e.value.$2}],
        'delivery_address': address.text.trim(),
        'delivery_note': note.text.trim().isEmpty ? null : note.text.trim(),
        'contact_phone': phone.full.isEmpty ? null : phone.full,
        'payment_method': method,
        'prescription_id': cart.prescriptionId,
      }));
      cart.clear();
      if (!mounted) return;
      final pay = o.objOrNull('payment');
      context.go('/success', extra: {
        'icon': Icons.shopping_bag_rounded,
        'title': 'Order placed!',
        'text': method == 'pay_on_delivery' ? 'We’ll confirm it and let you know when it’s on the way.' : 'Pay now and upload your receipt — we start preparing your order once it’s confirmed.',
        'rows': [
          ['Order', o.str('tracking_code', '#${o['id']}')],
          ['Total', etb(o['total'] as num?)],
          ['Payment', o.enumLabel('payment_method')],
        ],
        'primary': method != 'pay_on_delivery' && pay != null ? {'label': 'Pay now', 'to': '/pay/${pay['id']}'} : {'label': 'Track order', 'to': '/order/${o['id']}'},
        'secondary': {'label': 'Back to shop', 'to': '/shop'},
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'insufficient_stock') {
        final id = e.details['product_id'];
        final left = (e.details['available'] as num?)?.toInt() ?? 0;
        if (id is int) cart.set(id, left);
        toast(context, '${e.message} We updated your bag.', error: true);
      } else {
        showError(context, e);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fee = (session.config['delivery_fee'] as num?)?.toInt() ?? 0;
    return Scaffold(
      appBar: lvAppBar(context, 'Checkout'),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
        const SectionTitle('Delivery', top: 4),
        Field(label: 'Address', controller: address, icon: Icons.location_on_outlined, hint: 'e.g. Bole, around Edna Mall, Addis Ababa', maxLines: 2),
        PhoneField(label: 'Phone for the courier', controller: phone),
        Field(label: 'Note (optional)', controller: note, hint: 'e.g. Call when you arrive'),
        const SectionTitle('Payment', top: 10),
        for (final (v, t, s) in methods)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: RadioCard(selected: method == v, title: t, subtitle: s, onTap: () => setState(() => method = v))),
        const SizedBox(height: 8),
        LvCard(child: KVList([KV('Items', etb(cart.subtotal)), KV('Delivery', etb(fee)), KV('Total', etb(cart.subtotal + fee), total: true)])),
      ]),
      bottomNavigationBar: FootBar(child: LvButton('Place order · ${etb(cart.subtotal + fee)}', onTap: _place, busy: busy)),
    );
  }
}

// ---------------------------------------------------------------- orders

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: lvAppBar(context, 'My orders'),
        body: Loader<List<Json>>(
          load: () async => listOf(await api.get('/client/orders')),
          builder: (context, list, _) => list.isEmpty
              ? ListView(children: [Empty(icon: Icons.shopping_bag_outlined, title: 'No orders yet', text: 'Products you order from the shop appear here.', action: 'Go to shop', onAction: () => context.go('/shop'))])
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final o = list[i];
                    return LvCard(
                      onTap: () => context.push('/order/${o['id']}'),
                      child: Row(children: [
                        const IconBox(Icons.shopping_bag_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(o.str('tracking_code', 'Order #${o['id']}'), style: const TextStyle(fontWeight: FontWeight.w500)),
                            Muted('${dayLong(o.str('created_at'))} · ${o.integer('items_count')} item${o.integer('items_count') == 1 ? '' : 's'} · ${etb(o['total'] as num?)}', size: 12.5),
                          ]),
                        ),
                        Pill(o.str('status_label', o.str('status')), tone: Pill.toneOf(o.str('status'))),
                      ]),
                    );
                  },
                ),
        ),
      );
}

class OrderScreen extends StatelessWidget {
  const OrderScreen({super.key, required this.id});
  final int id;
  @override
  Widget build(BuildContext context) => Loader<Json>(
        load: () async => dataOf(await api.get('/client/orders/$id')),
        builder: (context, o, reload) {
          final pay = o.objOrNull('payment');
          final cancelled = o.str('status') == 'cancelled';
          return Scaffold(
            appBar: lvAppBar(context, o.str('tracking_code', 'Order #${o['id']}'), subtitle: 'Placed ${when(o.str('created_at'))}'),
            body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              if (cancelled)
                Banner2(tone: Tone.bad, icon: Icons.cancel_outlined, text: Text('This order was cancelled${o.str('cancel_reason').isNotEmpty ? ': ${o.str('cancel_reason')}' : '.'}'))
              else
                LvCard(child: Steps(steps: [for (final t in o.list('timeline')) StepItem(t.str('title'), t.str('at').isEmpty ? '' : when(t.str('at')), t.str('at').isNotEmpty)])),
              if (o.objOrNull('courier') != null) ...[
                const SizedBox(height: 12),
                LvCard(
                  child: Row(children: [
                    const IconBox(Icons.delivery_dining_rounded),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(o.obj('courier').str('name'), style: const TextStyle(fontWeight: FontWeight.w500)), const Muted('Your courier', size: 12)])),
                    Text(o.obj('courier').str('phone'), style: const TextStyle(color: C.dark, fontWeight: FontWeight.w500)),
                  ]),
                ),
              ],
              const SectionTitle('Items', top: 20),
              LvCard(
                child: Column(children: [
                  for (final it in o.list('items'))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        Expanded(child: Text('${it.integer('quantity')} × ${it.str('name')}')),
                        Text(etb(it['line_total'] as num?), style: const TextStyle(fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  const SizedBox(height: 6),
                  KVList([
                    KV('Delivery', etb(o['delivery_fee'] as num?)),
                    if (o.integer('discount') > 0) KV('Discount', '−${etb(o['discount'] as num?)}'),
                    KV('Total', etb(o['total'] as num?), total: true),
                  ]),
                ]),
              ),
              const SectionTitle('Delivery & payment', top: 20),
              LvCard(
                child: KVList([
                  KV('Address', o.str('delivery_address')),
                  KV('Payment', o.enumLabel('payment_method')),
                  if (pay != null) KV('Status', pay.str('status') == 'in_review' ? 'Receipt in review' : pay.str('status')),
                ]),
              ),
              if (pay != null && !cancelled && ['unpaid', 'failed', 'in_review'].contains(pay.str('status')) && o.enumValue('payment_method') != 'pay_on_delivery') ...[
                const SizedBox(height: 14),
                LvButton(pay.str('status') == 'in_review' ? 'View receipt status' : 'Pay now', icon: Icons.payments_outlined, onTap: () async {
                  await context.push('/pay/${pay['id']}');
                  reload();
                }),
              ],
            ]),
          );
        },
      );
}
