import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
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
    if (state.addToCart(
        m, pharmacyId: widget.pharmacy.id, pharmacyName: widget.pharmacy.name)) {
      if (m.rxRequired) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Prescription required — you can upload it at checkout.')),
        );
      }
      return;
    }
    showResponsiveDialog(
      context,
      (c) => AlertDialog(
        title: const Text('Switch pharmacy?'),
        content: const Text(
            'Your cart has items from another pharmacy. Clear it and add this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Keep cart'),
          ),
          FilledButton(
            onPressed: () {
              state.clearCart();
              state.addToCart(m,
                  pharmacyId: widget.pharmacy.id,
                  pharmacyName: widget.pharmacy.name);
              Navigator.pop(c);
            },
            child: const Text('Clear & add'),
          ),
        ],
      ),
    );
  }

  void _directions() {
    showResponsiveDialog(
      context,
      (c) => AlertDialog(
        title: const Text('Directions'),
        content: const Text('Opening maps… (demo)'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('OK'),
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
      body: context.isCompact
          ? _compactBody(state, p, list, categories)
          : _wideBody(state, p, list, categories),
      bottomSheet:
          state.cartCount > 0 ? _cartBar(state) : null,
    );
  }

  Widget _appBar(Pharmacy p) {
    return SliverAppBar(
      expandedHeight: 150,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Hero(
          tag: 'pharmacy-image-${p.id}',
          child: Container(
            decoration:
                const BoxDecoration(gradient: RemedooTheme.headerGradient),
            child: const Center(
              child: Icon(Icons.storefront,
                  color: Colors.white54, size: 72),
            ),
          ),
        ),
        title: Text(p.name),
      ),
      actions: [FavoriteButton(favKey: 'pharmacy:${p.id}')],
    );
  }

  Widget _compactBody(AppState state, Pharmacy p, List<Medicine> list,
      List<String> categories) {
    return CustomScrollView(
      slivers: [
        _appBar(p),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoCard(p),
                const SizedBox(height: 12),
                _categoryChips(categories),
                const SizedBox(height: 8),
                _sortRow(list.length),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: SliverList.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => StaggerItem(
                index: i % 6, child: _medCard(list[i], state)),
          ),
        ),
      ],
    );
  }

  Widget _wideBody(AppState state, Pharmacy p, List<Medicine> list,
      List<String> categories) {
    return CustomScrollView(
      slivers: [
        _appBar(p),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DetailSplit(
              main: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _infoCard(p),
                  const SizedBox(height: 12),
                  _categoryChips(categories),
                  const SizedBox(height: 8),
                  _sortRow(list.length),
                  const SizedBox(height: 8),
                  for (var i = 0; i < list.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: StaggerItem(
                          index: i % 6,
                          child: _medCard(list[i], state)),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
              side: _orderPanel(state, p),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoCard(Pharmacy p) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                if (p.verified)
                  const Icon(Icons.verified,
                      color: RemedooTheme.primary),
              ],
            ),
            const SizedBox(height: 4),
            Text('${p.deliveryTime} • ${p.itemCount} items • ${p.location}',
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Row(
              children: [
                RatingPill(rating: p.rating),
                const Spacer(),
                TextButton.icon(
                  onPressed: _directions,
                  icon: const Icon(Icons.directions),
                  label: const Text('Get Directions'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryChips(List<String> categories) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = categories[i];
          final sel = c == _category;
          return Center(
            child: ChoiceChip(
              label: Text(c),
              selected: sel,
              onSelected: (_) => setState(() => _category = c),
              selectedColor: RemedooTheme.primary,
              labelStyle: TextStyle(
                  color: sel
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface),
            ),
          );
        },
      ),
    );
  }

  Widget _sortRow(int count) {
    return Row(
      children: [
        Expanded(
          child: Text('$count products',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        DropdownButton<String>(
          value: _sort,
          underline: const SizedBox.shrink(),
          items: const ['Popular', 'Price Low→High', 'Price High→Low']
              .map((o) =>
                  DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (v) => setState(() => _sort = v ?? 'Popular'),
        ),
      ],
    );
  }

  Widget _orderPanel(AppState state, Pharmacy p) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Your order',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _orderRow('Delivery', p.deliveryTime),
            _orderRow('Items in cart', '${state.cartCount}'),
            const Divider(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text('Total',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
                Text(inr(state.cartTotal),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: RemedooTheme.primary)),
              ],
            ),
            const SizedBox(height: 16),
            if (state.cartCount > 0)
              BigTargetButton(
                onPressed: () =>
                    pushPage(context, const CartScreen()),
                child: const Text('Review Cart'),
              )
            else
              const Text(
                'Your cart is empty — add medicines to get started.',
                style: TextStyle(color: Colors.grey),
              ),
            const SizedBox(height: 8),
            const Text(
              'Free delivery on orders above ₹499.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _cartBar(AppState state) {
    return Container(
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
          onTap: () => pushPage(context, const CartScreen()),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${state.cartCount} items • ${inr(state.cartTotal)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16),
                ),
              ),
              const Text('View Cart →',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
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
                  color:
                      RemedooTheme.primary.withValues(alpha: 0.1),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700)),
                    Text('${m.pack} • ${m.brand}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                    Row(
                      children: [
                        Text(inr(state.priceOf(m)),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: RemedooTheme.primary)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(inr(m.mrp),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  decoration:
                                      TextDecoration.lineThrough,
                                  color: Colors.grey)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
