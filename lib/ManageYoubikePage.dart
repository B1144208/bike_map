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
  String? editCity;
  String? editTown;
  String? editTownID;
  LatLng? editYBlatlng;
  LatLng? tempLatlng;
  bool isLoadingCities = true;
  bool isLoadingTowns = false;
  bool isLoadingYoubikes = true;
  bool isInsertUpdate = false;
  String _selectedLocationName = '尚未選擇地區';
  
  
  // keyword
  final TextEditingController keywordController = TextEditingController();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController longitudeController = TextEditingController();
  final TextEditingController latitudeController = TextEditingController();

  // map
  final mapController = MapController();
  

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
    }else{
      if (selectedCity == null) {}
      else if (selectedCity != null) {
        url += '?cityid=$selectedCity';
      }
      if (selectedTown != null) {
        url += '&townid=$selectedTown';  // 使用 '&' 來附加其他參數
      }
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
  // 查詢 TownID
  Future<void> searchTownId() async {
    
    if (editCity==null || editTown==null) {
      // 確保 cityName 和 townName 有被填寫
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('查詢失敗')),
      );
      return;
    }
    final response = await http.get(Uri.parse('$baseUrl/town/searchTownId?cityname=$editCity&townname=$editTown'));

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);

        if (result.isNotEmpty) {
          // 如果找到 TownID，將它儲存到 editTownID
          setState(() {
            editTownID = result[0]['TownID'].toString(); // 假設返回的 JSON 是一個包含 TownID 的數組
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('找不到對應的城市、鄉鎮')),
          );
        }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('查詢失敗，請稍後再試')),
      );
    }
  }

  String fetchLocal() {
    if (tempLatlng == null) return '無法取得地區';

    const Distance distance = Distance();

    double minTownDist = double.infinity;
    double minCityDist = double.infinity;

    Map<String, dynamic>? nearestTown;
    Map<String, dynamic>? nearestCity;

    for (var town in towns) {
      if (town.containsKey('Latitude') && town.containsKey('Longitude')) {
        final d = distance(
          tempLatlng!,
          LatLng(town['Latitude'] * 1.0, town['Longitude'] * 1.0),
        );
        if (d < minTownDist) {
          minTownDist = d;
          nearestTown = town;
        }
      }
    }

    for (var city in cities) {
      if (city.containsKey('Latitude') && city.containsKey('Longitude')) {
        final d = distance(
          tempLatlng!,
          LatLng(city['Latitude'] * 1.0, city['Longitude'] * 1.0),
        );
        if (d < minCityDist) {
          minCityDist = d;
          nearestCity = city;
        }
      }
    }

    // 使用 setState 更新 editCity 和 editTown
    setState(() {
      // 更新全域變數
      editTown = nearestTown != null ? nearestTown['TownName'] : null;
      editCity = nearestCity != null ? nearestCity['CityName'] : null;
      _selectedLocationName = '選擇地區: ${editCity ?? '未知城市'} ${editTown ?? '未知鄉鎮'}';
    });
    return _selectedLocationName;
  }

  void updateLatLngFromTextControllers() {
    final longitude = double.tryParse(longitudeController.text);
    final latitude = double.tryParse(latitudeController.text);

    if (longitude != null && latitude != null) {
      setState(() {
        tempLatlng = LatLng(latitude, longitude);

        // 根據 tempLatlng 找到 city/town
        _selectedLocationName = fetchLocal();
      });
    }

    updateTextControllersFromLatLng();
  }

  // 反向地理編碼：將經緯度轉換為地址
  Future<String> _getCityAndTownFromCoordinates(double lat, double lng) async {
    try {
      final url =
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1&accept-language=zh-TW';

      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Flutter App'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['address'] != null) {
          final addr = data['address'];

          // 嘗試從結構化地址取得 city 和 town（台灣常用 city + suburb 或 city + town）
          String city = addr['city'] ??
                        addr['state'] ??      // 有些資料用 state 表示縣市（如：新竹縣）
                        addr['county'] ??     // 有些資料用 county
                        '未知城市';

          String town = addr['town'] ??
                        addr['city_district'] ?? 
                        addr['suburb'] ?? 
                        '未知鄉鎮';

          editCity = city;
          editTown = town;
          return '$city $town';
        }
      }
    } catch (e) {
      print('反向地理編碼錯誤: $e');
    }

    // 若失敗則回傳座標字串
    return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
  }


  // 當 tempLatlng 改變時，更新經緯度輸入框
  void updateTextControllersFromLatLng() async{
    if (tempLatlng != null) {
      // 更新輸入框內容
      longitudeController.text = tempLatlng!.longitude.toString();
      latitudeController.text = tempLatlng!.latitude.toString();

      // 呼叫反向地理編碼 API
      final address = await _getCityAndTownFromCoordinates(
        tempLatlng!.latitude,
        tempLatlng!.longitude,
      );

      // 更新畫面狀態
      setState(() {
        _selectedLocationName = '選擇地區: $address';
      });
    }
  }



  // youbike 標記
  Widget _youbikeMarker() {
    
    return MarkerLayer(
      markers: [
        Marker(
          point: editYBlatlng==null? LatLng(0.0, 0.0): editYBlatlng!, // 使用 editYBlatlng 的座標
          
          width: 60,
          height: 60,
          child: GestureDetector(
            onTap: () {
              // 你可以在這裡加點擊後的邏輯
              
            },
            child: const Icon(
              Icons.location_pin,
              color: Colors.red,
              size: 30,
            ),
          ),
        ),
        // 顯示 tempLatlng 上的綠色標記
        if (tempLatlng != null)
          Marker(
            point: tempLatlng!,
            width: 60,
            height: 60,
            child: const Icon(
              Icons.location_on,
              color: Colors.green,
              size: 30,
            ),
          ),
      ],
    );
    
  }

  
  // 新增/編輯 Youbike UI-地圖
  Widget _youbikeMap(){
    return SizedBox(
      height: 300,
      child: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          onTap: (tapPosition, point) async{
            // 當地圖被點擊時，儲存點擊的座標並更新 tempLatlng
            setState(() {
              tempLatlng = point;  // 儲存點擊的座標
            });
            updateTextControllersFromLatLng();
          },
          initialCameraFit: CameraFit.bounds(
            bounds: LatLngBounds(
              const LatLng(21.8, 119.8),
              const LatLng(25.3, 122.0),
            ),
            padding: const EdgeInsets.all(0),
          ),
        ),
        children: [
          TileLayer(
            urlTemplate:
            'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
            userAgentPackageName: 'com.example.app',
          ),
          _youbikeMarker(),

        ],
      ),
    );
  }

  // 新增/編輯 Youbike UI-文字框
  Widget _youbikeForm() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const Divider(height: 32, thickness: 1),
          Text(
            _selectedLocationName,
            style: const TextStyle(fontSize: 16),
          ),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: '站點名稱'),
          ),
          TextField(
            controller: longitudeController,
            decoration: const InputDecoration(labelText: '經度'),
            keyboardType: TextInputType.number,
            onChanged: (_) => updateLatLngFromTextControllers(),
          ),
          TextField(
            controller: latitudeController,
            decoration: const InputDecoration(labelText: '緯度'),
            keyboardType: TextInputType.number,
            onChanged: (_) => updateLatLngFromTextControllers(),
          ),
          const SizedBox(height: 16),
          _youbikeMap(),
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
                    isInsertUpdate = false;
                    editingYBID = null;
                    editYBlatlng = null;
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
    await searchTownId();
    if (editTownID == null ||
        nameController.text.isEmpty ||
        longitudeController.text.isEmpty ||
        latitudeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('輸入不完整')),
      );
      return;
    }

    final body = {
      'TownID': editTownID,
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
        isInsertUpdate = false;
        editingYBID = null;
        editYBlatlng = null;
        editCity = null;
        editTown = null;
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
    await searchTownId();
    if (editingYBID == null || editTownID == null || nameController.text.isEmpty || longitudeController.text.isEmpty || latitudeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('輸入不完整')),
      );
      return;
    }

    final body = {
      'TownID': editTownID,
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
        isInsertUpdate = false;
        editingYBID = null;
        editYBlatlng = null;
        editCity = null;
        editTown = null;
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
  // 確認刪除懸浮框
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
                    isInsertUpdate = false;
                    editingYBID = null;
                    editYBlatlng = null;
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
                      isInsertUpdate = true;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: isLoadingYoubikes
              ? const Center(child: CircularProgressIndicator())
              : isInsertUpdate
                // 新增
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
                                      onPressed: () async {
                                        setState(() {
                                          editingYBID = item['YBID'];
                                          editYBlatlng = LatLng(item['Latitude'], item['Longitude']);
                                          tempLatlng = LatLng(item['Latitude'], item['Longitude']);
                                          isInsertUpdate = true;
                                          selectedCity = item['CityID'];
                                          nameController.text = item['Name'] ?? '';
                                          longitudeController.text = item['Longitude'].toString();
                                          latitudeController.text = item['Latitude'].toString();
                                        });
                                        await fetchTowns(); // 等待鄉鎮資料加載完
                                        setState(() {
                                          selectedTown = item['TownID'];
                                        });

                                        updateTextControllersFromLatLng(); // 呼叫來更新地區文字
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
