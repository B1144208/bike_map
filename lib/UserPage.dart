import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// 連接頁面
import 'LoginPage.dart';
import 'HomePage.dart';

Future<void> SignOut() async{
  final prefs = await SharedPreferences.getInstance();
  prefs.clear();
}

Future<int> searchUserID() async{
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('UserID') ?? 0;
}

Future<bool> removAccount(int userID) async{
  final url = 'http://localhost:3000/user/deleteUser/$userID';
  final response = await http.delete(Uri.parse(url));

  if(response.statusCode == 200){
    print('User deleted successfully');
    final prefs = await SharedPreferences.getInstance();
    prefs.clear();
    return true;
  } else {
    print('Failed to delete user: ${response.body}');
    return false;
  }
}

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {

   String PromptMessage = "";

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
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('確認刪除'),
                      content: const Text('確定要刪除帳號嗎?'),
                      actions: <Widget>[

                        // 取消
                        TextButton(
                          child: const Text('取消'),
                          onPressed: (){
                            Navigator.of(context).pop();
                          },
                        ),

                        // 確定
                        TextButton(
                          child: const Text('確定'),
                          onPressed: (){
                            Future<int> userID = searchUserID();
                            userID.then((userId){

                              if(userId!=0){
                                Future<bool> RemoveStatus = removAccount(userId);
                                RemoveStatus.then((status){
                                  if(status){
                                    // 通知帳號已刪除
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          title: const Text('通知'),
                                          content: const Text('帳號已刪除'),
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
                                  }else{
                                    setState(() {
                                      PromptMessage = "刪除帳號失敗";
                                    });
                                  }
                                });
                              }
                            });
                            Navigator.of(context).pop();
                            
                          },
                        ),
                      ]
                    );
                  },
                );
              },
              child: const Text('刪除帳號'),
            ),

            const SizedBox(height: 10),

            if (PromptMessage.isNotEmpty) 
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  PromptMessage,
                  style: TextStyle(
                    color: PromptMessage == "" ? Colors.green : Colors.red, // 根據訊息顯示顏色
                  ),
                ),
              ),

            const SizedBox(height: 30),

            MouseRegion(
              cursor: SystemMouseCursors.click, // 滑鼠變成手指
              child: GestureDetector(
                onTap: () {
                  SignOut();
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