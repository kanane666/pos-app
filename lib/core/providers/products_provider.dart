import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/product.dart';

const _uuid = Uuid();

class ProductsNotifier extends AsyncNotifier<List<Product>> {
  @override
  Future<List<Product>> build() async {
    return await DatabaseHelper.getProducts();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => DatabaseHelper.getProducts());
  }

  Future<void> addProduct({
    required String name,
    String? description,
    required double purchasePrice,
    required double sellingPrice,
    required int stock,
    int alertStock = 5,
    String? imageUrl,
    String? barcode,
    String category = 'Général',
  }) async {
    final product = Product(
      id: _uuid.v4(),
      name: name,
      description: description,
      purchasePrice: purchasePrice,
      sellingPrice: sellingPrice,
      stock: stock,
      alertStock: alertStock,
      imageUrl: imageUrl,
      barcode: barcode,
      category: category,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await DatabaseHelper.insertProduct(product);
    await reload();
  }

  Future<void> editProduct(Product product) async {
    final updated = product.copyWith(updatedAt: DateTime.now());
    await DatabaseHelper.updateProduct(updated);
    await reload();
  }

  Future<void> removeProduct(String id) async {
    await DatabaseHelper.deleteProduct(id);
    await reload();
  }

  Future<void> adjustStock(String id, int newStock) async {
    await DatabaseHelper.updateProductStock(id, newStock);
    await reload();
  }
}

final productsProvider =
    AsyncNotifierProvider<ProductsNotifier, List<Product>>(
  ProductsNotifier.new,
);