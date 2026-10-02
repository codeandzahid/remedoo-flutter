import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'cart_screen.dart';

/// Pharmacy detail: info, category chips, medicine list, sticky cart bar.
class PharmacyDetailScreen extends StatefulWidget {
  final Pharmacy pharmacy;

  const PharmacyDetailScreen({super.key, required this.pharmacy});

  @override
  State<PharmacyDetailScreen> createState() => _PharmacyDetailScreenState();
}

class _PharmacyDetailScreenState extends State<PharmacyDetailScreen> {
  String _category = 'All';
  String _sort = 'Popular';

  List<Medicine> _list(AppState state) {
    var list = medicinesForPharmacy(widget.pharmacy.id)
        .where((m) => m.active)
        .toList();
    if (_category != 'All') {
      list = list.where((m) => m.category == _category).toList();
    }
    switch (_sort) {
      case 'Price Low→High':
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Price High→Low':
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
    }
    return list;
  }

  void _add(AppState state, Medicine m) {
    if (state.addToCart(m, pharmacyId: widget.pharmacy.id, pharmacyName: widget.pharmacy.name)) {
      if (m.rxRequired) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Prescription required — you can upload it at checkout.')),
        );
      }
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Switch pharmacy?'),
        content: const Text(
            'Your cart has items from another pharmacy. Clear it and add this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep cart'),
          ),
          FilledButton(
            onPressed: () {
              state.clearCart();
              state.addToCart(m, pharmacyId: widget.pharmacy.id, pharmacyName: widget.pharmacy.name);
              Navigator.pop(context);
            },
            child: const Text('Clear & add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final p = widget.pharmacy;
    final list = _list(state);
    final categories = [
      'All',
      ...{for (final m in medicinesForPharmacy(p.id)) m.category}
    ];
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 150,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                    gradient: RemedooTheme.headerGradient),
                child: const Center(
                  child: Icon(Icons.storefront,
                      color: Colors.white54, size: 72),
                ),
              ),
              title: Text(p.name),
            ),
            actions: [FavoriteButton(favKey: 'pharmacy:${p.id}')],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(p.name,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800)),
                              ),
                              if (p.verified)
                                const Icon(Icons.verified,
                                    color: RemedooTheme.primary),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                              '${p.deliveryTime} • ${p.itemCount} items • ${p.location}'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              RatingPill(rating: p.rating),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () => showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title:
                                        const Text('Directions'),
                                    content: const Text(
                                        'Opening maps… (demo)'),
                                    actions: [
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                ),
                                icon:
                                    const Icon(Icons.directions),
                                label:
                                    const Text('Get Directions'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final c = categories[i];
                        final sel = c == _category;
                        return Center(
                          child: ChoiceChip(
                            label: Text(c),
                            selected: sel,
                            onSelected: (_) =>
                                setState(() => _category = c),
                            selectedColor: RemedooTheme.primary,
                            labelStyle: TextStyle(
                                color: sel
                                    ? Colors.white
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurface),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('${list.length} products',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      DropdownButton<String>(
                        value: _sort,
                        underline: const SizedBox.shrink(),
                        items: const [
                          'Popular',
                          'Price Low→High',
                          'Price High→Low'
                        ]
                            .map((o) => DropdownMenuItem(
                                value: o, child: Text(o)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _sort = v ?? 'Popular'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: 10),
              itemBuilder: (_, i) => _medCard(list[i], state),
            ),
          ),
        ],
      ),
      bottomSheet: state.cartCount > 0
          ? Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: BoxDecoration(
                color: RemedooTheme.primary,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CartScreen()),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${state.cartCount} items • ${inr(state.cartTotal)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16),
                      ),
                      const Spacer(),
                      const Text('View Cart →',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _medCard(Medicine m, AppState state) {
    final qty = state.cartQty(m.id);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => MedicineDetailSheet.show(context, m),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: RemedooTheme.primary
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.medication,
                    color: RemedooTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (m.rxRequired)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Rx',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.orange)),
                      ),
                    Text(m.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700)),
                    Text('${m.pack} • ${m.brand}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                    Row(
                      children: [
                        Text(inr(state.priceOf(m)),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: RemedooTheme.primary)),
                        const SizedBox(width: 6),
                        Text(inr(m.mrp),
                            style: const TextStyle(
                                fontSize: 12,
                                decoration:
                                    TextDecoration.lineThrough,
                                color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
              if (qty == 0)
                OutlinedButton(
                  onPressed: () => _add(state, m),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 34),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text('ADD'),
                )
              else
                QtyStepper(
                  qty: qty,
                  onMinus: () => state.removeFromCart(m.id),
                  onPlus: () => _add(state, m),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
