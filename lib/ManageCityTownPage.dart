import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

//連接頁面
import 'config.dart';

class ManageCityTownPage extends StatefulWidget {
  const ManageCityTownPage({super.key});

  @override
  State<ManageCityTownPage> createState() => _ManagerCityTownState();
}

class _ManagerCityTownState extends State<ManageCityTownPage> {
  List<dynamic> cities = [];
  List<dynamic> towns = [];
  int? selectedCity;
  int? editingCityID;
  int? editingTownID;
  bool isLoadingCities = true;
  bool isLoadingTowns = false;
  bool isAddingCity = false;
  bool isAddingTown = false;

  // 城市相關 Controller
  final TextEditingController cityNameController = TextEditingController();

  // 鄉鎮相關 Controller
  final TextEditingController townNameController = TextEditingController();

  int currentCityPage = 0;
  int currentTownPage = 0;
  final int itemsPerPage = 20;

  // 城市分頁項目
  List<dynamic> get currentCityItems {
    int start = currentCityPage * itemsPerPage;
    int end = (start + itemsPerPage).clamp(0, cities.length);
    return cities.sublist(start, end);
  }

  // 鄉鎮分頁項目
  List<dynamic> get currentTownItems {
    int start = currentTownPage * itemsPerPage;
    int end = (start + itemsPerPage).clamp(0, towns.length);
    return towns.sublist(start, end);
  }

  @override
  void initState() {
    super.initState();
    fetchCities();
  }

  // 取得所有城市
  Future<void> fetchCities() async {
    final response = await http.get(Uri.parse('$baseUrl/city'));

    if (response.statusCode == 200) {
      setState(() {
        cities = jsonDecode(response.body);
        isLoadingCities = false;
        currentCityPage = 0;
      });
    } else {
      setState(() => isLoadingCities = false);
      throw Exception('Failed to load cities');
    }
  }

  // 根據城市ID取得鄉鎮
  Future<void> fetchTowns() async {
    if (selectedCity == null) {
      setState(() {
        towns = [];
        isLoadingTowns = false;
        currentTownPage = 0;
      });
      return;
    }

    setState(() => isLoadingTowns = true);

    final response = await http.get(Uri.parse('$baseUrl/town?cityid=$selectedCity'));

    if (response.statusCode == 200) {
      setState(() {
        towns = jsonDecode(response.body);
        isLoadingTowns = false;
        currentTownPage = 0;
      });
    } else {
      setState(() => isLoadingTowns = false);
      throw Exception('Failed to load towns');
    }
  }

  // 城市表單
  Widget _cityForm() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        children: [
          Text(
            editingCityID == null ? '新增城市' : '編輯城市',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: cityNameController,
            decoration: const InputDecoration(labelText: '城市名稱'),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: editingCityID == null ? _insertCity : _updateCity,
                child: Text(editingCityID == null ? '確認新增' : '確認修改'),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    isAddingCity = false;
                    editingCityID = null;
                    cityNameController.clear();
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

  // 鄉鎮表單
  Widget _townForm() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        children: [
          Text(
            editingTownID == null ? '新增鄉鎮' : '編輯鄉鎮',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          DropdownButton<int>(
            value: selectedCity,
            hint: const Text('選擇城市'),
            onChanged: (value) {
              setState(() {
                selectedCity = value;
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
          const SizedBox(height: 16),
          TextField(
            controller: townNameController,
            decoration: const InputDecoration(labelText: '鄉鎮名稱'),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: editingTownID == null ? _insertTown : _updateTown,
                child: Text(editingTownID == null ? '確認新增' : '確認修改'),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    isAddingTown = false;
                    editingTownID = null;
                    townNameController.clear();
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

  // 新增城市
  Future<void> _insertCity() async {
    if (cityNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('城市名稱不能為空')),
      );
      return;
    }

    final body = {
      'CityName': cityNameController.text,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/city/insertCity'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('城市新增成功')),
      );
      setState(() {
        isAddingCity = false;
        cityNameController.clear();
      });
      await fetchCities();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('城市新增失敗')),
      );
    }
  }

  // 修改城市
  Future<void> _updateCity() async {
    if (editingCityID == null || cityNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('輸入不完整')),
      );
      return;
    }

    final body = {
      'CityName': cityNameController.text,
    };

    final response = await http.put(
      Uri.parse('$baseUrl/city/updateCity/$editingCityID'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('城市修改成功')),
      );
      setState(() {
        isAddingCity = false;
        editingCityID = null;
        cityNameController.clear();
      });
      await fetchCities();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('城市修改失敗')),
      );
    }
  }

  // 刪除城市
  Future<void> _deleteCity(int cityId) async {
    final url = Uri.parse('$baseUrl/city/deleteCity/$cityId');
    final response = await http.delete(url);

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('城市刪除成功')),
      );
      await fetchCities();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('城市刪除失敗')),
      );
    }
  }

  // 確認刪除城市
  void _confirmDeleteCity(int cityId, String cityName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('確認刪除'),
          content: Text('確定要刪除城市 "$cityName" 嗎？'),
          actions: [
            TextButton(
              child: const Text('取消'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('刪除'),
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteCity(cityId);
              },
            ),
          ],
        );
      },
    );
  }

  // 新增鄉鎮
  Future<void> _insertTown() async {
    if (selectedCity == null || townNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請選擇城市並輸入鄉鎮名稱')),
      );
      return;
    }

    final body = {
      'CityID': selectedCity,
      'TownName': townNameController.text,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/town/insertTown'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('鄉鎮新增成功')),
      );
      setState(() {
        isAddingTown = false;
        townNameController.clear();
      });
      await fetchTowns();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('鄉鎮新增失敗')),
      );
    }
  }

  // 修改鄉鎮
  Future<void> _updateTown() async {
    if (editingTownID == null || selectedCity == null || townNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('輸入不完整')),
      );
      return;
    }

    final body = {
      'CityID': selectedCity,
      'TownName': townNameController.text,
    };

    final response = await http.put(
      Uri.parse('$baseUrl/town/updateTown/$editingTownID'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('鄉鎮修改成功')),
      );
      setState(() {
        isAddingTown = false;
        editingTownID = null;
        townNameController.clear();
      });
      await fetchTowns();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('鄉鎮修改失敗')),
      );
    }
  }

  // 刪除鄉鎮
  Future<void> _deleteTown(int townId) async {
    final url = Uri.parse('$baseUrl/town/deleteTown/$townId');
    final response = await http.delete(url);

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('鄉鎮刪除成功')),
      );
      await fetchTowns();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('鄉鎮刪除失敗')),
      );
    }
  }

  // 確認刪除鄉鎮
  void _confirmDeleteTown(int townId, String townName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('確認刪除'),
          content: Text('確定要刪除鄉鎮 "$townName" 嗎？'),
          actions: [
            TextButton(
              child: const Text('取消'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('刪除'),
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteTown(townId);
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
        title: const Text('管理 City/Town'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 選擇城市區域
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DropdownButton<int>(
                  value: selectedCity,
                  hint: const Text('選擇城市查看鄉鎮'),
                  onChanged: (int? newCityID) {
                    setState(() {
                      selectedCity = newCityID;
                      isAddingCity = false;
                      isAddingTown = false;
                      editingCityID = null;
                      editingTownID = null;
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
              ],
            ),

            const SizedBox(height: 16),

            Expanded(
              child: Row(
                children: [
                  // 左邊城市區域
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        // 城市標題和新增按鈕
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('城市管理', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('新增城市'),
                              onPressed: () {
                                setState(() {
                                  isAddingCity = true;
                                  isAddingTown = false;
                                  editingCityID = null;
                                  cityNameController.clear();
                                });
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // 城市表單或列表
                        Expanded(
                          child: isLoadingCities
                              ? const Center(child: CircularProgressIndicator())
                              : isAddingCity
                              ? _cityForm()
                              : cities.isEmpty
                              ? const Center(child: Text('無城市資料'))
                              : Column(
                            children: [
                              Expanded(
                                child: ListView.builder(
                                  itemCount: currentCityItems.length,
                                  itemBuilder: (context, index) {
                                    final city = currentCityItems[index];
                                    return ListTile(
                                      title: Text('[${city['CityID']}] ${city['CityName']}'),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.blue),
                                            onPressed: () {
                                              setState(() {
                                                editingCityID = city['CityID'];
                                                isAddingCity = true;
                                                isAddingTown = false;
                                                cityNameController.text = city['CityName'];
                                              });
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () {
                                              _confirmDeleteCity(city['CityID'], city['CityName']);
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              // 城市分頁按鈕
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton(
                                    onPressed: currentCityPage > 0
                                        ? () {
                                      setState(() {
                                        currentCityPage--;
                                      });
                                    }
                                        : null,
                                    child: const Text('上一頁'),
                                  ),
                                  const SizedBox(width: 10),
                                  Text('第 ${currentCityPage + 1} 頁'),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                    onPressed: (currentCityPage + 1) * itemsPerPage < cities.length
                                        ? () {
                                      setState(() {
                                        currentCityPage++;
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

                  const VerticalDivider(width: 20),

                  // 右邊鄉鎮區域
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        // 鄉鎮標題和新增按鈕
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('鄉鎮管理', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('新增鄉鎮'),
                              onPressed: selectedCity != null ? () {
                                setState(() {
                                  isAddingTown = true;
                                  isAddingCity = false;
                                  editingTownID = null;
                                  townNameController.clear();
                                });
                              } : null,
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // 鄉鎮表單或列表
                        Expanded(
                          child: selectedCity == null
                              ? const Center(child: Text('請先選擇城市'))
                              : isLoadingTowns
                              ? const Center(child: CircularProgressIndicator())
                              : isAddingTown
                              ? _townForm()
                              : towns.isEmpty
                              ? const Center(child: Text('該城市無鄉鎮資料'))
                              : Column(
                            children: [
                              Expanded(
                                child: ListView.builder(
                                  itemCount: currentTownItems.length,
                                  itemBuilder: (context, index) {
                                    final town = currentTownItems[index];
                                    return ListTile(
                                      title: Text('[${town['TownID']}] ${town['TownName']}'),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.blue),
                                            onPressed: () {
                                              setState(() {
                                                editingTownID = town['TownID'];
                                                isAddingTown = true;
                                                isAddingCity = false;
                                                townNameController.text = town['TownName'];
                                              });
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () {
                                              _confirmDeleteTown(town['TownID'], town['TownName']);
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              // 鄉鎮分頁按鈕
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton(
                                    onPressed: currentTownPage > 0
                                        ? () {
                                      setState(() {
                                        currentTownPage--;
                                      });
                                    }
                                        : null,
                                    child: const Text('上一頁'),
                                  ),
                                  const SizedBox(width: 10),
                                  Text('第 ${currentTownPage + 1} 頁'),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                    onPressed: (currentTownPage + 1) * itemsPerPage < towns.length
                                        ? () {
                                      setState(() {
                                        currentTownPage++;
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}