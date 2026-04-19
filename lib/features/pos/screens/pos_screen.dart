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

  void _showEditItemDialog(int index) async {
    final item = _cart[index];
    final settings = await DatabaseHelper.getSettings();
    final priceCtrl = TextEditingController(
        text: item.customPrice.toStringAsFixed(0));
    final qtyCtrl = TextEditingController(
        text: item.quantity.toString());

    final purchasePrice = item.product.purchasePrice;
    final sellingPrice = item.product.sellingPrice;
    final maxDiscountAmount = sellingPrice * (settings.maxDiscountPercent / 100);
    final priceAfterMaxDiscount = sellingPrice - maxDiscountAmount;

    // Prix minimum = le plus élevé entre :
    // - prix après réduction max autorisée
    // - prix d'achat (si enforceMinPrice activé)
    final minAllowedPrice = settings.enforceMinPrice
        ? priceAfterMaxDiscount.clamp(purchasePrice, double.infinity)
        : priceAfterMaxDiscount.clamp(0, double.infinity);


    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialog) {
          final currentPrice =
              double.tryParse(priceCtrl.text) ?? item.customPrice;
          final discount = item.product.sellingPrice - currentPrice;
          final discountPercent = item.product.sellingPrice > 0
              ? (discount / item.product.sellingPrice) * 100
              : 0.0;
          final isBelowMin = currentPrice < minAllowedPrice;

          return AlertDialog(
            title: Text(item.product.name),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info prix
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Prix de base',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary)),
                          Text(
                              '${item.product.sellingPrice.toStringAsFixed(0)} F',
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Prix d'achat",
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary)),
                          Text(
                              '${item.product.purchasePrice.toStringAsFixed(0)} F',
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              'Prix min (${settings.maxDiscountPercent.toStringAsFixed(0)}% max)',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary)),
                          Text(
                              '${minAllowedPrice.toStringAsFixed(0)} F',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.warning,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Quantité
                TextFormField(
                  controller: qtyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Quantité',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly
                  ],
                ),
                const SizedBox(height: 12),

                // Prix négocié
                TextFormField(
                  controller: priceCtrl,
                  decoration: InputDecoration(
                    labelText: 'Prix de vente négocié',
                    suffixText: 'F',
                    prefixIcon: const Icon(Icons.sell_outlined),
                    errorText: isBelowMin
                        ? 'Prix minimum : ${minAllowedPrice.toStringAsFixed(0)} F'
                        : null,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  onChanged: (_) => setDialog(() {}),
                ),
                const SizedBox(height: 8),

                // Réduction calculée
                if (discount > 0 && !isBelowMin)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Réduction appliquée',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.secondary)),
                        Text(
                          '-${discount.toStringAsFixed(0)} F (${discountPercent.toStringAsFixed(1)}%)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (isBelowMin)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.block,
                            size: 14, color: AppTheme.danger),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Prix trop bas — en dessous du seuil autorisé',
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.danger),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: isBelowMin
                    ? null
                    : () {
                        final newPrice =
                            double.tryParse(priceCtrl.text) ??
                                item.customPrice;
                        final newQty =
                            int.tryParse(qtyCtrl.text) ?? 1;
                        setState(() {
                          _cart[index].customPrice = newPrice;
                          _cart[index].quantity = newQty;
                          _cart[index].discount = 0;
                        });
                        Navigator.of(context, rootNavigator: true).pop();
                      },
                child: const Text('Appliquer'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPaymentDialog() {
    if (_cart.isEmpty) return;
    final paidCtrl =
        TextEditingController(text: _total.toStringAsFixed(0));
    double paidAmount = _total;
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
                if (selectedMethod != PaymentMethod.debt)
                  TextFormField(
                    controller: paidCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Montant reçu',
                      suffixText: 'F',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    onChanged: (v) {
                      paidAmount = double.tryParse(v) ?? _total;
                      setDialogState(() {});
                    },
                  ),
                const SizedBox(height: 8),

                // Monnaie à rendre — seulement si espèces/carte/mobile
                if (selectedMethod != PaymentMethod.debt)
                  AnimatedBuilder(
                    animation: paidCtrl,
                    builder: (_, __) {
                      final paid =
                          double.tryParse(paidCtrl.text) ?? 0;
                      final change = paid - _total;
                      if (change <= 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
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
                // Client requis pour dette
                if (selectedMethod == PaymentMethod.debt) ...[
                  const SizedBox(height: 12),
                  FutureBuilder<List<dynamic>>(
                    future: DatabaseHelper.getClients(),
                    builder: (context, snapshot) {
                      final clients = snapshot.data ?? [];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Choisir le client',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (clients.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.danger.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Aucun client — ajoute-en dans l\'onglet Clients',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.danger,
                                ),
                              ),
                            )
                          else
                            ...clients.map((client) => GestureDetector(
                                  onTap: () {
                                    setState(
                                        () => _selectedClient = client);
                                    setDialogState(() {});
                                  },
                                  child: Container(
                                    margin:
                                        const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _selectedClient?.id ==
                                              client.id
                                          ? AppTheme.primary
                                              .withOpacity(0.1)
                                          : AppTheme.surface,
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _selectedClient?.id ==
                                                client.id
                                            ? AppTheme.primary
                                            : AppTheme.border,
                                        width:
                                            _selectedClient?.id == client.id
                                                ? 2
                                                : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor:
                                              AppTheme.primary.withOpacity(0.1),
                                          child: Text(
                                            client.name[0].toUpperCase(),
                                            style: const TextStyle(
                                              color: AppTheme.primary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                client.name,
                                                style: TextStyle(
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  fontSize: 13,
                                                  color: _selectedClient
                                                              ?.id ==
                                                          client.id
                                                      ? AppTheme.primary
                                                      : AppTheme.textPrimary,
                                                ),
                                              ),
                                              if (client.totalDebt > 0)
                                                Text(
                                                  'Dette: ${client.totalDebt.toStringAsFixed(0)} F',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppTheme.warning,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        if (_selectedClient?.id == client.id)
                                          const Icon(Icons.check_circle,
                                              color: AppTheme.primary,
                                              size: 18),
                                      ],
                                    ),
                                  ),
                                )),
                        ],
                      );
                    },
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
                        paidAmount.toString(),
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
      final paid = method == PaymentMethod.debt
          ? 0.0
          : _total;

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
        paidAmount: paid,
        paymentMethod: method,
        status: method == PaymentMethod.debt
            ? SaleStatus.partial
            : SaleStatus.completed,
        clientId: _selectedClient?.id,
        clientName: _selectedClient?.name,
        createdAt: DateTime.now(),
      );

      await DatabaseHelper.insertSale(sale);

      for (final item in _cart) {
        final newStock = item.product.stock - item.quantity;
        await DatabaseHelper.updateProductStock(
            item.product.id, newStock.clamp(0, 999999));
      }

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

      await ref.read(productsProvider.notifier).reload();

      if (mounted) Navigator.of(dialogContext, rootNavigator: true).pop();

      if (mounted) {
        final profit = _totalProfit;
        final total = _total;

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
                  label: 'Total',
                  value: '${total.toStringAsFixed(0)} F',
                ),
                if (method != PaymentMethod.debt)
                  _ReceiptRow(
                    label: 'Reçu',
                    value: '${(double.tryParse(paidText) ?? total).toStringAsFixed(0)} F',
                  ),
                if (method != PaymentMethod.debt && (double.tryParse(paidText) ?? total) > total)
                  _ReceiptRow(
                    label: 'Monnaie à rendre',
                    value: '${((double.tryParse(paidText) ?? total) - total).toStringAsFixed(0)} F',
                    highlight: true,
                  ),
                if (method == PaymentMethod.debt)
                  _ReceiptRow(
                    label: 'Dette créée',
                    value: '${total.toStringAsFixed(0)} F',
                    highlight: true,
                    color: AppTheme.warning,
                  ),
                const Divider(),
                _ReceiptRow(
                  label: 'Bénéfice',
                  value: '${profit.toStringAsFixed(0)} F',
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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Sélectionner un client',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1),
            if (clients.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Aucun client — ajoute-en depuis l\'onglet Clients',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: clients.length,
                  itemBuilder: (_, i) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          AppTheme.primary.withOpacity(0.1),
                      child: Text(
                        clients[i].name[0].toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    title: Text(clients[i].name),
                    subtitle: clients[i].phone != null
                        ? Text(clients[i].phone!)
                        : null,
                    trailing: clients[i].totalDebt > 0
                        ? Text(
                            'Dette: ${clients[i].totalDebt.toStringAsFixed(0)} F',
                            style: const TextStyle(
                              color: AppTheme.warning,
                              fontSize: 12,
                            ),
                          )
                        : null,
                    onTap: () {
                      setState(() => _selectedClient = clients[i]);
                      Navigator.of(ctx).pop();
                    },
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
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