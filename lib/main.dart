import 'package:flutter/material.dart';

void main() {
  runApp(const InduljApp());
}

class InduljApp extends StatelessWidget {
  const InduljApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Indulj',
      home: Scaffold(body: Center(child: Text('Indulj'))),
    );
  }
}
