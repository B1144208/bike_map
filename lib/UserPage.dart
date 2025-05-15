import 'package:flutter/material.dart';

// 連接頁面
import 'LoginPage.dart';

class UserPage extends StatelessWidget{
  const UserPage({super.key});

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: const Text('使用者帳號'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            // 跳轉我的收藏
            FilledButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()), //****************************************************************************
                );
              },
              child: const Text('我的收藏'),
            ),

            const SizedBox(height: 30),

            // 刪除帳號按鈕
            ElevatedButton(
              onPressed: () {
                // 刪除帳號
              },
              child: const Text('刪除帳號'),
            ),

            const SizedBox(height: 30),

            MouseRegion(
              cursor: SystemMouseCursors.click, // 滑鼠變成手指
              child: GestureDetector(
                onTap: () {
                  print("你點到我了！");

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
          ]
        )
        
      )
    );
  }
  
}