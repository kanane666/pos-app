import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/client.dart';
import '../models/sale.dart';
import '../models/debt.dart';

class DatabaseHelper {
  static const _productsKey = 'products';
  static const _clientsKey = 'clients';
  static const _salesKey = 'sales';
  static const _debtsKey = 'debts';

  static Future<SharedPreferences> get _prefs async {
    return await SharedPreferences.getInstance();
  }

  // ─── PRODUCTS ───────────────────────────────────────────

  static Future<List<Product>> getProducts() async {
    final prefs = await _prefs;
    final data = prefs.getString(_productsKey);
    if (data == null) return [];
    final List decoded = jsonDecode(data);
    return decoded
        .map((e) => Product.fromMap(e as Map<String, dynamic>))
        .where((p) => p.isActive)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  static Future<void> insertProduct(Product product) async {
    final prefs = await _prefs;
    final all = await _getAllProducts();
    all.add(product);
    await prefs.setString(_productsKey, jsonEncode(all.map((e) => e.toMap()).toList()));
  }

  static Future<List<Product>> _getAllProducts() async {
    final prefs = await _prefs;
    final data = prefs.getString(_productsKey);
    if (data == null) return [];
    final List decoded = jsonDecode(data);
    return decoded.map((e) => Product.fromMap(e as Map<String, dynamic>)).toList();
  }

  static Future<void> updateProduct(Product product) async {
    final prefs = await _prefs;
    final all = await _getAllProducts();
    final index = all.indexWhere((p) => p.id == product.id);
    if (index != -1) all[index] = product;
    await prefs.setString(_productsKey, jsonEncode(all.map((e) => e.toMap()).toList()));
  }

  static Future<void> deleteProduct(String id) async {
    final prefs = await _prefs;
    final all = await _getAllProducts();
    final index = all.indexWhere((p) => p.id == id);
    if (index != -1) {
      all[index] = all[index].copyWith(isActive: false);
    }
    await prefs.setString(_productsKey, jsonEncode(all.map((e) => e.toMap()).toList()));
  }

  static Future<void> updateProductStock(String id, int newStock) async {
    final prefs = await _prefs;
    final all = await _getAllProducts();
    final index = all.indexWhere((p) => p.id == id);
    if (index != -1) {
      all[index] = all[index].copyWith(
        stock: newStock,
        updatedAt: DateTime.now(),
      );
    }
    await prefs.setString(_productsKey, jsonEncode(all.map((e) => e.toMap()).toList()));
  }

  // ─── CLIENTS ────────────────────────────────────────────

  static Future<List<Client>> getClients() async {
    final prefs = await _prefs;
    final data = prefs.getString(_clientsKey);
    if (data == null) return [];
    final List decoded = jsonDecode(data);
    return decoded
        .map((e) => Client.fromMap(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  static Future<void> insertClient(Client client) async {
    final prefs = await _prefs;
    final all = await getClients();
    all.add(client);
    await prefs.setString(_clientsKey, jsonEncode(all.map((e) => e.toMap()).toList()));
  }

  static Future<void> updateClient(Client client) async {
    final prefs = await _prefs;
    final all = await getClients();
    final index = all.indexWhere((c) => c.id == client.id);
    if (index != -1) all[index] = client;
    await prefs.setString(_clientsKey, jsonEncode(all.map((e) => e.toMap()).toList()));
  }

  static Future<void> updateClientDebt(String clientId, double totalDebt) async {
    final prefs = await _prefs;
    final all = await getClients();
    final index = all.indexWhere((c) => c.id == clientId);
    if (index != -1) {
      all[index] = all[index].copyWith(totalDebt: totalDebt);
    }
    await prefs.setString(_clientsKey, jsonEncode(all.map((e) => e.toMap()).toList()));
  }

  // ─── SALES ──────────────────────────────────────────────

  static Future<List<Sale>> getSales({int limit = 50}) async {
    final prefs = await _prefs;
    final data = prefs.getString(_salesKey);
    if (data == null) return [];
    final List decoded = jsonDecode(data);
    final sales = decoded
        .map((e) => Sale.fromMap(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sales.take(limit).toList();
  }

  static Future<List<Sale>> getSalesByDate(DateTime date) async {
    final all = await getSales(limit: 10000);
    return all.where((s) {
      return s.createdAt.year == date.year &&
          s.createdAt.month == date.month &&
          s.createdAt.day == date.day;
    }).toList();
  }

  static Future<void> insertSale(Sale sale) async {
    final prefs = await _prefs;
    final all = await getSales(limit: 10000);
    all.insert(0, sale);
    await prefs.setString(_salesKey, jsonEncode(all.map((e) => e.toMap()).toList()));
  }

  // ─── DEBTS ──────────────────────────────────────────────

  static Future<List<Debt>> getDebts() async {
    final prefs = await _prefs;
    final data = prefs.getString(_debtsKey);
    if (data == null) return [];
    final List decoded = jsonDecode(data);
    return decoded
        .map((e) => Debt.fromMap(e as Map<String, dynamic>))
        .where((d) => !d.isPaid)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Future<List<Debt>> _getAllDebts() async {
    final prefs = await _prefs;
    final data = prefs.getString(_debtsKey);
    if (data == null) return [];
    final List decoded = jsonDecode(data);
    return decoded.map((e) => Debt.fromMap(e as Map<String, dynamic>)).toList();
  }

  static Future<List<Debt>> getDebtsByClient(String clientId) async {
    final all = await _getAllDebts();
    return all.where((d) => d.clientId == clientId).toList();
  }

  static Future<void> insertDebt(Debt debt) async {
    final prefs = await _prefs;
    final all = await _getAllDebts();
    all.add(debt);
    await prefs.setString(_debtsKey, jsonEncode(all.map((e) => e.toMap()).toList()));
  }

  static Future<void> updateDebt(Debt debt) async {
    final prefs = await _prefs;
    final all = await _getAllDebts();
    final index = all.indexWhere((d) => d.id == debt.id);
    if (index != -1) all[index] = debt;
    await prefs.setString(_debtsKey, jsonEncode(all.map((e) => e.toMap()).toList()));
  }

  // ─── STATS ──────────────────────────────────────────────

  static Future<Map<String, double>> getTodayStats() async {
    final today = DateTime.now();
    final sales = await getSalesByDate(today);
    final completed = sales.where((s) => s.status != SaleStatus.cancelled);
    final revenue = completed.fold(0.0, (sum, s) => sum + s.totalAmount);
    final collected = completed.fold(0.0, (sum, s) => sum + s.paidAmount);
    return {
      'revenue': revenue,
      'collected': collected,
      'count': completed.length.toDouble(),
    };
  }
}