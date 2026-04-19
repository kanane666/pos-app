import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/product.dart';
import '../../../core/providers/products_provider.dart';
import '../../../core/theme/app_theme.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final Product? product;
  const ProductFormScreen({super.key, this.product});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _purchasePriceCtrl;
  late final TextEditingController _sellingPriceCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _alertStockCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _imageUrlCtrl;
  String _selectedUnit = 'pièce';

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _purchasePriceCtrl = TextEditingController(
        text: p != null ? p.purchasePrice.toStringAsFixed(0) : '');
    _sellingPriceCtrl = TextEditingController(
        text: p != null ? p.sellingPrice.toStringAsFixed(0) : '');
    _stockCtrl = TextEditingController(
        text: p != null ? p.stock.toString() : '0');
    _alertStockCtrl = TextEditingController(
        text: p != null ? p.alertStock.toString() : '5');
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    _categoryCtrl = TextEditingController(text: p?.category ?? 'Général');
    _imageUrlCtrl = TextEditingController(text: p?.imageUrl ?? '');
    _selectedUnit = p != null ? (p.description?.contains('unit:') == true
        ? p.description!.split('unit:').last
        : 'pièce') : 'pièce';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _sellingPriceCtrl.dispose();
    _stockCtrl.dispose();
    _alertStockCtrl.dispose();
    _barcodeCtrl.dispose();
    _categoryCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }
  

  double get _margin {
    final purchase = double.tryParse(_purchasePriceCtrl.text) ?? 0;
    final selling = double.tryParse(_sellingPriceCtrl.text) ?? 0;
    return selling - purchase;
  }

  double get _marginPercent {
    final purchase = double.tryParse(_purchasePriceCtrl.text) ?? 0;
    if (purchase == 0) return 0;
    return (_margin / purchase) * 100;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(productsProvider.notifier);
      final imageUrl = _imageUrlCtrl.text.trim().isEmpty
          ? null
          : _imageUrlCtrl.text.trim();
      final description = _descCtrl.text.trim().isEmpty
          ? 'unit:$_selectedUnit'
          : '${_descCtrl.text.trim()}|unit:$_selectedUnit';

      if (widget.product == null) {
        await notifier.addProduct(
          name: _nameCtrl.text.trim(),
          description: description,
          purchasePrice: double.parse(_purchasePriceCtrl.text),
          sellingPrice: double.parse(_sellingPriceCtrl.text),
          stock: int.parse(_stockCtrl.text),
          alertStock: int.parse(_alertStockCtrl.text),
          barcode: _barcodeCtrl.text.trim().isEmpty
              ? null
              : _barcodeCtrl.text.trim(),
          category: _categoryCtrl.text.trim().isEmpty
              ? 'Général'
              : _categoryCtrl.text.trim(),
          imageUrl: imageUrl,
        );
      } else {
        await notifier.editProduct(
          widget.product!.copyWith(
            name: _nameCtrl.text.trim(),
            description: description,
            purchasePrice: double.parse(_purchasePriceCtrl.text),
            sellingPrice: double.parse(_sellingPriceCtrl.text),
            stock: int.parse(_stockCtrl.text),
            alertStock: int.parse(_alertStockCtrl.text),
            barcode: _barcodeCtrl.text.trim().isEmpty
                ? null
                : _barcodeCtrl.text.trim(),
            category: _categoryCtrl.text.trim().isEmpty
                ? 'Général'
                : _categoryCtrl.text.trim(),
            imageUrl: imageUrl,
            updatedAt: DateTime.now(),
          ),
        );
      }
      if (mounted) context.go('/products');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Modifier produit' : 'Nouveau produit'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/products'),
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check, color: AppTheme.primary),
              label: const Text(
                'Enregistrer',
                style: TextStyle(color: AppTheme.primary),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Marge en temps réel
            AnimatedBuilder(
              animation: Listenable.merge(
                  [_purchasePriceCtrl, _sellingPriceCtrl]),
              builder: (context, _) {
                final margin = _margin;
                final percent = _marginPercent;
                final isPositive = margin >= 0;
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? AppTheme.secondary.withOpacity(0.08)
                        : AppTheme.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPositive
                          ? AppTheme.secondary.withOpacity(0.3)
                          : AppTheme.danger.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Marge estimée',
                            style: TextStyle(
                              fontSize: 12,
                              color: isPositive
                                  ? AppTheme.secondary
                                  : AppTheme.danger,
                            ),
                          ),
                          Text(
                            '${margin.toStringAsFixed(0)} F',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: isPositive
                                  ? AppTheme.secondary
                                  : AppTheme.danger,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isPositive
                              ? AppTheme.secondary.withOpacity(0.15)
                              : AppTheme.danger.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${percent.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isPositive
                                ? AppTheme.secondary
                                : AppTheme.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Nom
            _SectionLabel(label: 'Informations générales'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom du produit *',
                prefixIcon: Icon(Icons.label_outline),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Nom obligatoire' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optionnel)',
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _categoryCtrl,
              decoration: const InputDecoration(
                labelText: 'Catégorie',
                prefixIcon: Icon(Icons.category_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _barcodeCtrl,
              decoration: const InputDecoration(
                labelText: 'Code-barres (optionnel)',
                prefixIcon: Icon(Icons.qr_code),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),

            // Unité de vente
            _SectionLabel(label: 'Unité de vente'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: ['pièce', 'kg', 'g', 'litre', 'ml', 'boîte', 'sachet', 'mètre']
                  .map((unit) => ChoiceChip(
                        label: Text(unit),
                        selected: _selectedUnit == unit,
                        onSelected: (_) => setState(() => _selectedUnit = unit),
                        selectedColor: AppTheme.primary.withOpacity(0.15),
                        labelStyle: TextStyle(
                          color: _selectedUnit == unit
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                          fontWeight: _selectedUnit == unit
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: _selectedUnit == unit
                              ? AppTheme.primary
                              : AppTheme.border,
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),

            // Photo URL
            _SectionLabel(label: 'Photo du produit'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _imageUrlCtrl,
              decoration: const InputDecoration(
                labelText: 'URL de la photo (optionnel)',
                prefixIcon: Icon(Icons.image_outlined),
                hintText: 'https://exemple.com/photo.jpg',
              ),
            ),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _imageUrlCtrl,
              builder: (context, _) {
                if (_imageUrlCtrl.text.trim().isEmpty) {
                  return Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppTheme.border.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_outlined,
                              size: 36, color: AppTheme.textSecondary),
                          SizedBox(height: 6),
                          Text('Aperçu de la photo',
                              style: TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  );
                }
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _imageUrlCtrl.text.trim(),
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.danger.withOpacity(0.3)),
                      ),
                      child: const Center(
                        child: Text('URL invalide',
                            style: TextStyle(color: AppTheme.danger)),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Prix
            _SectionLabel(label: 'Prix'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _purchasePriceCtrl,
                    decoration: const InputDecoration(
                      labelText: "Prix d'achat *",
                      suffixText: 'F',
                      prefixIcon: Icon(Icons.shopping_cart_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Obligatoire';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _sellingPriceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Prix de vente *',
                      suffixText: 'F',
                      prefixIcon: Icon(Icons.sell_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Obligatoire';
                      if (double.parse(v) <= 0) return 'Prix invalide';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Stock
            _SectionLabel(label: 'Stock'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stockCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Stock initial *',
                      prefixIcon: Icon(Icons.inventory_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Obligatoire' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _alertStockCtrl,
                    decoration: const InputDecoration(
                      labelText: "Alerte stock bas",
                      prefixIcon: Icon(Icons.notifications_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Obligatoire' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _save,
              icon: const Icon(Icons.check),
              label: Text(
                isEdit ? 'Enregistrer les modifications' : 'Créer le produit',
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}