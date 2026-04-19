import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/pos/screens/pos_screen.dart';
import '../../features/products/screens/products_screen.dart';
import '../../features/products/screens/product_form_screen.dart';
import '../../features/clients/screens/clients_screen.dart';
import '../../features/stock/screens/stock_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../models/product.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/pos',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return MainShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/pos',
          builder: (context, state) => const PosScreen(),
        ),
        GoRoute(
          path: '/products',
          builder: (context, state) => const ProductsScreen(),
        ),
        GoRoute(
          path: '/products/new',
          builder: (context, state) => const ProductFormScreen(),
        ),
        GoRoute(
          path: '/products/edit',
          builder: (context, state) {
            final product = state.extra as Product;
            return ProductFormScreen(product: product);
          },
        ),
        GoRoute(
          path: '/clients',
          builder: (context, state) => const ClientsScreen(),
        ),
        GoRoute(
          path: '/stock',
          builder: (context, state) => const StockScreen(),
        ),
        GoRoute(
          path: '/reports',
          builder: (context, state) => const ReportsScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/pos')) return 0;
    if (location.startsWith('/products')) return 1;
    if (location.startsWith('/clients')) return 2;
    if (location.startsWith('/stock')) return 3;
    if (location.startsWith('/reports')) return 4;
    if (location.startsWith('/settings')) return 5;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex(context),
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/pos');
              break;
            case 1:
              context.go('/products');
              break;
            case 2:
              context.go('/clients');
              break;
            case 3:
              context.go('/stock');
              break;
            case 4:
              context.go('/reports');
              break;
            case 5:
              context.go('/settings');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale),
            label: 'Caisse',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: 'Produits',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Clients',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.warehouse),
            label: 'Stock',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Rapports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Réglages',
          ),
        ],
      ),
    );
  }
}