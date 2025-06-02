import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 連接頁面
import 'ManageUserPage.dart';
import 'ManageCityTownPage.dart';
import 'ManageYoubikePage.dart';
import 'ManageCyclingroutePage.dart';
import 'HomePage.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {

  Future<void> SignOut() async{
    final prefs = await SharedPreferences.getInstance();
    prefs.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理員介面'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ManageUserPage()),
                );
              },
              child: const Text('管理 User 資料'),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ManageCityTownPage()),
                );
              },
              child: const Text('管理 City / Town 資料'),
            ),

            const SizedBox(height: 30),

            FilledButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ManageYoubikePage()),
                );
              },
              child: const Text('管理 YouBike 資料'),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ManageCyclingroutePage()),
                );
              },
              child: const Text('管理 CyclingRoute 資料'),
            ),
            
            const SizedBox(height: 30),

            MouseRegion(
              cursor: SystemMouseCursors.click, // 滑鼠變成手指
              child: GestureDetector(
                onTap: () {
                  SignOut();

                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('通知'),
                        content: const Text('帳號已登出'),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('確定'),
                            onPressed: () {
                              Navigator.of(context).pop();
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => HomePage()),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  );

                },
                child: Text(
                  "登出",
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                    color: Colors.deepPurple,
                  ),
                  
                ),
              ),
            )
            
          ],
        ),
      ),
    );
  }
}





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