import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManageCityTownPage extends StatefulWidget {
  const ManageCityTownPage({super.key});

  @override
  State<ManageCityTownPage> createState() => _ManagerCityTownState();
}

class _ManagerCityTownState extends State<ManageCityTownPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理 City/Town'),
      ),
    );
  }
}