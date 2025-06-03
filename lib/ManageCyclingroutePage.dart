import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'config.dart';

class ManageCyclingroutePage extends StatefulWidget {
  const ManageCyclingroutePage({super.key});

  @override
  State<ManageCyclingroutePage> createState() => _ManageCyclingroutePageState();
}



class _ManageCyclingroutePageState extends State<ManageCyclingroutePage> {
  List<dynamic> cities = [];
  List<dynamic> towns = [];
  List<dynamic> cyclingroutes = [];
  // ******************************************************************************************************
  List<List<double>> coordinates = [];

  int? selectedCity;
  int? selectedTown;
  int? editingCRID;

  bool isLoading = true;
  bool isAdding = false;

  final int itemsPerPage = 50;
  int currentPage = 0;

  final ScrollController _scrollController = ScrollController();

  List<dynamic> get currentPageItems {
    final start = currentPage * itemsPerPage;
    final end = (start + itemsPerPage).clamp(0, cyclingroutes.length);
    return cyclingroutes.sublist(start, end);
  }
  
  // keyword
  final TextEditingController keywordController = TextEditingController();

  // 新增/修改資料
  final TextEditingController nameController = TextEditingController();
  final TextEditingController alternateNamesController = TextEditingController();
  final TextEditingController startController = TextEditingController();
  final TextEditingController endController = TextEditingController();
  final TextEditingController lengthController = TextEditingController();
  final TextEditingController directionController = TextEditingController();
  final TextEditingController finishDateController = TextEditingController();
  final TextEditingController managementIdController = TextEditingController();

  // 點座標 ***********************************************************************************
  final TextEditingController coordinateLngController = TextEditingController();
  final TextEditingController coordinateLatController = TextEditingController();
  

  

  @override
  void initState() {
    super.initState();
    fetchCities();
    fetchCyclingroutes();
  }

  Future<void> fetchCities() async {
    final response = await http.get(Uri.parse('$baseUrl/city'));
    if (response.statusCode == 200) {
      setState(() => cities = jsonDecode(response.body));
    }
  }

  Future<void> fetchTowns() async {
    if (selectedCity == null) return;
    final response = await http.get(Uri.parse('$baseUrl/town?cityid=$selectedCity'));
    if (response.statusCode == 200) {
      setState(() => towns = jsonDecode(response.body));
    }
  }

  Future<void> fetchCyclingroutes() async {
    String url = '$baseUrl/cyclingroute';
    final keyword = keywordController.text.trim();
    if (keyword.isNotEmpty) {
      url += '?keyword=$keyword';
    } else if (selectedTown != null) {
      url += '?townid=$selectedTown';
    } else if (selectedCity != null) {
      url += '?cityid=$selectedCity';
    }

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      setState(() {
        cyclingroutes = jsonDecode(response.body);
        isLoading = false;
        currentPage = 0;
      });
    }
  }

  // 確認是否有 Management
  Future<int?> checkOrCreateManagement(String name) async {
    final encodedName = Uri.encodeComponent(name);
    final checkUrl = Uri.parse('$baseUrl/management?name=$encodedName');

    final checkRes = await http.get(checkUrl);

    if (checkRes.statusCode == 200) {
      final result = jsonDecode(checkRes.body);
      return result[0]['ManagementID']; // 成功找到，直接回傳
    }
    // 如果找不到，建立新的
    final createRes = await http.post(
      Uri.parse('$baseUrl/management/insertManagement'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'ManagementName': name}),
    );
    if (createRes.statusCode == 200) {
      final created = jsonDecode(createRes.body);
      return created['ManagementID'];
    }
    return null; // 建立失敗或發生錯誤
  }

  void _addCoordinate() {
    final lng = double.tryParse(coordinateLngController.text);
    final lat = double.tryParse(coordinateLatController.text);
    if (lng != null && lat != null) {
      setState(() {
        coordinates.add([lng, lat]);
        coordinateLngController.clear();
        coordinateLatController.clear();
      });
    }
  }

  void _removeCoordinate(int index) {
    setState(() {
      coordinates.removeAt(index);
    });
  }

  void _clearCoordinates() {
    setState(() {
      coordinates = coordinates;
    });
  }

  Future<bool> _coordinatesEqual(int crid) async {
    final response = await http.get(Uri.parse('$baseUrl/points?crid=$crid'));
    if (response.statusCode != 200) return false;

    final List<dynamic> rawPoints = jsonDecode(response.body);
    final List<List<double>> dbCoords = rawPoints
        .map<List<double>>((p) => [p['Longitude'] * 1.0, p['Latitude'] * 1.0])
        .toList();

    if (dbCoords.length != coordinates.length) return false;

    for (int i = 0; i < dbCoords.length; i++) {
      if (dbCoords[i][0] != coordinates[i][0] ||
          dbCoords[i][1] != coordinates[i][1]) {
        return false;
      }
    }

    return true;
  }

  Future<void> _syncCoordinatesWithServer(int crid) async {
    final equal = await _coordinatesEqual(crid);
    print("equal: $equal");
    if (!equal) {
      await http.delete(Uri.parse('$baseUrl/points/deleteRoute/$crid'));

      for (final coord in coordinates) {
        final lng = double.tryParse(coord[0].toString());
        final lat = double.tryParse(coord[1].toString());

        if (lng != null && lat != null) {
          await http.post(
            Uri.parse('$baseUrl/points/insertPoint'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'CRID': crid,
              'Longitude': lng,
              'Latitude': lat,
            }),
          );
        } else {
          print('轉換失敗，輸入不是數字: lng=$lng, lat=$lat');
        }
      }
    }
  }

  void _loadCoordinatesFromItem(Map<String, dynamic> item) {
    if (item.containsKey('Coordinates')) {
      final coordList = item['Coordinates'] as List<dynamic>;
      final parsed = coordList.map<List<double>>((c) => [c[0] as double, c[1] as double]).toList();
      setState(() {
        coordinates = parsed;
        coordinates = coordinates;
      });
    }
  }

  // 新增 cyclingroutes
  Future<void> _submitInsert() async {
    final managementName = managementIdController.text.trim();
    int? managementID;

    if (managementName.isNotEmpty) {
      managementID = await checkOrCreateManagement(managementName);
      if (managementID == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('無法新增管理單位')),
        );
        return;
      }
    }

    final body = {
      'CityID': selectedCity,
      'TownID': selectedTown,
      'Name': nameController.text,
      'AlternateNames': alternateNamesController.text,
      'Start': startController.text,
      'End': endController.text,
      'Length': double.tryParse(lengthController.text),
      'Direction': directionController.text,
      'FinishDate': finishDateController.text,
      'ManagementID': managementID,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/cyclingroute/insertCyclingroute'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final res = jsonDecode(response.body);
      final insertedId = res['insertedId'];

      
      for (final coord in coordinates) {
        final lng = double.tryParse(coord[0].toString());
        final lat = double.tryParse(coord[1].toString());

        if (lng != null && lat != null) {
          await http.post(
            Uri.parse('$baseUrl/points/insertPoint'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'CRID': insertedId,
              'Longitude': lng,
              'Latitude': lat,
            }),
          );
        } else {
          print('轉換失敗，輸入不是數字: lng=$lng, lat=$lat');
        }
      }

      await fetchCyclingroutes();
      _clearForm();
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // 編輯 cyclingroutes
  Future<void> _submitUpdate() async {
    // ***************************************************************************************************
    print("_submitUpdate(): $editingCRID");
    if (editingCRID == null) return;

    final managementName = managementIdController.text.trim();
    int? managementID;

    if (managementName.isNotEmpty) {
      managementID = await checkOrCreateManagement(managementName);
      if (managementID == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('無法新增管理單位')),
        );
        return;
      }
    }
    
    final body = {
      'CityID': selectedCity,
      'TownID': selectedTown,
      'Name': nameController.text,
      'AlternateNames': alternateNamesController.text,
      'Start': startController.text,
      'End': endController.text,
      'Length': double.tryParse(lengthController.text),
      'Direction': directionController.text,
      'FinishDate': finishDateController.text,
      'ManagementID': managementID,
    };

    final response = await http.put(
      Uri.parse('$baseUrl/cyclingroute/updateCyclingroute/$editingCRID'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      await fetchCyclingroutes();
      setState(() => editingCRID = null);
      _clearForm();
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    final item = cyclingroutes.firstWhere(
      (e) => e['CRID'] == editingCRID,
      orElse: () => {},
    );
    await _syncCoordinatesWithServer(editingCRID??0);
  }

  // 刪除 cyclingroutes
  Future<void> _deleteCyclingroute(int crid) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/cyclingroute/deleteCyclingroute/$crid'),
    );
    if (response.statusCode == 200) {
      await fetchCyclingroutes();
    }
  }

  void _clearForm() {
    setState(() {
      isAdding = false;
      editingCRID = null;
      nameController.clear();
      alternateNamesController.clear();
      startController.clear();
      endController.clear();
      lengthController.clear();
      directionController.clear();
      finishDateController.clear();
      managementIdController.clear();
    });
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
                await _deleteCyclingroute(ybid);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
      child: SizedBox(
        width: MediaQuery.of(context).size.width / 3,
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: label,
          ),
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        ),
      ),
    );
  }


  Widget _cyclingrouteForm() {
    return Column(
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
            const SizedBox(width: 20),
            DropdownButton<int>(
              value: selectedTown,
              hint: const Text('選擇鄉鎮'),
              onChanged: (value) => setState(() => selectedTown = value),
              items: towns.map<DropdownMenuItem<int>>((town) {
                return DropdownMenuItem<int>(
                  value: town['TownID'],
                  child: Text(town['TownName']),
                );
              }).toList(),
            ),
          ],
        ),
        _buildTextField('Name', nameController),
        _buildTextField('Alternate Name', alternateNamesController),
        _buildTextField('Start', startController),
        _buildTextField('End', endController),
        _buildTextField('Length', lengthController, isNumber: true),
        _buildTextField('Direction', directionController),
        _buildTextField('FinishDate', finishDateController),
        _buildTextField('Management', managementIdController),

        const SizedBox(height: 16),

        const Text('座標點'),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: coordinateLngController,
                decoration: const InputDecoration(labelText: '經度'),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: coordinateLatController,
                decoration: const InputDecoration(labelText: '緯度'),
                keyboardType: TextInputType.number,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.green),
              onPressed: _addCoordinate,
            )
          ],
        ),
        ListView.builder(
          shrinkWrap: true,
          itemCount: coordinates.length,
          itemBuilder: (context, index) {
            final coord = coordinates[index];
            return ListTile(
              title: Text('(${coord[0]}, ${coord[1]})'),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeCoordinate(index),
              ),
            );
          },
        ),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: editingCRID == null ? _submitInsert : _submitUpdate,
              child: Text(editingCRID == null ? '確認新增' : '確認修改'),
            ),
            const SizedBox(width: 20),
            ElevatedButton(
              onPressed: _clearForm,
              child: const Text('取消'),
            ),
          ],
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('管理 CyclingRoute')),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      
                      const SizedBox(width: 20),
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
                      const SizedBox(width: 20),
                      DropdownButton<int>(
                        value: selectedTown,
                        hint: const Text('選擇鄉鎮'),
                        onChanged: (value) => setState(() => selectedTown = value),
                        items: towns.map<DropdownMenuItem<int>>((town) {
                          return DropdownMenuItem<int>(
                            value: town['TownID'],
                            child: Text(town['TownName']),
                          );
                        }).toList(),
                      ),
                      const SizedBox(width: 20),
                      SizedBox(
                        width: 150,
                        child: TextField(
                          controller: keywordController,
                          decoration: const InputDecoration(hintText: '輸入關鍵字'),
                        ),
                      ),
                      const SizedBox(width: 20),
                      ElevatedButton(
                        onPressed: fetchCyclingroutes,
                        child: const Text('搜尋'),
                      ),
                      const SizedBox(width: 50),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('新增'),
                        onPressed: () {
                          setState(() {
                            isAdding = true;
                            editingCRID = null;
                            nameController.clear();
                            alternateNamesController.clear();
                            startController.clear();
                            endController.clear();
                            lengthController.clear();
                            directionController.clear();
                            finishDateController.clear();
                            managementIdController.clear();
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  isAdding
                      ? _cyclingrouteForm()
                      : cyclingroutes.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.only(top: 30.0),
                            child: Text('無自行車道資料'),
                          )
                        : Column(
                          children: [
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: currentPageItems.length,
                              itemBuilder: (context, index) {
                                final item = currentPageItems[index];
                                return ListTile(
                                  title: Text('[${item['CRID']}] ${item['Name']}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () {
                                          setState(() {
                                            editingCRID = item['CRID'];
                                            isAdding = true;
                                            selectedCity = item['CityID'];
                                            fetchTowns().then((_) {
                                              setState(() {
                                                selectedTown = item['TownID'];
                                              });
                                            });
                                            nameController.text = item['Name'] ?? '';
                                            alternateNamesController.text = item['AlternateNames'] ?? '';
                                            startController.text = item['Start'] ?? '';
                                            endController.text = item['End'] ?? '';
                                            lengthController.text = item['Length']?.toString() ?? '';
                                            directionController.text = item['Direction'] ?? '';
                                            finishDateController.text = item['FinishDate'] ?? '';
                                            managementIdController.text = item['ManagementName'] ?? '';
                                            _loadCoordinatesFromItem(item);
                                          });
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () {
                                          _confirmDelete(item['CRID']);
                                        },
                                      )
                                    ],
                                  ),
                                );
                              },
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
                                Text('第 ${currentPage + 1} 頁 / 共 ${((cyclingroutes.length - 1) / itemsPerPage).floor() + 1} 頁'),
                                const SizedBox(width: 20),
                                ElevatedButton(
                                  onPressed: (currentPage + 1) * itemsPerPage < cyclingroutes.length
                                      ? () {
                                          setState(() {
                                            currentPage++;
                                          });
                                        }
                                      : null,
                                  child: const Text('下一頁'),
                                ),
                              ],
                            ),
                          ],
                        ),
                ],
              ),
      ),
    );
  }
}
