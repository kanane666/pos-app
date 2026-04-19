import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/models/settings.dart';
import '../../../core/models/work_session.dart';
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final settings = await DatabaseHelper.getSettings();
    final session = await DatabaseHelper.getCurrentSession();
    if (mounted) {
      setState(() {
        _settings = settings;
        _currentSession = session;
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

    final sales =
        await DatabaseHelper.getSalesBySession(_currentSession!);
    final revenue =
        sales.fold(0.0, (sum, s) => sum + s.totalAmount);
    final collected =
        sales.fold(0.0, (sum, s) => sum + s.paidAmount);
    final profit = sales.fold(0.0, (sum, s) => sum + s.totalProfit);
    final cashCtrl = TextEditingController(
        text: (_currentSession!.openingCash + collected)
            .toStringAsFixed(0));

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
              // Résumé session
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
                      value: _currentSession!.durationLabel,
                    ),
                    _SummaryRow(
                      label: 'Nb ventes',
                      value: '${sales.length}',
                    ),
                    _SummaryRow(
                      label: 'CA total',
                      value: '${revenue.toStringAsFixed(0)} F',
                    ),
                    _SummaryRow(
                      label: 'Encaissé',
                      value: '${collected.toStringAsFixed(0)} F',
                      color: AppTheme.secondary,
                    ),
                    _SummaryRow(
                      label: 'Bénéfice',
                      value: '${profit.toStringAsFixed(0)} F',
                      color: AppTheme.secondary,
                    ),
                    _SummaryRow(
                      label: 'Fond de caisse',
                      value:
                          '${_currentSession!.openingCash.toStringAsFixed(0)} F',
                    ),
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
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly
                ],
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
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger),
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
                  // Session fermée
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
                  // Session ouverte
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
                          value: _formatTime(
                              _currentSession!.openedAt),
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

                const SizedBox(height: 28),

                // Réglages réduction
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
                      // Toggle prix achat
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

                      // % max réduction
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
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
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