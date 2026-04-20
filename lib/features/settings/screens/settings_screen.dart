import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/models/settings.dart';
import '../../../core/models/work_session.dart';
import '../../../core/models/sale.dart';
import '../../../core/theme/app_theme.dart';

const _settingsUuid = Uuid();

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppSettings _settings = AppSettings();
  WorkSession? _currentSession;
  List<WorkSession> _sessionHistory = [];
  bool _isLoading = true;
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final settings = await DatabaseHelper.getSettings();
    final session = await DatabaseHelper.getCurrentSession();
    final history = await DatabaseHelper.getAllSessions();
    if (mounted) {
      setState(() {
        _settings = settings;
        _currentSession = session;
        _sessionHistory = history.where((s) => !s.isOpen).toList();
        _isLoading = false;
      });
    }
  }

  void _showOpenSessionDialog() {
    final cashCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ouvrir la session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Entrez le montant en caisse au démarrage',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: cashCtrl,
              decoration: const InputDecoration(
                labelText: 'Fond de caisse',
                suffixText: 'F',
                prefixIcon: Icon(Icons.money),
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
              final session = WorkSession(
                id: _settingsUuid.v4(),
                openingCash: double.tryParse(cashCtrl.text) ?? 0,
                openedAt: DateTime.now(),
              );
              await DatabaseHelper.openSession(session);
              if (mounted) {
                Navigator.of(context, rootNavigator: true).pop();
                _load();
              }
            },
            child: const Text('Ouvrir la session'),
          ),
        ],
      ),
    );
  }

  void _showCloseSessionDialog() async {
    if (_currentSession == null) return;

    final sales = await DatabaseHelper.getSalesBySession(_currentSession!);
    final revenue = sales.fold(0.0, (sum, s) => sum + s.totalAmount);
    final collected = sales.fold(0.0, (sum, s) => sum + s.paidAmount);
    final profit = sales.fold(0.0, (sum, s) => sum + s.totalProfit);
    final cashCtrl = TextEditingController(
        text: (_currentSession!.openingCash + collected).toStringAsFixed(0));

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clôturer la session'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    _SummaryRow(
                        label: 'Durée',
                        value: _currentSession!.durationLabel),
                    _SummaryRow(
                        label: 'Nb ventes', value: '${sales.length}'),
                    _SummaryRow(
                        label: 'CA total',
                        value: '${revenue.toStringAsFixed(0)} F'),
                    _SummaryRow(
                        label: 'Encaissé',
                        value: '${collected.toStringAsFixed(0)} F',
                        color: AppTheme.secondary),
                    _SummaryRow(
                        label: 'Bénéfice',
                        value: '${profit.toStringAsFixed(0)} F',
                        color: AppTheme.secondary),
                    _SummaryRow(
                        label: 'Fond de caisse',
                        value:
                            '${_currentSession!.openingCash.toStringAsFixed(0)} F'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: cashCtrl,
                decoration: const InputDecoration(
                  labelText: 'Montant en caisse à la clôture',
                  suffixText: 'F',
                  prefixIcon: Icon(Icons.money),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () async {
              final closed = _currentSession!.copyWith(
                closingCash: double.tryParse(cashCtrl.text) ?? 0,
                closedAt: DateTime.now(),
                isOpen: false,
              );
              await DatabaseHelper.closeSession(closed);
              if (mounted) {
                Navigator.of(context, rootNavigator: true).pop();
                _load();
              }
            },
            child: const Text('Clôturer'),
          ),
        ],
      ),
    );
  }

  void _showSessionDetail(WorkSession session) async {
    final sales = await DatabaseHelper.getSalesBySession(session);
    final revenue = sales.fold(0.0, (sum, s) => sum + s.totalAmount);
    final collected = sales.fold(0.0, (sum, s) => sum + s.paidAmount);
    final profit = sales.fold(0.0, (sum, s) => sum + s.totalProfit);
    final debt = revenue - collected;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
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
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(session.openedAt),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _sessionDateRange(session),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(16),
                children: [
                  // Stats session
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      children: [
                        _SummaryRow(
                          label: 'Fond de caisse ouverture',
                          value:
                              '${session.openingCash.toStringAsFixed(0)} F',
                        ),
                        if (session.closingCash != null)
                          _SummaryRow(
                            label: 'Caisse à la clôture',
                            value:
                                '${session.closingCash!.toStringAsFixed(0)} F',
                          ),
                        const Divider(height: 16),
                        _SummaryRow(
                          label: 'Nombre de ventes',
                          value: '${sales.length}',
                        ),
                        _SummaryRow(
                          label: 'Chiffre d\'affaires',
                          value: '${revenue.toStringAsFixed(0)} F',
                        ),
                        _SummaryRow(
                          label: 'Encaissé',
                          value: '${collected.toStringAsFixed(0)} F',
                          color: AppTheme.secondary,
                        ),
                        _SummaryRow(
                          label: 'Bénéfice net',
                          value: '${profit.toStringAsFixed(0)} F',
                          color: AppTheme.secondary,
                        ),
                        if (debt > 0)
                          _SummaryRow(
                            label: 'Non encaissé (dettes)',
                            value: '${debt.toStringAsFixed(0)} F',
                            color: AppTheme.warning,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Répartition paiements
                  if (sales.isNotEmpty) ...[
                    const Text(
                      'Répartition des paiements',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        children: [
                          _paymentRow(
                              sales, PaymentMethod.cash, 'Espèces',
                              AppTheme.secondary),
                          _paymentRow(
                              sales,
                              PaymentMethod.mobileMoney,
                              'Mobile money',
                              AppTheme.primary),
                          _paymentRow(sales, PaymentMethod.card,
                              'Carte', AppTheme.primary),
                          _paymentRow(sales, PaymentMethod.debt,
                              'À crédit', AppTheme.warning),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Top produits
                    const Text(
                      'Produits vendus',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._topProducts(sales).map(
                      (entry) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.key,
                                style: const TextStyle(fontSize: 13)),
                            Text(
                              'x${entry.value}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentRow(List<Sale> sales, PaymentMethod method,
      String label, Color color) {
    final amount = sales
        .where((s) => s.paymentMethod == method)
        .fold(0.0, (sum, s) => sum + s.paidAmount);
    if (amount == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary)),
          Text(
            '${amount.toStringAsFixed(0)} F',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color),
          ),
        ],
      ),
    );
  }

  List<MapEntry<String, int>> _topProducts(List<Sale> sales) {
    final Map<String, int> counts = {};
    for (final sale in sales) {
      for (final item in sale.items) {
        counts[item.productName] =
            (counts[item.productName] ?? 0) + item.quantity;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).toList();
  }

  Future<void> _saveSettings() async {
    await DatabaseHelper.saveSettings(_settings);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Réglages enregistrés'),
          backgroundColor: AppTheme.secondary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Session de travail
                const _SectionTitle(title: 'Session de travail'),
                const SizedBox(height: 12),

                if (_currentSession == null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.lock_outline,
                            size: 40, color: AppTheme.textSecondary),
                        const SizedBox(height: 8),
                        const Text(
                          'Aucune session ouverte',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _showOpenSessionDialog,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Ouvrir la session'),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.secondary.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: AppTheme.secondary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Session en cours',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.secondary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _currentSession!.durationLabel,
                              style: const TextStyle(
                                color: AppTheme.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _SummaryRow(
                          label: 'Ouverture',
                          value: _formatTime(_currentSession!.openedAt),
                        ),
                        _SummaryRow(
                          label: 'Fond de caisse',
                          value:
                              '${_currentSession!.openingCash.toStringAsFixed(0)} F',
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _showCloseSessionDialog,
                            icon: const Icon(Icons.stop,
                                color: AppTheme.danger),
                            label: const Text('Clôturer la session',
                                style:
                                    TextStyle(color: AppTheme.danger)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: AppTheme.danger),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // Historique des sessions
                if (_sessionHistory.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () =>
                        setState(() => _showHistory = !_showHistory),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.history,
                              color: AppTheme.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Historique des sessions (${_sessionHistory.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            _showHistory
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: AppTheme.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showHistory) ...[
                    const SizedBox(height: 8),
                    ..._sessionHistory.map((session) => GestureDetector(
                          onTap: () => _showSessionDetail(session),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: AppTheme.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary
                                        .withOpacity(0.08),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.receipt_long_outlined,
                                    size: 20,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _formatDate(session.openedAt),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      
                                      Text(
                                        _sessionDateRange(session),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                  color: AppTheme.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        )),
                  ],
                  const SizedBox(height: 20),
                ],

                // Règles de réduction
                const _SectionTitle(title: 'Règles de réduction'),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bloquer sous le prix d\'achat',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Empêche de vendre à perte',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _settings.enforceMinPrice,
                            activeColor: AppTheme.primary,
                            onChanged: (v) {
                              setState(() {
                                _settings = _settings.copyWith(
                                    enforceMinPrice: v);
                              });
                            },
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Réduction maximum autorisée',
                            style:
                                TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${_settings.maxDiscountPercent.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Slider(
                        value: _settings.maxDiscountPercent,
                        min: 0,
                        max: 50,
                        divisions: 50,
                        activeColor: AppTheme.primary,
                        label:
                            '${_settings.maxDiscountPercent.toStringAsFixed(0)}%',
                        onChanged: (v) {
                          setState(() {
                            _settings = _settings.copyWith(
                                maxDiscountPercent: v);
                          });
                        },
                      ),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('0%',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary)),
                          const Text('50%',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                ElevatedButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Enregistrer les réglages'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
  String _sessionDateRange(WorkSession session) {
    final openDate = _formatDate(session.openedAt);
    final closeDate = session.closedAt != null
        ? _formatDate(session.closedAt!)
        : null;
    final openTime = _formatTime(session.openedAt);
    final closeTime = session.closedAt != null
        ? _formatTime(session.closedAt!)
        : '?';

    if (closeDate == null || closeDate == openDate) {
      return '$openDate · $openTime → $closeTime · ${session.durationLabel}';
    } else {
      return '$openDate $openTime → $closeDate $closeTime · ${session.durationLabel}';
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimary,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}