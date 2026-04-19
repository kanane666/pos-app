import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/products_provider.dart';
import '../../../core/models/product.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  String _filter = 'all';

  void _showAdjustDialog(Product product) {
    final stockCtrl = TextEditingController(
        text: product.stock.toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Ajuster le stock — ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Stock actuel'),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: product.isOutOfStock
                        ? AppTheme.danger.withOpacity(0.1)
                        : product.isLowStock
                            ? AppTheme.warning.withOpacity(0.1)
                            : AppTheme.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${product.stock}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: product.isOutOfStock
                          ? AppTheme.danger
                          : product.isLowStock
                              ? AppTheme.warning
                              : AppTheme.secondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: stockCtrl,
              decoration: const InputDecoration(
                labelText: 'Nouveau stock',
                prefixIcon: Icon(Icons.inventory_outlined),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newStock = int.tryParse(stockCtrl.text) ?? 0;
              await DatabaseHelper.updateProductStock(
                  product.id, newStock);
              await ref.read(productsProvider.notifier).reload();
              if (mounted) {
                Navigator.of(context, rootNavigator: true).pop();
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (products) {
          // Stats globales
          final outOfStock =
              products.where((p) => p.isOutOfStock).length;
          final lowStock = products
              .where((p) => p.isLowStock && !p.isOutOfStock)
              .length;
          final total = products.length;

          // Filtrage
          final filtered = products.where((p) {
            if (_filter == 'out') return p.isOutOfStock;
            if (_filter == 'low') return p.isLowStock && !p.isOutOfStock;
            return true;
          }).toList();

          return Column(
            children: [
              // Stats cards
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _StockStatCard(
                      label: 'Total produits',
                      value: '$total',
                      color: AppTheme.primary,
                      onTap: () => setState(() => _filter = 'all'),
                      selected: _filter == 'all',
                    ),
                    const SizedBox(width: 8),
                    _StockStatCard(
                      label: 'Stock bas',
                      value: '$lowStock',
                      color: AppTheme.warning,
                      onTap: () => setState(() => _filter = 'low'),
                      selected: _filter == 'low',
                    ),
                    const SizedBox(width: 8),
                    _StockStatCard(
                      label: 'Rupture',
                      value: '$outOfStock',
                      color: AppTheme.danger,
                      onTap: () => setState(() => _filter = 'out'),
                      selected: _filter == 'out',
                    ),
                  ],
                ),
              ),

              // Liste produits
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          _filter == 'out'
                              ? 'Aucune rupture de stock'
                              : _filter == 'low'
                                  ? 'Aucun stock bas'
                                  : 'Aucun produit',
                          style: const TextStyle(
                              color: AppTheme.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final product = filtered[i];
                          return Card(
                            child: ListTile(
                              onTap: () =>
                                  _showAdjustDialog(product),
                              leading: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(8),
                                child: product.imageUrl != null
                                    ? Image.network(
                                        product.imageUrl!,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (_, __, ___) =>
                                                _stockPlaceholder(),
                                      )
                                    : _stockPlaceholder(),
                              ),
                              title: Text(
                                product.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                product.category,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4),
                                    decoration: BoxDecoration(
                                      color: product.isOutOfStock
                                          ? AppTheme.danger
                                              .withOpacity(0.1)
                                          : product.isLowStock
                                              ? AppTheme.warning
                                                  .withOpacity(0.1)
                                              : AppTheme.secondary
                                                  .withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${product.stock}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: product.isOutOfStock
                                            ? AppTheme.danger
                                            : product.isLowStock
                                                ? AppTheme.warning
                                                : AppTheme.secondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.edit_outlined,
                                      size: 18,
                                      color: AppTheme.textSecondary),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _stockPlaceholder() {
    return Container(
      width: 48,
      height: 48,
      color: AppTheme.border,
      child: const Icon(Icons.inventory_2_outlined,
          size: 20, color: AppTheme.textSecondary),
    );
  }
}

class _StockStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;
  final bool selected;

  const _StockStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? color.withOpacity(0.12)
                : AppTheme.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : AppTheme.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}