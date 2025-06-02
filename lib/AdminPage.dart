import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminPage extends StatefulWidget{
  const AdminPage({super.key});

  @override
  State<AdminPage>createState()=> _AdminPageState();
}

class _AdminPageState extends State<AdminPage>{

  /*
  Future<void> _checkManager() async {
    final prefs = await SharedPreferences.getInstance();
    final userID = prefs.getInt('UserID');

    if(userID != null){
      final isManager = prefs.getInt('isManager') ?? 0;
      if (isManager==0) return;
    
      WidgetsBinding.instance.addPostFrameCallback((_) {
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminPage()),
        );
        
      });
    }
  }
  */

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: Text('管理員介面'),
      ),
    );
  }
}

