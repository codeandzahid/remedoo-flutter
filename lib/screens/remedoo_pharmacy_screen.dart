import 'package:flutter/material.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'remedoo_checkout_screen.dart';

/// Remedoo's own pharmacy storefront.
class RemedooPharmacyScreen extends StatefulWidget {
  const RemedooPharmacyScreen({super.key});

  @override
  State<RemedooPharmacyScreen> createState() =>
      _RemedooPharmacyScreenState();
}

class _RemedooPharmacyScreenState extends State<RemedooPharmacyScreen> {
  String _category = 'All';

  void _add(AppState state, Medicine m) {
    if (state.addToCart(m, pharmacyId: 'remedoo', pharmacyName: 'Remedoo Pharmacy')) return;
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
              state.addToCart(m, pharmacyId: 'remedoo', pharmacyName: 'Remedoo Pharmacy');
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
    final all = state.activeMedicines.toList();
    final categories = ['All', ...{for (final m in all) m.category}];
    final list = _category == 'All'
        ? all
        : all.where((m) => m.category == _category).toList();
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 170,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                    gradient: RemedooTheme.headerGradient),
                child: const Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Remedoo Pharmacy',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800)),
                      Text(
                          'Genuine medicines • Delivered in 30 minutes',
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverGrid(
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.78,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final m = list[i];
                  final qty = state.cartQty(m.id);
                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () =>
                          MedicineDetailSheet.show(context, m),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: RemedooTheme.primary
                                      .withValues(alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                    Icons.medication,
                                    color: RemedooTheme.primary,
                                    size: 30),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(m.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                            Text(m.pack,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey)),
                            const Spacer(),
                            Text(inr(state.priceOf(m)),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: RemedooTheme.primary)),
                            const SizedBox(height: 6),
                            if (qty == 0)
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () => _add(state, m),
                                  style:
                                      OutlinedButton.styleFrom(
                                    minimumSize:
                                        const Size(0, 32),
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: const Text('ADD'),
                                ),
                              )
                            else
                              QtyStepper(
                                qty: qty,
                                onMinus: () => state
                                    .removeFromCart(m.id),
                                onPlus: () => _add(state, m),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: list.length,
              ),
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
                    color:
                        Colors.black.withValues(alpha: 0.12),
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
                        builder: (_) =>
                            const RemedooCheckoutScreen()),
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
                      const Text('Checkout →',
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
}
