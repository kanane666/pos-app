import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/models/client.dart';
import '../../../core/models/debt.dart';
import '../../../core/theme/app_theme.dart';

const _clientUuid = Uuid();

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  List<Client> _clients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() => _isLoading = true);
    final clients = await DatabaseHelper.getClients();
    if (mounted) setState(() {
      _clients = clients;
      _isLoading = false;
    });
  }

  void _showAddClientDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nouveau client'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom complet *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Nom obligatoire' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Téléphone (optionnel)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
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
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final client = Client(
                id: _clientUuid.v4(),
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim().isEmpty
                    ? null
                    : phoneCtrl.text.trim(),
                createdAt: DateTime.now(),
              );
              await DatabaseHelper.insertClient(client);
              if (mounted) Navigator.of(context, rootNavigator: true).pop();
              _loadClients();
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _showClientDetail(Client client) async {
    final debts = await DatabaseHelper.getDebtsByClient(client.id);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ClientDetailSheet(
        client: client,
        debts: debts,
        onDebtPaid: () {
          Navigator.pop(context);
          _loadClients();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalDebt = _clients.fold(0.0, (sum, c) => sum + c.totalDebt);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: _showAddClientDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Résumé dettes
                if (totalDebt > 0)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.warning.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_outlined,
                            color: AppTheme.warning),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total dettes en cours',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.warning,
                              ),
                            ),
                            Text(
                              '${totalDebt.toStringAsFixed(0)} F',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.warning,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Liste clients
                Expanded(
                  child: _clients.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline,
                                  size: 64,
                                  color: AppTheme.textSecondary),
                              const SizedBox(height: 16),
                              const Text(
                                'Aucun client',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _showAddClientDialog,
                                icon: const Icon(Icons.person_add),
                                label: const Text('Ajouter un client'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadClients,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _clients.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final client = _clients[i];
                              return Card(
                                child: ListTile(
                                  onTap: () =>
                                      _showClientDetail(client),
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        AppTheme.primary.withOpacity(0.1),
                                    child: Text(
                                      client.name[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    client.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: client.phone != null
                                      ? Text(client.phone!)
                                      : null,
                                  trailing: client.hasDebt
                                      ? Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.warning
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: AppTheme.warning
                                                  .withOpacity(0.3),
                                            ),
                                          ),
                                          child: Text(
                                            '${client.totalDebt.toStringAsFixed(0)} F',
                                            style: const TextStyle(
                                              color: AppTheme.warning,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.check_circle_outline,
                                          color: AppTheme.secondary,
                                        ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddClientDialog,
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }
}

class _ClientDetailSheet extends StatefulWidget {
  final Client client;
  final List<Debt> debts;
  final VoidCallback onDebtPaid;

  const _ClientDetailSheet({
    required this.client,
    required this.debts,
    required this.onDebtPaid,
  });

  @override
  State<_ClientDetailSheet> createState() => _ClientDetailSheetState();
}

class _ClientDetailSheetState extends State<_ClientDetailSheet> {
  void _showPayDebtDialog(Debt debt) {
    final amountCtrl = TextEditingController(
        text: debt.remainingAmount.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enregistrer un paiement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Reste à payer'),
                  Text(
                    '${debt.remainingAmount.toStringAsFixed(0)} F',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.warning,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Montant payé',
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
            onPressed: () async {
              final amount =
                  double.tryParse(amountCtrl.text) ?? 0;
              if (amount <= 0) return;

              final payment = DebtPayment(
                id: _clientUuid.v4(),
                amount: amount,
                paidAt: DateTime.now(),
              );

              final newRemaining =
                  (debt.remainingAmount - amount).clamp(0, double.infinity);

              final updatedDebt = Debt(
                id: debt.id,
                clientId: debt.clientId,
                clientName: debt.clientName,
                saleId: debt.saleId,
                originalAmount: debt.originalAmount,
                remainingAmount: newRemaining.toDouble(),
                payments: [...debt.payments, payment],
                createdAt: debt.createdAt,
              );

              await DatabaseHelper.updateDebt(updatedDebt);

              final newClientDebt =
                  (widget.client.totalDebt - amount)
                      .clamp(0, double.infinity);
              await DatabaseHelper.updateClientDebt(
                  widget.client.id, newClientDebt.toDouble());

              if (mounted) Navigator.pop(context);
              widget.onDebtPaid();
            },
            child: const Text('Valider le paiement'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // En-tête client
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primary.withOpacity(0.1),
                  child: Text(
                    widget.client.name[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.client.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (widget.client.phone != null)
                        Text(widget.client.phone!,
                            style: const TextStyle(
                                color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                if (widget.client.hasDebt)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Dette totale',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary)),
                      Text(
                        '${widget.client.totalDebt.toStringAsFixed(0)} F',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.warning,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const Divider(height: 24),

          // Liste des dettes
          Expanded(
            child: widget.debts.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 48, color: AppTheme.secondary),
                        SizedBox(height: 8),
                        Text('Aucune dette en cours',
                            style:
                                TextStyle(color: AppTheme.secondary)),
                      ],
                    ),
                  )
                : ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: widget.debts.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final debt = widget.debts[i];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Vente du ${_formatDate(debt.createdAt)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        'Original : ${debt.originalAmount.toStringAsFixed(0)} F',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${debt.remainingAmount.toStringAsFixed(0)} F',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.warning,
                                        ),
                                      ),
                                      const Text('restant',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color:
                                                  AppTheme.textSecondary)),
                                    ],
                                  ),
                                ],
                              ),
                              if (debt.payments.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                const Text('Paiements reçus :',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary)),
                                ...debt.payments.map((p) => Padding(
                                      padding: const EdgeInsets.only(
                                          top: 2),
                                      child: Text(
                                        '+ ${p.amount.toStringAsFixed(0)} F le ${_formatDate(p.paidAt)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.secondary,
                                        ),
                                      ),
                                    )),
                              ],
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _showPayDebtDialog(debt),
                                  icon: const Icon(Icons.payment,
                                      size: 16),
                                  label: const Text('Enregistrer paiement'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}