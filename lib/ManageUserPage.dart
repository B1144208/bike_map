import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManageUserPage extends StatefulWidget {
  const ManageUserPage({super.key});

  @override
  State<ManageUserPage> createState() => _ManagerUserState();
}

class _ManagerUserState extends State<ManageUserPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理 User'),
      ),
    );
  }
}