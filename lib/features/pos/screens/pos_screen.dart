import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/product.dart';
import '../../../core/models/sale.dart';
import '../../../core/models/client.dart';
import '../../../core/models/debt.dart';
import '../../../core/providers/products_provider.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';

const _uuid = Uuid();

class CartItem {
  final Product product;
  int quantity;
  double customPrice;
  double discount;

  CartItem({
    required this.product,
    this.quantity = 1,
    required this.customPrice,
    this.discount = 0,
  });

  double get total => (customPrice - discount) * quantity;
  double get profit =>
      (customPrice - discount - product.purchasePrice) * quantity;
}

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final List<CartItem> _cart = [];
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  Client? _selectedClient;
  bool _isProcessing = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  double get _total => _cart.fold(0, (sum, item) => sum + item.total);
  double get _totalProfit => _cart.fold(0, (sum, item) => sum + item.profit);

  void _addToCart(Product product) {
    setState(() {
      final index = _cart.indexWhere((i) => i.product.id == product.id);
      if (index != -1) {
        _cart[index].quantity++;
      } else {
        _cart.add(CartItem(
          product: product,
          customPrice: product.sellingPrice,
        ));
      }
    });
  }

  void _removeFromCart(int index) {
    setState(() => _cart.removeAt(index));
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
      _selectedClient = null;
      _searchCtrl.clear();
      _searchQuery = '';
    });
  }

  void _showEditItemDialog(int index) {
    final item = _cart[index];
    final priceCtrl = TextEditingController(
        text: item.customPrice.toStringAsFixed(0));
    final discountCtrl = TextEditingController(
        text: item.discount.toStringAsFixed(0));
    final qtyCtrl = TextEditingController(
        text: item.quantity.toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(item.product.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: qtyCtrl,
              decoration: const InputDecoration(labelText: 'Quantité'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: priceCtrl,
              decoration: const InputDecoration(
                labelText: 'Prix unitaire',
                suffixText: 'F',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: discountCtrl,
              decoration: const InputDecoration(
                labelText: 'Remise par unité',
                suffixText: 'F',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _cart[index].quantity =
                    int.tryParse(qtyCtrl.text) ?? 1;
                _cart[index].customPrice =
                    double.tryParse(priceCtrl.text) ??
                        item.product.sellingPrice;
                _cart[index].discount =
                    double.tryParse(discountCtrl.text) ?? 0;
              });
              Navigator.pop(context);
            },
            child: const Text('Appliquer'),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog() {
    if (_cart.isEmpty) return;
    final paidCtrl =
        TextEditingController(text: _total.toStringAsFixed(0));
    PaymentMethod selectedMethod = PaymentMethod.cash;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Encaissement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Total
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total à payer',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        '${_total.toStringAsFixed(0)} F',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Mode de paiement
                const Text('Mode de paiement',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _PaymentChip(
                      label: 'Espèces',
                      icon: Icons.money,
                      selected: selectedMethod == PaymentMethod.cash,
                      onTap: () => setDialogState(
                          () => selectedMethod = PaymentMethod.cash),
                    ),
                    _PaymentChip(
                      label: 'Mobile money',
                      icon: Icons.phone_android,
                      selected:
                          selectedMethod == PaymentMethod.mobileMoney,
                      onTap: () => setDialogState(() =>
                          selectedMethod = PaymentMethod.mobileMoney),
                    ),
                    _PaymentChip(
                      label: 'Carte',
                      icon: Icons.credit_card,
                      selected: selectedMethod == PaymentMethod.card,
                      onTap: () => setDialogState(
                          () => selectedMethod = PaymentMethod.card),
                    ),
                    _PaymentChip(
                      label: 'Dette',
                      icon: Icons.person_outline,
                      selected: selectedMethod == PaymentMethod.debt,
                      onTap: () => setDialogState(
                          () => selectedMethod = PaymentMethod.debt),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Montant payé
                TextFormField(
                  controller: paidCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Montant reçu',
                    suffixText: 'F',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 8),

                // Monnaie à rendre
                AnimatedBuilder(
                  animation: paidCtrl,
                  builder: (_, __) {
                    final paid = double.tryParse(paidCtrl.text) ?? 0;
                    final change = paid - _total;
                    if (change <= 0) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Monnaie à rendre'),
                          Text(
                            '${change.toStringAsFixed(0)} F',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.secondary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Client requis pour dette
                if (selectedMethod == PaymentMethod.debt) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.warning.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: AppTheme.warning, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedClient != null
                                ? 'Client : ${_selectedClient!.name}'
                                : 'Sélectionne un client avant de valider',
                            style: TextStyle(
                              color: AppTheme.warning,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: _isProcessing
                  ? null
                  : () => _processSale(
                        ctx,
                        paidCtrl.text,
                        selectedMethod,
                      ),
              child: const Text('Valider la vente'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processSale(
    BuildContext dialogContext,
    String paidText,
    PaymentMethod method,
  ) async {
    if (method == PaymentMethod.debt && _selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sélectionne un client pour une vente à crédit'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final paid = double.tryParse(paidText) ?? _total;
      final actualPaid = method == PaymentMethod.debt ? 0.0 : paid;

      final sale = Sale(
        id: _uuid.v4(),
        items: _cart
            .map((item) => SaleItem(
                  productId: item.product.id,
                  productName: item.product.name,
                  unitPrice: item.customPrice,
                  purchasePrice: item.product.purchasePrice,
                  quantity: item.quantity,
                  discount: item.discount,
                ))
            .toList(),
        totalAmount: _total,
        paidAmount: actualPaid,
        paymentMethod: method,
        status: method == PaymentMethod.debt
            ? SaleStatus.partial
            : SaleStatus.completed,
        clientId: _selectedClient?.id,
        clientName: _selectedClient?.name,
        createdAt: DateTime.now(),
      );

      await DatabaseHelper.insertSale(sale);

      // Mettre à jour le stock
      for (final item in _cart) {
        final newStock = item.product.stock - item.quantity;
        await DatabaseHelper.updateProductStock(
            item.product.id, newStock.clamp(0, 999999));
      }

      // Créer la dette si nécessaire
      if (method == PaymentMethod.debt && _selectedClient != null) {
        final debt = Debt(
          id: _uuid.v4(),
          clientId: _selectedClient!.id,
          clientName: _selectedClient!.name,
          saleId: sale.id,
          originalAmount: _total,
          remainingAmount: _total,
          createdAt: DateTime.now(),
        );
        await DatabaseHelper.insertDebt(debt);
        await DatabaseHelper.updateClientDebt(
          _selectedClient!.id,
          _selectedClient!.totalDebt + _total,
        );
      }

      // Rafraîchir les produits
      await ref.read(productsProvider.notifier).reload();

      if (mounted) Navigator.pop(dialogContext);

      // Confirmation
      if (mounted) {
        final change =
            method != PaymentMethod.debt ? (paid - _total) : 0.0;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.secondary),
                SizedBox(width: 8),
                Text('Vente enregistrée'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ReceiptRow(
                    label: 'Total', value: '${_total.toStringAsFixed(0)} F'),
                if (method != PaymentMethod.debt)
                  _ReceiptRow(
                      label: 'Reçu',
                      value: '${paid.toStringAsFixed(0)} F'),
                if (change > 0)
                  _ReceiptRow(
                    label: 'Monnaie',
                    value: '${change.toStringAsFixed(0)} F',
                    highlight: true,
                  ),
                if (method == PaymentMethod.debt)
                  _ReceiptRow(
                    label: 'Dette créée',
                    value: '${_total.toStringAsFixed(0)} F',
                    highlight: true,
                    color: AppTheme.warning,
                  ),
                const Divider(),
                _ReceiptRow(
                  label: 'Bénéfice',
                  value: '${_totalProfit.toStringAsFixed(0)} F',
                  color: AppTheme.secondary,
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  _clearCart();
                },
                child: const Text('Nouvelle vente'),
              ),
            ],
          ),
        );
      }
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
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showClientPicker() async {
    final clients = await DatabaseHelper.getClients();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Sélectionner un client',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          const Divider(height: 1),
          Expanded(
            child: clients.isEmpty
                ? const Center(child: Text('Aucun client enregistré'))
                : ListView.builder(
                    itemCount: clients.length,
                    itemBuilder: (_, i) => ListTile(
                      leading: const CircleAvatar(
                          child: Icon(Icons.person)),
                      title: Text(clients[i].name),
                      subtitle: clients[i].totalDebt > 0
                          ? Text(
                              'Dette : ${clients[i].totalDebt.toStringAsFixed(0)} F',
                              style: const TextStyle(
                                  color: AppTheme.warning),
                            )
                          : null,
                      onTap: () {
                        setState(
                            () => _selectedClient = clients[i]);
                        Navigator.pop(context);
                      },
                    ),
                  ),
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
        title: const Text('Caisse'),
        actions: [
          if (_selectedClient != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Chip(
                avatar: const Icon(Icons.person, size: 16),
                label: Text(_selectedClient!.name),
                onDeleted: () =>
                    setState(() => _selectedClient = null),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: _showClientPicker,
            tooltip: 'Associer un client',
          ),
          if (_cart.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _clearCart,
              tooltip: 'Vider le panier',
            ),
        ],
      ),
      body: productsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (products) {
          final filtered = products
              .where((p) =>
                  p.name
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase()) ||
                  (p.barcode?.contains(_searchQuery) ?? false))
              .toList();

          return Column(
            children: [
              // Barre de recherche
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un produit...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) =>
                      setState(() => _searchQuery = v),
                ),
              ),

              // Grille produits
              Expanded(
                flex: 5,
                child: filtered.isEmpty
                    ? const Center(
                        child: Text('Aucun produit trouvé'))
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) =>
                            _ProductTile(
                          product: filtered[i],
                          onTap: () => _addToCart(filtered[i]),
                        ),
                      ),
              ),

              // Panier
              if (_cart.isNotEmpty) ...[
                const Divider(height: 1),
                Container(
                  constraints:
                      const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    itemCount: _cart.length,
                    itemBuilder: (_, i) => _CartRow(
                      item: _cart[i],
                      onEdit: () => _showEditItemDialog(i),
                      onRemove: () => _removeFromCart(i),
                    ),
                  ),
                ),
                // Total + bouton payer
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: AppTheme.cardBg,
                    border: Border(
                        top: BorderSide(color: AppTheme.border)),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text('Total',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12)),
                          Text(
                            '${_total.toStringAsFixed(0)} F',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _showPaymentDialog,
                          icon: const Icon(Icons.payment),
                          label: const Text('Encaisser',
                              style: TextStyle(fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductTile(
      {required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final outOfStock = product.isOutOfStock;
    return GestureDetector(
      onTap: outOfStock ? null : onTap,
      child: Opacity(
        opacity: outOfStock ? 0.5 : 1,
        child: Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12)),
                  child: product.imageUrl != null
                      ? Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _placeholder(),
                        )
                      : _placeholder(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${product.sellingPrice.toStringAsFixed(0)} F',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'x${product.stock}',
                          style: TextStyle(
                            fontSize: 10,
                            color: product.isLowStock
                                ? AppTheme.warning
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppTheme.border,
      child: const Icon(Icons.image_outlined,
          color: AppTheme.textSecondary),
    );
  }
}

class _CartRow extends StatelessWidget {
  final CartItem item;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _CartRow(
      {required this.item,
      required this.onEdit,
      required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onEdit,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.product.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13)),
                  Text(
                    '${item.quantity} x ${item.customPrice.toStringAsFixed(0)} F'
                    '${item.discount > 0 ? ' (-${item.discount.toStringAsFixed(0)} F)' : ''}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          Text(
            '${item.total.toStringAsFixed(0)} F',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close,
                size: 18, color: AppTheme.danger),
          ),
        ],
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withOpacity(0.1)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                selected ? AppTheme.primary : AppTheme.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: selected
                    ? AppTheme.primary
                    : AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected
                    ? FontWeight.w600
                    : FontWeight.normal,
                color: selected
                    ? AppTheme.primary
                    : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final Color? color;

  const _ReceiptRow({
    required this.label,
    required this.value,
    this.highlight = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(color: AppTheme.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontWeight: highlight
                  ? FontWeight.w700
                  : FontWeight.w500,
              fontSize: highlight ? 16 : 14,
              color: color ??
                  (highlight
                      ? AppTheme.primary
                      : AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}