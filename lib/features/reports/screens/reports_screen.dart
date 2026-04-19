import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/models/sale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/debt.dart';
import '../../../core/models/client.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Sale> _sales = [];
  bool _isLoading = true;
  Map<String, double> _todayStats = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final sales = await DatabaseHelper.getSalesByDate(_selectedDate);
    final stats = await DatabaseHelper.getTodayStats();
    if (mounted) {
      setState(() {
        _sales = sales;
        _todayStats = stats;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  double get _revenue =>
      _sales.where((s) => s.status != SaleStatus.cancelled).fold(
          0.0, (sum, s) => sum + s.totalAmount);

  double get _collected =>
      _sales.where((s) => s.status != SaleStatus.cancelled).fold(
          0.0, (sum, s) => sum + s.paidAmount);

  double get _profit =>
      _sales.where((s) => s.status != SaleStatus.cancelled).fold(
          0.0, (sum, s) => sum + s.totalProfit);

  double get _totalDebt => _revenue - _collected;

  int get _salesCount =>
      _sales.where((s) => s.status != SaleStatus.cancelled).length;

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapports'),
        actions: [
          TextButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today,
                size: 16, color: AppTheme.primary),
            label: Text(
              _isToday
                  ? "Aujourd'hui"
                  : '${_selectedDate.day.toString().padLeft(2, '0')}/'
                      '${_selectedDate.month.toString().padLeft(2, '0')}/'
                      '${_selectedDate.year}',
              style: const TextStyle(color: AppTheme.primary),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Cartes stats principales
                  Row(
                    children: [
                      _StatCard(
                        label: 'Chiffre d\'affaires',
                        value: '${_revenue.toStringAsFixed(0)} F',
                        icon: Icons.trending_up,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        label: 'Encaissé',
                        value: '${_collected.toStringAsFixed(0)} F',
                        icon: Icons.payments_outlined,
                        color: AppTheme.secondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _StatCard(
                        label: 'Bénéfice net',
                        value: '${_profit.toStringAsFixed(0)} F',
                        icon: Icons.account_balance_wallet_outlined,
                        color: AppTheme.secondary,
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        label: 'Dettes du jour',
                        value: '${_totalDebt.toStringAsFixed(0)} F',
                        icon: Icons.warning_amber_outlined,
                        color: _totalDebt > 0
                            ? AppTheme.warning
                            : AppTheme.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _StatCard(
                        label: 'Ventes',
                        value: '$_salesCount',
                        icon: Icons.receipt_outlined,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        label: 'Panier moyen',
                        value: _salesCount > 0
                            ? '${(_revenue / _salesCount).toStringAsFixed(0)} F'
                            : '0 F',
                        icon: Icons.shopping_basket_outlined,
                        color: AppTheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Bouton dettes
                  _DebtsSummaryButton(totalDebt: _totalDebt),

                  const SizedBox(height: 24),

                  // Répartition paiements
                  if (_sales.isNotEmpty) ...[
                    const Text(
                      'Répartition des paiements',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PaymentBreakdown(sales: _sales),
                    const SizedBox(height: 24),
                  ],

                  // Liste des ventes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Détail des ventes',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '$_salesCount vente${_salesCount > 1 ? 's' : ''}',
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_sales.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 48,
                              color: AppTheme.textSecondary),
                          SizedBox(height: 8),
                          Text(
                            'Aucune vente ce jour',
                            style: TextStyle(
                                color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    )
                  else
                    ...(_sales.map((sale) => _SaleCard(sale: sale))),
                ],
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
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
    );
  }
}

class _PaymentBreakdown extends StatelessWidget {
  final List<Sale> sales;

  const _PaymentBreakdown({required this.sales});

  @override
  Widget build(BuildContext context) {
    final completed =
        sales.where((s) => s.status != SaleStatus.cancelled).toList();
    final cash = completed
        .where((s) => s.paymentMethod == PaymentMethod.cash)
        .fold(0.0, (sum, s) => sum + s.paidAmount);
    final mobile = completed
        .where((s) => s.paymentMethod == PaymentMethod.mobileMoney)
        .fold(0.0, (sum, s) => sum + s.paidAmount);
    final card = completed
        .where((s) => s.paymentMethod == PaymentMethod.card)
        .fold(0.0, (sum, s) => sum + s.paidAmount);
    final debt = completed
        .where((s) => s.paymentMethod == PaymentMethod.debt)
        .fold(0.0, (sum, s) => sum + s.totalAmount);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          if (cash > 0)
            _PaymentRow(
                label: 'Espèces',
                amount: cash,
                icon: Icons.money,
                color: AppTheme.secondary),
          if (mobile > 0)
            _PaymentRow(
                label: 'Mobile money',
                amount: mobile,
                icon: Icons.phone_android,
                color: AppTheme.primary),
          if (card > 0)
            _PaymentRow(
                label: 'Carte',
                amount: card,
                icon: Icons.credit_card,
                color: AppTheme.primary),
          if (debt > 0)
            _PaymentRow(
                label: 'À crédit',
                amount: debt,
                icon: Icons.person_outline,
                color: AppTheme.warning),
          if (cash == 0 && mobile == 0 && card == 0 && debt == 0)
            const Text('Aucune donnée',
                style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;

  const _PaymentRow({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const Spacer(),
          Text(
            '${amount.toStringAsFixed(0)} F',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  final Sale sale;

  const _SaleCard({required this.sale});

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _methodLabel(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.cash:
        return 'Espèces';
      case PaymentMethod.mobileMoney:
        return 'Mobile money';
      case PaymentMethod.card:
        return 'Carte';
      case PaymentMethod.debt:
        return 'À crédit';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: sale.status == SaleStatus.cancelled
              ? AppTheme.danger.withOpacity(0.3)
              : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    _formatTime(sale.createdAt),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: sale.paymentMethod == PaymentMethod.debt
                          ? AppTheme.warning.withOpacity(0.1)
                          : AppTheme.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _methodLabel(sale.paymentMethod),
                      style: TextStyle(
                        fontSize: 11,
                        color: sale.paymentMethod == PaymentMethod.debt
                            ? AppTheme.warning
                            : AppTheme.secondary,
                      ),
                    ),
                  ),
                  if (sale.clientName != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      sale.clientName!,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary),
                    ),
                  ],
                ],
              ),
              Text(
                '${sale.totalAmount.toStringAsFixed(0)} F',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...sale.items.map((item) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    const Icon(Icons.circle,
                        size: 6, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${item.productName} x${item.quantity}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary),
                      ),
                    ),
                    Text(
                      '${item.total.toStringAsFixed(0)} F',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              )),
          if (sale.hasDebt) ...[
            const SizedBox(height: 6),
            Text(
              'Reste à payer : ${sale.remainingAmount.toStringAsFixed(0)} F',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
class _DebtsSummaryButton extends StatelessWidget {
  final double totalDebt;
  const _DebtsSummaryButton({required this.totalDebt});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAllDebts(context),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: totalDebt > 0
              ? AppTheme.warning.withOpacity(0.08)
              : AppTheme.secondary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: totalDebt > 0
                ? AppTheme.warning.withOpacity(0.4)
                : AppTheme.secondary.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              totalDebt > 0
                  ? Icons.warning_amber_outlined
                  : Icons.check_circle_outline,
              color:
                  totalDebt > 0 ? AppTheme.warning : AppTheme.secondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gestion des dettes',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    totalDebt > 0
                        ? '${totalDebt.toStringAsFixed(0)} F non encaissé aujourd\'hui'
                        : 'Tout est encaissé',
                    style: TextStyle(
                      fontSize: 12,
                      color: totalDebt > 0
                          ? AppTheme.warning
                          : AppTheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: totalDebt > 0
                  ? AppTheme.warning
                  : AppTheme.secondary,
            ),
          ],
        ),
      ),
    );
  }

  void _showAllDebts(BuildContext context) async {
    final debts = await DatabaseHelper.getDebts();
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, controller) => Column(
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Toutes les dettes',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${debts.fold(0.0, (s, d) => s + d.remainingAmount).toStringAsFixed(0)} F',
                      style: const TextStyle(
                        color: AppTheme.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: debts.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 48, color: AppTheme.secondary),
                          SizedBox(height: 8),
                          Text('Aucune dette en cours',
                              style: TextStyle(
                                  color: AppTheme.secondary)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.all(16),
                      itemCount: debts.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final debt = debts[i];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                    AppTheme.warning.withOpacity(0.1),
                                child: Text(
                                  debt.clientName[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: AppTheme.warning,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      debt.clientName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      'Depuis le ${debt.createdAt.day.toString().padLeft(2, '0')}/${debt.createdAt.month.toString().padLeft(2, '0')}/${debt.createdAt.year}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary),
                                    ),
                                    if (debt.payments.isNotEmpty)
                                      Text(
                                        '${debt.payments.length} paiement(s) reçu(s)',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.secondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${debt.remainingAmount.toStringAsFixed(0)} F',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: AppTheme.warning,
                                    ),
                                  ),
                                  Text(
                                    'sur ${debt.originalAmount.toStringAsFixed(0)} F',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}