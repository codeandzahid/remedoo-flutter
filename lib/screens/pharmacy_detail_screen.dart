import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'cart_screen.dart';

/// Pharmacy detail: hero header, overlapping info card, category chips,
/// medicine list with ADD → stepper, sticky cart bar — matches PharmacyDetail.tsx.
///
/// ADD→stepper and detail-sheet add-to-cart behavior kept exactly as before;
/// only the visuals changed.
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
    if (state.isGuest) {
      return const GuestGate(message: 'Please login to view details');
    }
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
      bottomSheet: state.cartCount > 0 ? _cartBar(state) : null,
    );
  }

  Widget _hero(Pharmacy p) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 190,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? [RemedooTheme.darkSecondary, RemedooTheme.darkCard]
                    : [
                        const Color(0xFFF0E8DC),
                        const Color(0xFFF9F5EE),
                      ],
              ),
            ),
            child: const Center(
              child: Text('💊', style: TextStyle(fontSize: 76)),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  _CircleBtn(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.maybePop(context),
                  ),
                  const Spacer(),
                  _CircleBtn(
                    child: FavoriteButton(favKey: 'pharmacy:${p.id}'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactBody(AppState state, Pharmacy p, List<Medicine> list,
      List<String> categories) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _hero(p)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Transform.translate(
              offset: const Offset(0, -46),
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
        SliverToBoxAdapter(child: _hero(p)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Transform.translate(
              offset: const Offset(0, -46),
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
        ),
      ],
    );
  }

  Widget _infoCard(Pharmacy p) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
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
                        fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              if (p.verified)
                Icon(Icons.verified,
                    color: RemedooTheme.primary, size: 20),
            ],
          ),
          const SizedBox(height: 4),
          Text('${p.deliveryTime} • ${p.itemCount} items • ${p.location}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          Row(
            children: [
              RRatingPill(rating: p.rating),
              const Spacer(),
              GestureDetector(
                onTap: _directions,
                child: Row(
                  children: [
                    Icon(Icons.navigation_outlined,
                        size: 14, color: scheme.primary),
                    const SizedBox(width: 4),
                    Text('Get Directions',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: scheme.primary)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _categoryChips(List<String> categories) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories
            .map((c) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: RFilterChip(
                    label: c,
                    selected: _category == c,
                    onTap: () => setState(() => _category = c),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _sortRow(int count) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text('$count products',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _sort,
              isDense: true,
              icon: Icon(Icons.keyboard_arrow_down,
                  size: 15, color: scheme.onSurfaceVariant),
              style: TextStyle(
                fontFamily: RemedooTheme.fontFamily,
                fontSize: 12,
                color: scheme.onSurface,
              ),
              items: const ['Popular', 'Price Low→High', 'Price High→Low']
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: (v) => setState(() => _sort = v ?? 'Popular'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _orderPanel(AppState state, Pharmacy p) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Your order',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _orderRow('Delivery', p.deliveryTime),
          _orderRow('Items in cart', '${state.cartCount}'),
          Divider(height: 20, color: Theme.of(context).dividerColor),
          Row(
            children: [
              const Expanded(
                child: Text('Total',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              Text(inr(state.cartTotal),
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: RemedooTheme.primary)),
            ],
          ),
          const SizedBox(height: 16),
          if (state.cartCount > 0)
            RButton(
              label: 'Review Cart',
              fullWidth: true,
              onPressed: () => pushPage(context, const CartScreen()),
            )
          else
            Text('Your cart is empty — add medicines to get started.',
                style: TextStyle(
                    fontSize: 13, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text('Free delivery on orders above ₹499.',
              style: TextStyle(
                  fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
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
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SafeArea(
        child: Material(
          color: RemedooTheme.primary,
          borderRadius: BorderRadius.circular(18),
          elevation: 6,
          shadowColor: Colors.black.withValues(alpha: 0.2),
          child: InkWell(
            onTap: () => pushPage(context, const CartScreen()),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color:
                          Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                        Icons.shopping_cart_outlined,
                        color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${state.cartCount} item${state.cartCount == 1 ? '' : 's'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14),
                        ),
                        Text('Free delivery above ₹499',
                            style: TextStyle(
                                color: Colors.white
                                    .withValues(alpha: 0.85),
                                fontSize: 11)),
                      ],
                    ),
                  ),
                  Text(inr(state.cartTotal),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17)),
                  const SizedBox(width: 8),
                  const Text('View Cart →',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_forward_ios,
                      color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _medCard(Medicine m, AppState state) {
    final scheme = Theme.of(context).colorScheme;
    final qty = state.cartQty(m.id);
    return RCard(
      padding: EdgeInsets.zero,
      onTap: () => MedicineDetailSheet.show(context, m),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.medication_outlined,
                  color: scheme.primary, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (m.rxRequired)
                    Container(
                      margin: const EdgeInsets.only(bottom: 3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: RemedooTheme.warning
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Rx',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB45309))),
                    ),
                  Text(m.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  Text('${m.pack} • ${m.brand}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(inr(state.priceOf(m)),
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: RemedooTheme.primary)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(inr(m.mrp),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                decoration:
                                    TextDecoration.lineThrough,
                                color: scheme.onSurfaceVariant)),
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
                  minimumSize: const Size(0, 32),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  tapTargetSize:
                      MaterialTapTargetSize.shrinkWrap,
                  side: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .primary,
                      width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text('ADD',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
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
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData? icon;
  final Widget? child;
  final VoidCallback? onTap;

  const _CircleBtn({this.icon, this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final btn = Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: child ?? Icon(icon, size: 19, color: Colors.black87),
      ),
    );
    if (onTap == null) return btn;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: btn,
      ),
    );
  }
}
