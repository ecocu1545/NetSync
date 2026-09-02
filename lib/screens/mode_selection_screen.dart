import 'package:flutter/material.dart';
import 'child/child_setup_screen.dart';
import 'parent/parent_dashboard.dart';

class ModeSelectionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NetSync - Kurulum')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChildSetupScreen()));
              },
              child: const Text('Çocuk Cihazı Olarak Ayarla'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ParentDashboard()));
              },
              child: const Text('Ebeveyn Cihazı Olarak Ayarla'),
            ),
          ],
        ),
      ),
    );
  }
}
