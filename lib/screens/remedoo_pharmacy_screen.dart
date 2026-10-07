import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'remedoo_checkout_screen.dart';
import '../app_navigator.dart';

const _sortOptions = [
  'Relevance',
  'Price: Low to High',
  'Price: High to Low',
  'Biggest Discount',
  'Name: A to Z',
];

/// Remedoo's own pharmacy storefront — matches RemedooPharmacyPage.tsx
/// (12-remedoo-pharmacy.png). Cart behavior kept exactly as before.
class RemedooPharmacyScreen extends StatefulWidget {
  const RemedooPharmacyScreen({super.key});

  @override
  State<RemedooPharmacyScreen> createState() =>
      _RemedooPharmacyScreenState();
}

class _RemedooPharmacyScreenState extends State<RemedooPharmacyScreen> {
  String _category = 'All';
  String _sort = _sortOptions.first;
  final _search = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _add(AppState state, Medicine m) {
    if (state.addToCart(
        m, pharmacyId: 'remedoo', pharmacyName: 'Remedoo Pharmacy')) {
      return;
    }
    showResponsiveDialog(
      context,
      (c) => AlertDialog(
        title: const Text('One pharmacy at a time'),
        content: const Text(
            'You can order only from one pharmacy at once. Your cart has items from another pharmacy. Clear it and add this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Keep cart'),
          ),
          FilledButton(
            onPressed: () {
              state.clearCart();
              state.addToCart(m,
                  pharmacyId: 'remedoo',
                  pharmacyName: 'Remedoo Pharmacy');
              Navigator.pop(c);
            },
            child: const Text('Clear & add'),
          ),
        ],
      ),
    );
  }

  List<Medicine> _list(AppState state) {
    final all = state.activeMedicines.toList();
    var list = _category == 'All'
        ? all
        : all.where((m) => m.category == _category).toList();
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((m) =>
              m.name.toLowerCase().contains(q) ||
              m.pack.toLowerCase().contains(q) ||
              m.brand.toLowerCase().contains(q))
          .toList();
    }
    switch (_sort) {
      case 'Price: Low to High':
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Price: High to Low':
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'Biggest Discount':
        list.sort((a, b) =>
            (b.mrp - b.price).compareTo(a.mrp - a.price));
        break;
      case 'Name: A to Z':
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final all = state.activeMedicines.toList();
    final categories = ['All', ...{for (final m in all) m.category}];
    final list = _list(state);
    final aspect = const ResponsiveValue<double>(
      compact: 0.78,
      medium: 1.6,
      expanded: 1.35,
      wide: 0.85,
    ).of(context);
    return Scaffold(
      body: Column(
        children: [
          _stickyHeader(categories),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.delayed(
                    const Duration(milliseconds: 600));
                if (mounted) setState(() {});
              },
              child: _loading
                  ? _gridSkeleton(aspect)
                  : list.isEmpty
                      ? const REmptyState(
                          icon: Icons.medication_outlined,
                          title: 'No medicines found',
                          subtitle:
                              'Try searching by generic name or brand',
                        )
                      : _grid(list, state, aspect),
            ),
          ),
        ],
      ),
      bottomSheet: state.cartCount > 0 ? _cartFooter(state) : null,
    );
  }

  Widget _stickyHeader(List<String> categories) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  _BackCircle(
                      onTap: () => goBack(context)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Remedoo Pharmacy',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(width: 6),
                            Icon(Icons.verified,
                                size: 17, color: scheme.primary),
                          ],
                        ),
                        Text('Free delivery above ₹499',
                            style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: RSearchBar(
                hint: 'Search by name, brand, or generic…',
                controller: _search,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  ...categories.map((c) => Padding(
                        padding:
                            const EdgeInsets.only(right: 8),
                        child: RFilterChip(
                          label: c,
                          selected: _category == c,
                          onTap: () =>
                              setState(() => _category = c),
                        ),
                      )),
                  _sortPill(),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _sortPill() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sort, size: 14, color: scheme.primary),
          const SizedBox(width: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _sort,
              isDense: true,
              icon: Icon(Icons.keyboard_arrow_down,
                  size: 16, color: scheme.onSurfaceVariant),
              style: TextStyle(
                fontFamily: RemedooTheme.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
              items: _sortOptions
                  .map((o) =>
                      DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _sort = v ?? _sortOptions.first),
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid(
      List<Medicine> list, AppState state, double aspect) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          sliver: ResponsiveSliverGrid(
            compactCols: 2,
            mediumCols: 3,
            expandedCols: 4,
            wideCols: 6,
            childAspectRatio: aspect,
            itemCount: list.length,
            itemBuilder: (context, i) => _productCard(list[i], state),
          ),
        ),
      ],
    );
  }

  Widget _gridSkeleton(double aspect) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          sliver: ResponsiveSliverGrid(
            compactCols: 2,
            mediumCols: 3,
            expandedCols: 4,
            wideCols: 6,
            childAspectRatio: aspect,
            itemCount: 8,
            itemBuilder: (context, i) =>
                const SkeletonCard(height: 140),
          ),
        ),
      ],
    );
  }

  Widget _productCard(Medicine m, AppState state) {
    final scheme = Theme.of(context).colorScheme;
    final qty = state.cartQty(m.id);
    final price = state.priceOf(m);
    final discountPct =
        m.mrp > price ? ((m.mrp - price) / m.mrp * 100).round() : 0;
    return RCard(
      padding: const EdgeInsets.all(12),
      onTap: () => MedicineDetailSheet.show(context, m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Medicine image
          if (m.imageUrl != null && m.imageUrl!.isNotEmpty)
            Container(
              height: 80,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: scheme.surfaceContainerHighest,
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                m.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.medication_outlined,
                  size: 32,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5)),
                    Text(m.brand,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10.5,
                            color: scheme.primary,
                            fontWeight: FontWeight.w600)),
                    Text(m.pack,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10,
                            color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Column(
                children: [
                  if (m.rxRequired)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: scheme.onSurfaceVariant),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Rx',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant)),
                    ),
                  const SizedBox(height: 4),
                  Icon(Icons.info_outline,
                      size: 16, color: scheme.onSurfaceVariant),
                ],
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Text(inr(price),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(width: 5),
              if (m.mrp > price)
                Flexible(
                  child: Text(inr(m.mrp),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10.5,
                          decoration: TextDecoration.lineThrough,
                          color: scheme.onSurfaceVariant)),
                ),
              if (discountPct > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: RemedooTheme.success
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('$discountPct% off',
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: RemedooTheme.success)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (qty == 0)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _add(state, m),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding: EdgeInsets.zero,
                  side: BorderSide(
                      color: scheme.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text('ADD',
                    style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
              ),
            )
          else
            QtyStepper(
              qty: qty,
              onMinus: () => state.removeFromCart(m.id),
              onPlus: () => _add(state, m),
            ),
        ],
      ),
    );
  }

  Widget _cartFooter(AppState state) {
    final hasRx =
        state.cartLines.any((l) => l.medicine.rxRequired);
    final subtotal = state.cartTotal;
    final delivery = subtotal >= 499 ? 0.0 : 30.0;
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
            onTap: () {
              if (!checkLogin(context)) return;
              pushPage(context, const RemedooCheckoutScreen());
            },
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
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
                        if (hasRx)
                          Text('Prescription needed',
                              style: TextStyle(
                                  color: Colors.white
                                      .withValues(alpha: 0.85),
                                  fontSize: 10.5)),
                        if (delivery == 0)
                          Text('✓ Free delivery',
                              style: TextStyle(
                                  color: Colors.white
                                      .withValues(alpha: 0.85),
                                  fontSize: 10.5)),
                      ],
                    ),
                  ),
                  Text(inr(subtotal + delivery),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18)),
                  const SizedBox(width: 8),
                  const Text('Checkout →',
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
}

class _BackCircle extends StatelessWidget {
  final VoidCallback onTap;

  const _BackCircle({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color:
          dark ? RemedooTheme.darkSecondary : RemedooTheme.mutedSurface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 38,
          height: 38,
          child: Icon(Icons.arrow_back, size: 20),
        ),
      ),
    );
  }
}
