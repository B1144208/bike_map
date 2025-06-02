import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// config.dart 中要定義 baseUrl，例如：https://xxx.ngrok-free.app
import 'config.dart';

class ManageUserPage extends StatefulWidget {
  const ManageUserPage({super.key});

  @override
  State<ManageUserPage> createState() => _ManageUserPageState();
}

class _ManageUserPageState extends State<ManageUserPage> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String _error = '';
  int _currentUserManager = 0; // 當前使用者的管理員等級

  final String getAllUsersUrl = '$baseUrl/user';
  final String createUserUrl = '$baseUrl/user/insertUser';
  String updateUserUrl(int id) => '$baseUrl/user/updateUser/$id';
  String deleteUserUrl(int id) => '$baseUrl/user/deleteUser/$id';

  @override
  void initState() {
    super.initState();
    _loadUserManager();
    _fetchUsers();
  }

  // 載入當前使用者的管理員等級
  Future<void> _loadUserManager() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserManager = prefs.getInt('IsManager') ?? 0;
    });
  }

  Future<void> _fetchUsers() async {
    try {
      final response = await http.get(Uri.parse(getAllUsersUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        setState(() {
          _users = data.map((user) => {
            'UserID': user['UserID'],
            'Account': user['Account'],
            'IsManager': user['IsManager'],
          }).toList();
          _loading = false;
        });
      } else {
        setState(() {
          _error = '錯誤狀態碼：${response.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '連線錯誤：$e';
        _loading = false;
      });
    }
  }

  String _managerLabel(int level) {
    switch (level) {
      case 1:
        return '管理員';
      case 2:
        return '超級管理員';
      default:
        return '一般用戶';
    }
  }

  // 指派管理員功能 (一般用戶 -> 管理員)
  Future<void> _promoteToManager(int userID, String account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('指派管理員'),
        content: Text('確定要將 $account 指派為管理員嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('確定')),
        ],
      ),
    );

    if (confirm ?? false) {
      await _updateUserManager(userID, account, 1);
    }
  }

  // 賦予超級管理員功能 (管理員 -> 超級管理員，自己降級為管理員)
  Future<void> _promoteToSuperManager(int userID, String account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('賦予超級管理員'),
        content: Text('確定要將 $account 賦予超級管理員權限嗎？\n注意：您將會降級為管理員。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('確定')),
        ],
      ),
    );

    if (confirm ?? false) {
      // 先將目標用戶升級為超級管理員
      await _updateUserManager(userID, account, 2);

      // 將自己降級為管理員
      final prefs = await SharedPreferences.getInstance();
      final currentUserID = prefs.getInt('UserID');
      final currentAccount = prefs.getString('Account');
      if (currentUserID != null && currentAccount != null) {
        await _updateUserManager(currentUserID, currentAccount, 1);
        // 更新本地 SharedPreferences
        await prefs.setInt('IsManager', 1);
        setState(() {
          _currentUserManager = 1;
        });
      }

      // 重新載入頁面
      _fetchUsers();
    }
  }

  // 更新使用者管理員等級（不包含密碼）
  Future<void> _updateUserManager(int userID, String account, int managerLevel) async {
    try {
      final payload = {
        'Account': account,
        'IsManager': managerLevel
      };

      final response = await http.put(
        Uri.parse(updateUserUrl(userID)),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        _fetchUsers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失敗：${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新錯誤：$e')),
      );
    }
  }

  void _showUserDialog({Map<String, dynamic>? user}) {
    final isEdit = user != null;
    final TextEditingController accountController =
    TextEditingController(text: user?['Account'] ?? '');
    final TextEditingController passwordController = TextEditingController();
    int managerLevel = user?['IsManager'] ?? 0;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEdit ? '修改使用者' : '新增使用者'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: accountController,
                  decoration: const InputDecoration(labelText: '帳號'),
                ),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: '密碼'),
                  obscureText: true,
                ),
                // 權限選單顯示邏輯：
                // 1. 新增時：不顯示選單，固定為一般用戶
                // 2. 編輯時管理員：不顯示選單（無法修改權限）
                // 3. 編輯時超級管理員：顯示完整選單
                if (!isEdit) ...[
                  // 新增模式：不顯示選單，固定為一般用戶
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      '權限等級：一般用戶',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ),
                ] else if (_currentUserManager == 2) ...[
                  // 編輯模式 + 超級管理員：顯示完整選單
                  DropdownButton<int>(
                    value: managerLevel,
                    items: const [
                      DropdownMenuItem(value: 2, child: Text('超級管理員')),
                      DropdownMenuItem(value: 1, child: Text('管理員')),
                      DropdownMenuItem(value: 0, child: Text('一般用戶')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => managerLevel = value);
                      }
                    },
                  ),
                ] else ...[
                  // 編輯模式 + 管理員：只顯示當前權限，無法修改
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      '權限等級：${_managerLabel(managerLevel)}',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final account = accountController.text.trim();
                  final password = passwordController.text;

                  // 新增模式必須要有帳號和密碼，編輯模式只需要帳號
                  if (account.isEmpty || (!isEdit && password.isEmpty)) return;

                  final payload = <String, dynamic>{
                    'Account': account,
                    'IsManager': managerLevel
                  };

                  // 只有當有輸入密碼時才加入 Password 欄位
                  if (password.isNotEmpty) {
                    payload['Password'] = password;
                  }

                  try {
                    final response = isEdit
                        ? await http.put(
                      Uri.parse(updateUserUrl(user!['UserID'])),
                      headers: {'Content-Type': 'application/json'},
                      body: json.encode(payload),
                    )
                        : await http.post(
                      Uri.parse(createUserUrl),
                      headers: {'Content-Type': 'application/json'},
                      body: json.encode(payload),
                    );

                    if (response.statusCode == 200 || response.statusCode == 201) {
                      Navigator.pop(context);
                      _fetchUsers();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('操作失敗：${response.statusCode}')),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('錯誤：$e')),
                    );
                  }
                },
                child: Text(isEdit ? '修改' : '新增'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteUser(int userID) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除使用者'),
        content: const Text('確定要刪除這個使用者嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );

    if (confirm ?? false) {
      try {
        final response = await http.delete(Uri.parse(deleteUserUrl(userID)));
        if (response.statusCode == 200) {
          _fetchUsers();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('刪除失敗：${response.statusCode}')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('刪除錯誤：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理使用者'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
          ? Center(child: Text(_error))
          : ListView.builder(
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          final userManager = user['IsManager'] as int;

          return ListTile(
            title: Text('${user['Account']}（${_managerLabel(userManager)}）'),
            subtitle: Text('UserID: ${user['UserID']}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 指派管理員按鈕：只有超級管理員(2)可以用，目標是一般用戶(0)
                if (_currentUserManager == 2 && userManager == 0)
                  IconButton(
                    icon: const Icon(Icons.person_add, color: Colors.green),
                    tooltip: '指派管理員',
                    onPressed: () => _promoteToManager(user['UserID'], user['Account']),
                  ),
                // 賦予超級管理員按鈕：只有超級管理員(2)可以用，目標是管理員(1)
                if (_currentUserManager == 2 && userManager == 1)
                  IconButton(
                    icon: const Icon(Icons.admin_panel_settings, color: Colors.orange),
                    tooltip: '賦予超級管理員',
                    onPressed: () => _promoteToSuperManager(user['UserID'], user['Account']),
                  ),
                // 編輯和刪除按鈕：管理員和超級管理員都可以用
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showUserDialog(user: user),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteUser(user['UserID']),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUserDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}