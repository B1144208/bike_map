import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

//連接頁面
import 'config.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final TextEditingController oldPasswordController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String promptMessage = "";

  @override
  void initState() {
    super.initState();

    newPasswordController.addListener(_validatePasswordMatch);
    confirmPasswordController.addListener(_validatePasswordMatch);
  }

  void _validatePasswordMatch() {
    setState(() {
      if (newPasswordController.text != confirmPasswordController.text) {
        promptMessage = "新密碼不一致！";
      } else {
        promptMessage = "";
      }
    });
  }

  Future<void> _submitChangePassword() async {
    if (oldPasswordController.text.isEmpty ||
        newPasswordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      setState(() => promptMessage = "密碼欄位不能為空");
      return;
    }

    if (newPasswordController.text != confirmPasswordController.text) {
      setState(() => promptMessage = "新密碼不一致！");
      return;
    }

    // 檢查新密碼不能與舊密碼相同
    if (newPasswordController.text == oldPasswordController.text) {
      setState(() => promptMessage = "新密碼不能與舊密碼相同！");
      return;
    }

    setState(() {
      _isLoading = true;
      promptMessage = "";
    });

    try {
      // 從 SharedPreferences 取得當前用戶資訊
      final prefs = await SharedPreferences.getInstance();
      final userID = prefs.getInt('UserID');
      final account = prefs.getString('Account');

      if (userID == null || account == null) {
        setState(() {
          promptMessage = "用戶資訊錯誤，請重新登入";
          _isLoading = false;
        });
        return;
      }

      // 第一步：用 checkuser API 驗證舊密碼
      final verifyResponse = await http.get(
        Uri.parse('$baseUrl/user/checkuser?account=$account&password=${oldPasswordController.text}'),
      );

      // 檢查驗證是否成功
      if (verifyResponse.statusCode != 200) {
        setState(() {
          promptMessage = "驗證失敗！";
          _isLoading = false;
        });
        return;
      }

      // 解析驗證回應
      try {
        final verifyData = json.decode(verifyResponse.body);
        final exists = verifyData['exists'];

        // exists 為 0 表示帳號密碼不正確，為 UserID 表示正確
        if (exists == 0) {
          setState(() {
            promptMessage = "舊密碼錯誤！";
            _isLoading = false;
          });
          return;
        }

        // 確認 UserID 與當前用戶一致
        if (exists != userID) {
          setState(() {
            promptMessage = "用戶驗證失敗！";
            _isLoading = false;
          });
          return;
        }

      } catch (e) {
        setState(() {
          promptMessage = "驗證回應解析失敗";
          _isLoading = false;
        });
        return;
      }

      // 第二步：舊密碼驗證成功，更新新密碼
      final requestBody = {
        'Account': account,
        'Password': newPasswordController.text,
        'IsManager': prefs.getInt('IsManager') ?? 0,
      };

      final response = await http.put(
        Uri.parse('$baseUrl/user/updateUser/$userID'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        setState(() {
          promptMessage = "密碼修改成功！";
          _isLoading = false;
        });

        // 清空輸入框
        oldPasswordController.clear();
        newPasswordController.clear();
        confirmPasswordController.clear();

        // 延遲一秒後返回上一頁
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pop(context);

      } else if (response.statusCode == 400) {
        setState(() {
          promptMessage = "請求格式錯誤或舊密碼不正確！";
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        setState(() {
          promptMessage = "舊密碼錯誤！";
          _isLoading = false;
        });
      } else {
        setState(() {
          promptMessage = "密碼修改失敗！";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        promptMessage = "網路錯誤";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double inputWidth = MediaQuery.of(context).size.width / 3;

    return Scaffold(
      appBar: AppBar(title: const Text('修改密碼')),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: SizedBox(
                  width: inputWidth,
                  child: TextField(
                    controller: oldPasswordController,
                    obscureText: _obscureOldPassword,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: '輸入舊密碼',
                      suffixIcon: IconButton(
                        icon: Icon(_obscureOldPassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () {
                          setState(() => _obscureOldPassword = !_obscureOldPassword);
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: SizedBox(
                  width: inputWidth,
                  child: TextField(
                    controller: newPasswordController,
                    obscureText: _obscureNewPassword,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: '輸入新密碼',
                      suffixIcon: IconButton(
                        icon: Icon(_obscureNewPassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () {
                          setState(() => _obscureNewPassword = !_obscureNewPassword);
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: SizedBox(
                  width: inputWidth,
                  child: TextField(
                    controller: confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: '再次輸入新密碼',
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () {
                          setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                        },
                      ),
                    ),
                  ),
                ),
              ),
              if (promptMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    promptMessage,
                    style: TextStyle(
                      color: promptMessage.contains('成功') ? Colors.green : Colors.red,
                      fontSize: 16,
                    ),
                  ),
                ),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _submitChangePassword,
                child: const Text('確認修改'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}