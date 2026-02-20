import 'package:flutter/material.dart';
import '../../../shared/widgets/admin_sidebar.dart';

class BillingScreen extends StatelessWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const AdminSidebar(),
          Expanded(
            child: Column(
              children: [
                AppBar(
                  automaticallyImplyLeading: false,
                  title: const Text('Billing'),
                ),
                const Expanded(
                  child: Center(child: Text('Billing — coming soon')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
