import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    // 模擬密碼更新，這裡可改為實際後端 API 呼叫
    final success = await Future.delayed(const Duration(seconds: 1), () => true);

    if (success) {
      setState(() => promptMessage = "密碼修改成功！");
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context);
    } else {
      setState(() => promptMessage = "密碼修改失敗！");
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
                    ),
                  ),
                ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _submitChangePassword,
                child: const Text('確認修改'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
