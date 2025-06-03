import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

//連接頁面
import 'config.dart';


class ManageYoubikePage extends StatefulWidget {
  const ManageYoubikePage({super.key});

  @override
  State<ManageYoubikePage> createState() => _ManagerYoubikeState();
}

class _ManagerYoubikeState extends State<ManageYoubikePage> {
  List<dynamic> cities = [];
  List<dynamic> towns = [];
  List<dynamic> youbikes = [];
  int? selectedCity;
  int? selectedTown;
  int? editingYBID;
  bool isLoadingCities = true;
  bool isLoadingTowns = false;
  bool isLoadingYoubikes = true;
  bool isAdding = false;
  
  // keyword
  final TextEditingController keywordController = TextEditingController();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController longitudeController = TextEditingController();
  final TextEditingController latitudeController = TextEditingController();
  

  int currentPage = 0;
  final int itemsPerPage = 50;

  List<dynamic> get currentPageItems {
    int start = currentPage * itemsPerPage;
    int end = (start + itemsPerPage).clamp(0, youbikes.length);
    return youbikes.sublist(start, end);
  }

  @override
  void initState() {
    super.initState();
    fetchCities();
    fetchYoubikes();
  }

  Future<void> fetchYoubikes() async {
    String url = '$baseUrl/youbike';
    final keyword = keywordController.text.trim();
    if (keyword.isNotEmpty) {
      url += '?keyword=$keyword';
    } else if (selectedCity == null) {
      url += '';
    } else if (selectedTown == null) {
      url += 'cityid=$selectedCity';
    } else {
      url += 'townid=$selectedTown';
    }

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      setState(() {
        youbikes = jsonDecode(response.body);
        isLoadingYoubikes = false;
        currentPage = 0; // ← 每次查詢重設頁碼
      });
    } else {
      setState(() => isLoadingYoubikes = false);
      throw Exception('Failed to load youbikes');
    }
  }

  Future<void> fetchCities() async {
    final response = await http.get(Uri.parse('$baseUrl/city'));

    if (response.statusCode == 200) {
      setState(() {
        cities = jsonDecode(response.body);
        isLoadingCities = false;
      });
    } else {
      setState(() => isLoadingCities = false);
      throw Exception('Failed to load cities');
    }
  }

  Future<void> fetchTowns() async {
    if (selectedCity == null) return;

    setState(() => isLoadingTowns = true);

    final response =
        await http.get(Uri.parse('$baseUrl/town?cityid=$selectedCity'));

    if (response.statusCode == 200) {
      setState(() {
        towns = jsonDecode(response.body);
        isLoadingTowns = false;
      });
    } else {
      setState(() => isLoadingTowns = false);
      throw Exception('Failed to load towns');
    }
  }

  Widget _youbikeForm() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const Divider(height: 32, thickness: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DropdownButton<int>(
                value: selectedCity,
                hint: const Text('選擇城市'),
                onChanged: (value) {
                  setState(() {
                    selectedCity = value;
                    selectedTown = null;
                    fetchTowns();
                  });
                },
                items: cities.map<DropdownMenuItem<int>>((city) {
                  return DropdownMenuItem<int>(
                    value: city['CityID'],
                    child: Text(city['CityName']),
                  );
                }).toList(),
              ),
              const SizedBox(width: 30),
              DropdownButton<int>(
                value: selectedTown,
                hint: const Text('選擇鄉鎮'),
                onChanged: (value) {
                  setState(() => selectedTown = value);
                },
                items: towns.map<DropdownMenuItem<int>>((town) {
                  return DropdownMenuItem<int>(
                    value: town['TownID'],
                    child: Text(town['TownName']),
                  );
                }).toList(),
              ),
            ],
          ),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: '站點名稱'),
          ),
          TextField(
            controller: longitudeController,
            decoration: const InputDecoration(labelText: '經度'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: latitudeController,
            decoration: const InputDecoration(labelText: '緯度'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: editingYBID == null ? _insertYoubike : _updateYoubike,
                child: Text(editingYBID == null ? '確認新增' : '確認修改'),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    isAdding = false;
                    editingYBID = null;
                    nameController.clear();
                    longitudeController.clear();
                    latitudeController.clear();
                  });
                },
                child: const Text('取消'),
              ),
            ],
          )
        ],
      ),
    );
  }
  
  // 新增 youbikes
  Future<void> _insertYoubike() async {
    if (selectedTown == null ||
        nameController.text.isEmpty ||
        longitudeController.text.isEmpty ||
        latitudeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('輸入不完整')),
      );
      return;
    }

    final body = {
      'TownID': selectedTown,
      'Name': nameController.text,
      'Longitude': double.tryParse(longitudeController.text),
      'Latitude': double.tryParse(latitudeController.text),
    };

    final response = await http.post(
      Uri.parse('$baseUrl/youbike/insertYoubike'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('新增成功')),
      );
      setState(() {
        isAdding = false;
        
        nameController.clear();
        longitudeController.clear();
        latitudeController.clear();
      });
      await fetchYoubikes();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('新增失敗')),
      );
    }
  }

  // 修改 youbikes
  Future<void> _updateYoubike() async {
    if (editingYBID == null || selectedTown == null || nameController.text.isEmpty || longitudeController.text.isEmpty || latitudeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('輸入不完整')),
      );
      return;
    }

    final body = {
      'TownID': selectedTown,
      'Name': nameController.text,
      'Longitude': double.tryParse(longitudeController.text),
      'Latitude': double.tryParse(latitudeController.text),
    };

    final response = await http.put(
      Uri.parse('$baseUrl/youbike/updateYoubike/$editingYBID'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('修改成功')),
      );
      setState(() {
        isAdding = false;
        editingYBID = null;
        nameController.clear();
        longitudeController.clear();
        latitudeController.clear();
      });
      await fetchYoubikes();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('修改失敗')),
      );
    }
  }



  // 刪除 youbikes
  Future<void> _deleteYoubike(int ybid) async {
    final url = Uri.parse('$baseUrl/youbike/deleteYoubike/$ybid');
    final response = await http.delete(url);

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('刪除成功')),
      );
      await fetchYoubikes(); // 刪除後重新整理列表
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('刪除失敗')),
      );
    }
  }
  void _confirmDelete(int ybid) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('確認刪除'),
          content: Text('確定要刪除站點 $ybid 嗎？'),
          actions: [
            TextButton(
              child: const Text('取消'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('刪除'),
              onPressed: () async {
                Navigator.of(context).pop(); // 關閉 dialog
                await _deleteYoubike(ybid);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理 YouBike'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                DropdownButton<int>(
                  value: selectedCity,
                  hint: const Text('選擇城市'),
                  onChanged: (int? newCityID) {
                    setState(() {
                      selectedCity = newCityID;
                      selectedTown = null;
                      fetchTowns();
                    });
                  },
                  items: cities.map<DropdownMenuItem<int>>((city) {
                    return DropdownMenuItem<int>(
                      value: city['CityID'],
                      child: Text(city['CityName']),
                    );
                  }).toList(),
                ),
                const SizedBox(width: 30),
                DropdownButton<int>(
                  value: selectedTown,
                  hint: const Text('選擇鄉鎮'),
                  onChanged: (int? newTownID) {
                    setState(() {
                      selectedTown = newTownID;
                    });
                  },
                  items: [
                    if (selectedCity != null)
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('選擇鄉鎮'),
                      ),
                    ...towns.map<DropdownMenuItem<int>>((town) {
                      return DropdownMenuItem<int>(
                        value: town['TownID'],
                        child: Text(town['TownName']),
                      );
                    }),
                  ],
                ),
                const SizedBox(width: 30),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: keywordController,
                    decoration: const InputDecoration(hintText: '輸入關鍵字'),
                  ),
                ),
                const SizedBox(width: 30),
                ElevatedButton(
                  onPressed: () async {
                    isAdding = false;
                    editingYBID = null;
                    setState(() => isLoadingYoubikes = true);
                    await fetchYoubikes();
                  },
                  child: const Text('搜尋'),
                ),
                const SizedBox(width: 50),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('新增'),
                  onPressed: () {
                    setState(() {
                      isAdding = true;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: isLoadingYoubikes
              ? const Center(child: CircularProgressIndicator())
              : isAdding
                ? _youbikeForm()
                : youbikes.isEmpty
                    ? const Center(child: Text('無 YouBike 站點資料'))
                    : Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            itemCount: currentPageItems.length,
                            itemBuilder: (context, index) {
                              final item = currentPageItems[index];
                              return ListTile(
                                title: Text('[${item['YBID']}] ${item['Name'] ?? '未命名'}'),
                                subtitle: Text(
                                  '${item['CityName'] ?? ''} ${item['TownName'] ?? ''}\n經度: ${item['Longitude']}、緯度: ${item['Latitude']}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () {
                                        // **********************************************************************************************************************
                                        setState(() {
                                          editingYBID = item['YBID'];
                                          isAdding = true;
                                          selectedCity = item['CityID'];
                                          fetchTowns().then((_) {
                                            setState(() {
                                              selectedTown = item['TownID'];
                                            });
                                          });
                                          nameController.text = item['Name'] ?? '';
                                          longitudeController.text = item['Longitude'].toString();
                                          latitudeController.text = item['Latitude'].toString();
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () {
                                        _confirmDelete(item['YBID']);
                                      },
                                    ),
                                  ],
                                ),
                              );

                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: currentPage > 0
                                  ? () {
                                      setState(() {
                                        currentPage--;
                                      });
                                    }
                                  : null,
                              child: const Text('上一頁'),
                            ),
                            const SizedBox(width: 20),
                            Text(
                              '第 ${currentPage + 1} 頁 / 共 ${((youbikes.length - 1) / itemsPerPage).floor() + 1} 頁',
                            ),
                            const SizedBox(width: 20),
                            ElevatedButton(
                              onPressed:
                                  (currentPage + 1) * itemsPerPage < youbikes.length
                                      ? () {
                                          setState(() {
                                            currentPage++;
                                          });
                                        }
                                      : null,
                              child: const Text('下一頁'),
                            ),
                          ],
                        )
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
