import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManageCyclingroutePage extends StatefulWidget {
  const ManageCyclingroutePage({super.key});

  @override
  State<ManageCyclingroutePage> createState() => _ManagerCyclingrouteState();
}

class _ManagerCyclingrouteState extends State<ManageCyclingroutePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理 CyclingRoute'),
      ),
    );
  }
}