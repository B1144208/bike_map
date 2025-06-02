import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// 連接頁面
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

  final String getAllUsersUrl = '$baseUrl/user';
  final String createUserUrl = '$baseUrl/user/insertUser';
  String updateUserUrl(int id) => '$baseUrl/user/updateUser/$id';
  String deleteUserUrl(int id) => '$baseUrl/user/deleteUser/$id';


  @override
  void initState() {
    super.initState();
    _fetchUsers();
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
                DropdownButton<int>(
                  value: managerLevel,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('一般用戶')),
                    DropdownMenuItem(value: 1, child: Text('管理員')),
                    DropdownMenuItem(value: 2, child: Text('超級管理員')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => managerLevel = value);
                    }
                  },
                ),
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

                  if (account.isEmpty || (!isEdit && password.isEmpty)) return;

                  final payload = {
                    'Account': account,
                    'Password': password,
                    'IsManager': managerLevel
                  };

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
          return ListTile(
            title: Text('${user['Account']}（${_managerLabel(user['IsManager'])}）'),
            subtitle: Text('UserID: ${user['UserID']}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
