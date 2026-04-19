import 'package:flutter/material.dart';
import '../../../core/models/product.dart';

class ProductFormScreen extends StatelessWidget {
  final Product? product;
  const ProductFormScreen({super.key, this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(product == null ? 'Nouveau produit' : 'Modifier produit'),
      ),
      body: const Center(child: Text('Formulaire — bientôt')),
    );
  }
}