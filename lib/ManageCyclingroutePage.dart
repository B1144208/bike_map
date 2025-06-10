import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
  List<List<double>> coordinates = [];

  // 路線分區相關
  List<Map<String, String>> routeAreas = []; // 存放 {cityName, townName}

  int? selectedCity;
  int? selectedTown;
  int? editingCRID;

  bool isLoading = true;
  bool isAdding = false;
  bool isSimpleMode = true;
  bool isLoadingAddress = false;

  final int itemsPerPage = 50;
  int currentPage = 0;

  final ScrollController _scrollController = ScrollController();
  final mapController = MapController();

  List<dynamic> get currentPageItems {
    final start = currentPage * itemsPerPage;
    final end = (start + itemsPerPage).clamp(0, cyclingroutes.length);
    return cyclingroutes.sublist(start, end);
  }

  // Controllers
  final TextEditingController keywordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController alternateNamesController = TextEditingController();
  final TextEditingController startController = TextEditingController();
  final TextEditingController endController = TextEditingController();
  final TextEditingController lengthController = TextEditingController();
  final TextEditingController finishDateController = TextEditingController();
  final TextEditingController managementIdController = TextEditingController();
  final TextEditingController coordinateLngController = TextEditingController();
  final TextEditingController coordinateLatController = TextEditingController();

  String? selectedDirection;

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

  // 根據城市名稱和鄉鎮名稱搜尋 TownID
  Future<int?> searchTownId(String cityName, String townName) async {
    try {
      final encodedCityName = Uri.encodeComponent(cityName);
      final encodedTownName = Uri.encodeComponent(townName);
      final response = await http.get(
          Uri.parse('$baseUrl/town/searchTownId?cityname=$encodedCityName&townname=$encodedTownName')
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result.isNotEmpty) {
          return result[0]['TownID'];
        }
      }
    } catch (e) {
      print('搜尋 TownID 錯誤: $e');
    }
    return null;
  }

  // 判斷座標點是否在指定的地區內
  Future<Map<String, String>?> getLocationFromCoordinates(double lat, double lng) async {
    try {
      final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1&accept-language=zh-TW';

      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Flutter App'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['address'] != null) {
          final address = data['address'];
          String? cityName;
          String? townName;

          // 提取城市和鄉鎮資訊
          if (address['city'] != null) {
            cityName = address['city'];
          } else if (address['county'] != null) {
            cityName = address['county'];
          } else if (address['state'] != null) {
            cityName = address['state'];
          }

          if (address['suburb'] != null) {
            townName = address['suburb'];
          } else if (address['town'] != null) {
            townName = address['town'];
          } else if (address['village'] != null) {
            townName = address['village'];
          }

          if (cityName != null && townName != null) {
            return {'cityName': cityName, 'townName': townName};
          }
        }
      }
    } catch (e) {
      print('取得地址錯誤: $e');
    }
    return null;
  }

  // 檢查新座標點是否已存在於路線分區列表中
  Future<void> checkAndAddRouteArea(double lat, double lng) async {
    final location = await getLocationFromCoordinates(lat, lng);
    if (location != null) {
      final cityName = location['cityName']!;
      final townName = location['townName']!;

      // 檢查是否已存在
      bool exists = routeAreas.any((area) =>
      area['cityName'] == cityName && area['townName'] == townName
      );

      if (!exists) {
        setState(() {
          routeAreas.add({'cityName': cityName, 'townName': townName});
        });
      }
    }
  }

  Future<int?> checkOrCreateManagement(String name) async {
    final encodedName = Uri.encodeComponent(name);
    final checkUrl = Uri.parse('$baseUrl/management?name=$encodedName');

    final checkRes = await http.get(checkUrl);

    if (checkRes.statusCode == 200) {
      final result = jsonDecode(checkRes.body);
      return result[0]['ManagementID'];
    }

    final createRes = await http.post(
      Uri.parse('$baseUrl/management/insertManagement'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'ManagementName': name}),
    );
    if (createRes.statusCode == 200) {
      final created = jsonDecode(createRes.body);
      return created['ManagementID'];
    }
    return null;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) {
    return deg * (pi / 180);
  }

  Future<String> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1&accept-language=zh-TW';

      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Flutter App'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['display_name'] != null) {
          String address = data['display_name'];

          if (data['address'] != null) {
            final addr = data['address'];
            List<String> addressParts = [];

            if (addr['suburb'] != null) addressParts.add(addr['suburb']);
            if (addr['road'] != null) addressParts.add(addr['road']);
            if (addr['house_number'] != null) addressParts.add(addr['house_number']);

            if (addressParts.isNotEmpty) {
              address = addressParts.join('');
            }
          }

          return address;
        }
      }
    } catch (e) {
      print('反向地理編碼錯誤: $e');
    }

    return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
  }

  double _calculateTotalLength() {
    if (coordinates.length < 2) return 0;

    double totalLength = 0;
    for (int i = 0; i < coordinates.length - 1; i++) {
      totalLength += _calculateDistance(
        coordinates[i][1],
        coordinates[i][0],
        coordinates[i + 1][1],
        coordinates[i + 1][0],
      );
    }
    return totalLength;
  }

  Future<void> _updateRouteInfo() async {
    if (coordinates.isNotEmpty) {
      setState(() {
        isLoadingAddress = true;
      });

      lengthController.text = _calculateTotalLength().round().toString();

      try {
        final startLat = coordinates.first[1];
        final startLng = coordinates.first[0];
        final startAddress = await _getAddressFromCoordinates(startLat, startLng);
        startController.text = startAddress;

        if (coordinates.length > 1) {
          final endLat = coordinates.last[1];
          final endLng = coordinates.last[0];
          final endAddress = await _getAddressFromCoordinates(endLat, endLng);
          endController.text = endAddress;
        } else {
          endController.text = startController.text;
        }
      } catch (e) {
        print('更新地址錯誤: $e');
      } finally {
        setState(() {
          isLoadingAddress = false;
        });
      }
    }
  }

  void _addCoordinate() async {
    final lng = double.tryParse(coordinateLngController.text);
    final lat = double.tryParse(coordinateLatController.text);
    if (lng != null && lat != null) {
      await checkAndAddRouteArea(lat, lng);
      setState(() {
        coordinates.add([lng, lat]);
        coordinateLngController.clear();
        coordinateLatController.clear();
      });
      _updateRouteInfo();
    }
  }

  void _addCoordinateFromMap(LatLng point) async {
    await checkAndAddRouteArea(point.latitude, point.longitude);
    setState(() {
      coordinates.add([point.longitude, point.latitude]);
    });
    _updateRouteInfo();
  }

  void _removeCoordinate(int index) {
    setState(() {
      coordinates.removeAt(index);
    });
    _updateRouteInfo();
  }

  void _clearCoordinates() {
    setState(() {
      coordinates.clear();
      routeAreas.clear();
      startController.clear();
      endController.clear();
      lengthController.clear();
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        finishDateController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Widget _cyclingrouteMarkers() {
    return MarkerLayer(
      markers: coordinates.asMap().entries.map((entry) {
        int index = entry.key;
        List<double> coord = entry.value;

        return Marker(
          point: LatLng(coord[1], coord[0]),
          width: 60,
          height: 60,
          child: GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('座標點 ${index + 1}'),
                  content: Text('經度: ${coord[0]}\n緯度: ${coord[1]}'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _removeCoordinate(index);
                      },
                      child: const Text('刪除', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
            child: Icon(
              Icons.location_on,
              color: index == 0 ? Colors.green : (index == coordinates.length - 1 ? Colors.red : Colors.blue),
              size: 30,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _cyclingroutePolylines() {
    if (coordinates.length < 2) return Container();

    return PolylineLayer(
      polylines: [
        Polyline(
          points: coordinates.map((coord) => LatLng(coord[1], coord[0])).toList(),
          color: Colors.blue,
          strokeWidth: 4.0,
        ),
      ],
    );
  }

  Widget _cyclingrouteMap() {
    return SizedBox(
      height: 300,
      child: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          onTap: isSimpleMode ? (tapPosition, point) {
            _addCoordinateFromMap(point);
          } : null,
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
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
            userAgentPackageName: 'com.example.app',
          ),
          _cyclingroutePolylines(),
          _cyclingrouteMarkers(),
        ],
      ),
    );
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
      });
      _updateRouteInfo();
    }
  }

  // 新增多筆路線資料 (支援跨區)
  Future<void> _submitInsert() async {
    if (routeAreas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請至少新增一個座標點')),
      );
      return;
    }

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

    // 將路線分區轉換為 TownID
    List<int?> townIds = [];
    for (final area in routeAreas) {
      final townId = await searchTownId(area['cityName']!, area['townName']!);
      townIds.add(townId);
    }

    // 為每個分區新增路線資料
    for (int i = 0; i < townIds.length; i++) {
      final townId = townIds[i];
      final body = {
        'TownID': townId,
        'Name': nameController.text,
        'AlternateNames': alternateNamesController.text,
        'Start': startController.text,
        'End': endController.text,
        'Length': double.tryParse(lengthController.text),
        'Direction': selectedDirection ?? '',
        'FinishDate': finishDateController.text,
        'ManagementID': managementID,
        'isChange': townId != null ? 1 : 0, // 根據 TownID 設置 isChange
      };

      final response = await http.post(
        Uri.parse('$baseUrl/cyclingroute/insertCyclingroute'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final res = jsonDecode(response.body);
        final insertedId = res['insertedId'];

        // 插入座標點資料 (只在第一筆資料時插入)
        if (i == 0) {
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
            }
          }
        }
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

  Future<void> _submitUpdate() async {
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

    // 更新時使用原本的 TownID (不跨區更新)
    final body = {
      'Name': nameController.text,
      'AlternateNames': alternateNamesController.text,
      'Start': startController.text,
      'End': endController.text,
      'Length': double.tryParse(lengthController.text),
      'Direction': selectedDirection ?? '',
      'FinishDate': finishDateController.text,
      'ManagementID': managementID,
    };

    final response = await http.put(
      Uri.parse('$baseUrl/cyclingroute/updateCyclingroute/$editingCRID'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    await _syncCoordinatesWithServer(editingCRID ?? 0);

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
  }

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
      selectedDirection = null;
      nameController.clear();
      alternateNamesController.clear();
      startController.clear();
      endController.clear();
      lengthController.clear();
      finishDateController.clear();
      managementIdController.clear();
      _clearCoordinates();
    });
  }

  void _confirmDelete(int crid) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('確認刪除'),
          content: Text('確定要刪除路線 $crid 嗎？'),
          actions: [
            TextButton(
              child: const Text('取消'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('刪除'),
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteCyclingroute(crid);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDirectionDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
      child: SizedBox(
        width: MediaQuery.of(context).size.width / 3,
        child: DropdownButtonFormField<String>(
          value: selectedDirection,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: '方向',
          ),
          items: const [
            DropdownMenuItem(value: '單向', child: Text('單向')),
            DropdownMenuItem(value: '雙向', child: Text('雙向')),
          ],
          onChanged: (String? value) {
            setState(() {
              selectedDirection = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isNumber = false, bool readOnly = false, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
      child: SizedBox(
        width: MediaQuery.of(context).size.width / 3,
        child: TextField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: label,
            suffixIcon: label.contains('日期') ? const Icon(Icons.calendar_today) : null,
          ),
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        ),
      ),
    );
  }

  Widget _simpleForm() {
    return Column(
      children: [
        const Divider(height: 32, thickness: 1),
        _buildTextField('路線名稱', nameController),
        _buildTextField('路線別名', alternateNamesController),
        _buildDirectionDropdown(),
        _buildTextField('完成日期', finishDateController, readOnly: true, onTap: _selectDate),
        _buildTextField('管理單位', managementIdController),

        const SizedBox(height: 16),
        const Text('點擊地圖添加路線座標點', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const Text('綠色標記為起點，紅色標記為終點', style: TextStyle(fontSize: 12, color: Colors.grey)),

        _cyclingrouteMap(),

        const SizedBox(height: 16),

        if (coordinates.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('已添加 ${coordinates.length} 個座標點'),
              if (isLoadingAddress) ...[
                const SizedBox(width: 10),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 5),
                const Text('載入地址中...', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // 顯示路線分區資訊
          if (routeAreas.isNotEmpty) ...[
            const Text('路線經過區域:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: routeAreas.map((area) => Chip(
                label: Text('${area['cityName']} ${area['townName']}'),
                backgroundColor: Colors.blue[100],
              )).toList(),
            ),
            const SizedBox(height: 8),
          ],

          if (startController.text.isNotEmpty) ...[
            Text('起點: ${startController.text}', style: const TextStyle(fontSize: 12, color: Colors.green)),
            const SizedBox(height: 4),
          ],
          if (endController.text.isNotEmpty) ...[
            Text('終點: ${endController.text}', style: const TextStyle(fontSize: 12, color: Colors.red)),
            const SizedBox(height: 4),
          ],
          if (lengthController.text.isNotEmpty) ...[
            Text('總長度: ${lengthController.text} 公尺', style: const TextStyle(fontSize: 12, color: Colors.blue)),
            const SizedBox(height: 8),
          ],
          ElevatedButton(
            onPressed: _clearCoordinates,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('清除所有座標'),
          ),
          const SizedBox(height: 16),
        ],

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

  Widget _detailedForm() {
    return Column(
      children: [
        const Divider(height: 32, thickness: 1),
        _buildTextField('路線名稱', nameController),
        _buildTextField('路線別名', alternateNamesController),
        _buildTextField('起點', startController),
        _buildTextField('終點', endController),
        _buildTextField('長度(公尺)', lengthController, isNumber: true),
        _buildDirectionDropdown(),
        _buildTextField('完成日期', finishDateController, readOnly: true, onTap: _selectDate),
        _buildTextField('管理單位', managementIdController),

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
              title: Text('${index + 1}. (${coord[0]}, ${coord[1]})'),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeCoordinate(index),
              ),
            );
          },
        ),

        // 顯示路線分區資訊
        if (routeAreas.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('路線經過區域:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: routeAreas.map((area) => Chip(
              label: Text('${area['cityName']} ${area['townName']}'),
              backgroundColor: Colors.blue[100],
            )).toList(),
          ),
          const SizedBox(height: 16),
        ],

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

  Widget _cyclingrouteForm() {
    return isSimpleMode ? _simpleForm() : _detailedForm();
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
                const SizedBox(width: 20),
                // 簡易/詳細模式切換按鈕
                if (isAdding) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ToggleButtons(
                      borderRadius: BorderRadius.circular(20),
                      isSelected: [isSimpleMode, !isSimpleMode],
                      onPressed: (index) {
                        setState(() {
                          isSimpleMode = index == 0;
                        });
                      },
                      constraints: const BoxConstraints(
                        minWidth: 60,
                        minHeight: 35,
                      ),
                      selectedColor: Colors.white,
                      fillColor: Colors.blue,
                      color: Colors.black,
                      children: const [
                        Text('簡易'),
                        Text('詳細'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                ],
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('新增'),
                  onPressed: () {
                    setState(() {
                      isAdding = true;
                      editingCRID = null;
                      selectedDirection = null;
                      nameController.clear();
                      alternateNamesController.clear();
                      startController.clear();
                      endController.clear();
                      lengthController.clear();
                      finishDateController.clear();
                      managementIdController.clear();
                      _clearCoordinates();
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
                                nameController.text = item['Name'] ?? '';
                                alternateNamesController.text = item['AlternateNames'] ?? '';
                                startController.text = item['Start'] ?? '';
                                endController.text = item['End'] ?? '';
                                lengthController.text = item['Length']?.toString() ?? '';
                                selectedDirection = item['Direction'] ?? '';
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