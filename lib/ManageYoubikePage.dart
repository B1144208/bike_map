import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManageYoubikePage extends StatefulWidget {
  const ManageYoubikePage({super.key});

  @override
  State<ManageYoubikePage> createState() => _ManagerYoubikeState();
}

class _ManagerYoubikeState extends State<ManageYoubikePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理 YouBike'),
      ),
    );
  }
}