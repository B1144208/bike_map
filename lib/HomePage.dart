import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 連接頁面
import 'config.dart';
import 'LoginPage.dart';
import 'UserPage.dart';
import 'AdminPage.dart';

Future<bool> IsLogin() async {
  final prefs = await SharedPreferences.getInstance();
  final exists = prefs.getInt('UserID');
  if (exists != null) return true;
  return false;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<dynamic> cities = [];
  List<dynamic> towns = [];
  List<dynamic> youbikes = [];
  List<dynamic> cyclingroutesdata = [];
  List<Map<String, dynamic>> cyclingroutes = [];
  List<dynamic> bookmark = [];
  int? selectedCity;
  int? selectedTown;
  Set<int> highlightedYouBikeIds = {};
  bool isLoadingCities = true;
  bool isLoadingTowns = false;
  bool isLoadingYoubikes = false;
  bool isFavorited = false;
  bool showYoubike = true;
  int? selectedMarkerId; // YouBike 的選中標記 ID
  int? selectedCyclingRouteId; // CyclingRoute 的選中路線 ID

  // 新增：儲存當前選中路線的相關YouBike站點數量
  int currentRouteRelatedYouBikeCount = 0;

  // 分頁相關
  final int itemsPerPage = 20;
  int currentPage = 0;

  // 搜尋關鍵字 - 新增這行
  final TextEditingController keywordController = TextEditingController();

  final mapController = MapController();

  // 取得當前頁面的項目
  List<dynamic> get currentPageItems {
    final items = showYoubike ? youbikes : cyclingroutesdata;
    final start = currentPage * itemsPerPage;
    final end = (start + itemsPerPage).clamp(0, items.length);
    return items.sublist(start, end);
  }

  // 取得總頁數
  int get totalPages {
    final items = showYoubike ? youbikes : cyclingroutesdata;
    return items.isEmpty ? 1 : ((items.length - 1) / itemsPerPage).floor() + 1;
  }

  Future<void> _checkManager() async {
    final prefs = await SharedPreferences.getInstance();
    final userID = prefs.getInt('UserID');

    if (userID != null) {
      final isManager = prefs.getInt('IsManager') ?? 0;
      if (isManager == 0) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminPage()),
        );
      });
    }
  }

  // 獲取 city 資料
  Future<void> fetchCities() async {
    final response = await http.get(Uri.parse('$baseUrl/city'));

    if (response.statusCode == 200) {
      setState(() {
        cities = jsonDecode(response.body);
        isLoadingCities = false;
      });
    } else {
      setState(() {
        isLoadingCities = false;
      });
      throw Exception('Failed to load cities');
    }
  }

  // 獲取 town 資料
  Future<void> fetchTowns() async {
    if (selectedCity == null) return;

    isLoadingTowns = true;

    final response = await http.get(
      Uri.parse('$baseUrl/town?cityid=$selectedCity'),
    );

    if (response.statusCode == 200) {
      setState(() {
        towns = jsonDecode(response.body);
        isLoadingTowns = false;
      });
    } else {
      setState(() {
        isLoadingTowns = false;
      });
      throw Exception('Failed to load towns');
    }
  }

  // 獲取 youbike 資料
  Future<void> fetchYoubikes() async {
    setState(() => isLoadingYoubikes = true);

    String url = '$baseUrl/youbike';
    final keyword = keywordController.text.trim();

    // 構建查詢參數
    List<String> queryParams = [];

    if (keyword.isNotEmpty) {
      url += '?keyword=$keyword';
    } else if (keyword.isNotEmpty) {
      queryParams.add('keyword=$keyword');
    } else {
      if (selectedTown != null) {
        queryParams.add('townid=$selectedTown');
      } else if (selectedCity != null) {
        queryParams.add('cityid=$selectedCity');
      }
    }

    if (queryParams.isNotEmpty) {
      url += '?${queryParams.join('&')}';
    }

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      setState(() {
        youbikes = jsonDecode(response.body);
        isLoadingYoubikes = false;
        currentPage = 0;
      });
    } else {
      setState(() {
        isLoadingYoubikes = false;
        throw Exception('Failed to load youbikes');
      });
    }
  }

  // 獲取 cyclingroute 資料
  Future<void> fetchCyclingRoutes() async {
    String url = '$baseUrl/cyclingroute';
    final keyword = keywordController.text.trim();

    // 構建查詢參數
    List<String> queryParams = [];

    if (keyword.isNotEmpty) {
      url += '?keyword=$keyword';
    } else if (selectedTown != null) {
      url += '?townid=$selectedTown';
    } else if (selectedCity != null) {
      url += '?cityid=$selectedCity';
    }

    if (queryParams.isNotEmpty) {
      url += '?${queryParams.join('&')}';
    }

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      cyclingroutesdata = jsonDecode(response.body);
      cyclingroutes.clear();

      for (final route in cyclingroutesdata) {
        final coordinates = route['Coordinates'];

        final latLngGroup = coordinates
            .map<LatLng>((point) => LatLng(point[1], point[0]))
            .toList();

        cyclingroutes.add({'data': route, 'latlng': latLngGroup});
      }

      setState(() {
        this.cyclingroutes = cyclingroutes;
        currentPage = 0;
      });
    } else {
      throw Exception('Failed to load cycling routes');
    }
  }

  // 修改：只在選擇城市後才載入資料
  Future<void> loadAllData() async {
    if (selectedCity != null || keywordController.text.trim().isNotEmpty) {
      setState(() {
        highlightedYouBikeIds.clear(); // 在載入新資料前清除高亮狀態
      });
      await fetchYoubikes();
      await fetchCyclingRoutes();
    }
  }

  Future<int> IsBookmarkExist(int BMID, bool IsYB) async {
    final prefs = await SharedPreferences.getInstance();
    final userID = prefs.getInt('UserID') ?? 0;

    String url;
    if (IsYB)
      url = '$baseUrl/bmyb?userid=$userID&ybid=$BMID';
    else
      url = '$baseUrl/bmcr?userid=$userID&crid=$BMID';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final bookmark = jsonDecode(response.body);
      if (bookmark.isEmpty) {
        return 0;
      } else if (IsYB) {
        return bookmark[0]['BMYBID'];
      } else {
        return bookmark[0]['BMCRID'];
      }
    } else {
      throw Exception('Failed to load bookmark');
    }
  }

  Future<bool> insertBookmark(int userID, int BMID, bool IsYB) async {
    String url;
    if (IsYB)
      url = '$baseUrl/bmyb/insertBMYB';
    else
      url = '$baseUrl/bmcr/insertBMCR';

    final Map<String, int> body = {
      'UserID': userID,
      IsYB ? 'YBID' : 'CRID': BMID,
    };

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 201) {
      return true;
    } else {
      try {
        final errorResponse = jsonDecode(response.body);
        print('Error: ${errorResponse['error']}');
      } catch (e) {
        print('Error: ${response.body}');
      }
      return false;
    }
  }

  Future<bool> removeBookmark(int userID, int BMID, bool IsYB) async {
    String url;
    if (IsYB)
      url = '$baseUrl/bmyb/deleteBMYB?userid=$userID&ybid=$BMID';
    else
      url = '$baseUrl/bmcr/deleteBMCR?userid=$userID&crid=$BMID';
    final response = await http.delete(Uri.parse(url));

    if (response.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  }

  Future<void> toggleFavorite(int BMID, bool IsYB) async {
    final prefs = await SharedPreferences.getInstance();
    final userID = prefs.getInt('UserID') ?? 0;

    int exists = await IsBookmarkExist(BMID, IsYB);
    if (exists == 0)
      isFavorited = false;
    else
      isFavorited = true;

    setState(() {
      isFavorited = !isFavorited;
      try {
        if (isFavorited) {
          insertBookmark(userID, BMID, IsYB);
        } else {
          removeBookmark(userID, BMID, IsYB);
        }
      } catch (e) {
        print('❌ 收藏操作失敗: $e');
      }
    });
  }

  // 新增：計算路線附近的YouBike站點
  Set<int> _calculateNearbyYouBikeStations(List<dynamic> coordinates) {
    Set<int> nearbyStations = {};

    // 走訪整條自行車道的所有點，找出 1km 內的 YouBike 站點
    for (final point in coordinates) {
      final pointLat = double.tryParse(point[1].toString());
      final pointLng = double.tryParse(point[0].toString());
      if (pointLat == null || pointLng == null) continue;

      for (final youbikePoint in youbikes) {
        final ybLat = double.tryParse(youbikePoint['Latitude'].toString());
        final ybLng = double.tryParse(youbikePoint['Longitude'].toString());
        if (ybLat == null || ybLng == null) continue;

        final distance = _calculateDistance(pointLat, pointLng, ybLat, ybLng);
        if (distance <= 1000) { // 1000 公尺內
          nearbyStations.add(int.parse(youbikePoint['YBID'].toString()));
        }
      }
    }

    return nearbyStations;
  }

  // 建立列表項目
  Widget _buildListItem(dynamic item) {
    if (showYoubike) {
      // YouBike 項目
      return Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        child: ListTile(
          leading: FutureBuilder<bool>(
            future: IsLogin(),
            builder: (context, snapshot) {
              final isLoggedIn = snapshot.data ?? false;
              if (!isLoggedIn) {
                return const Icon(Icons.location_on, color: Colors.red);
              }

              return FutureBuilder<int>(
                future: IsBookmarkExist(item['YBID'], true),
                builder: (context, bookmarkSnapshot) {
                  final isBookmarked = (bookmarkSnapshot.data ?? 0) != 0;
                  return GestureDetector(
                    onTap: () async {
                      if (isLoggedIn) {
                        await toggleFavorite(item['YBID'], true);
                      }
                    },
                    child: Icon(
                      isBookmarked ? Icons.favorite : Icons.favorite_border,
                      color: Colors.red,
                    ),
                  );
                },
              );
            },
          ),
          title: Text(item['Name'] ?? '未命名'),
          subtitle: Text('${item['CityName'] ?? ''} ${item['TownName'] ?? ''}'),
          onTap: () {
            // 點擊後在地圖上定位 YouBike 站點
            setState(() {
              selectedMarkerId = int.parse(item['YBID'].toString());
              final lat = double.tryParse(item['Latitude'].toString());
              final lng = double.tryParse(item['Longitude'].toString());
              if (lat != null && lng != null) {
                mapController.move(LatLng(lat, lng), 15.0);
              }
            });
          },
        ),
      );
    } else {
      // CyclingRoute 項目
      return Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        child: ListTile(
            leading: FutureBuilder<bool>(
              future: IsLogin(),
              builder: (context, snapshot) {
                final isLoggedIn = snapshot.data ?? false;
                if (!isLoggedIn) {
                  return const Icon(Icons.route, color: Colors.blue);
                }

                return FutureBuilder<int>(
                  future: IsBookmarkExist(item['CRID'], false),
                  builder: (context, bookmarkSnapshot) {
                    final isBookmarked = (bookmarkSnapshot.data ?? 0) != 0;
                    return GestureDetector(
                      onTap: () async {
                        if (isLoggedIn) {
                          await toggleFavorite(item['CRID'], false);
                        }
                      },
                      child: Icon(
                        isBookmarked ? Icons.favorite : Icons.favorite_border,
                        color: Colors.red,
                      ),
                    );
                  },
                );
              },
            ),
            title: Text(item['Name'] ?? '未命名'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item['CityName'] ?? ''} ${item['TownName'] ?? ''}'),
                if (item['Start'] != null) Text('起點: ${item['Start']}'),
                if (item['End'] != null) Text('終點: ${item['End']}'),
              ],
            ),
            isThreeLine: true,
            onTap: () {
              setState(() {
                selectedCyclingRouteId = item['CRID'];

                final coordinates = item['Coordinates'];
                if (coordinates != null && coordinates.isNotEmpty) {
                  // 先把地圖移動到起點
                  final startPoint = coordinates[0];
                  final lat = double.tryParse(startPoint[1].toString());
                  final lng = double.tryParse(startPoint[0].toString());
                  if (lat != null && lng != null) {
                    mapController.move(LatLng(lat, lng), 15.0);
                  }

                  // 計算附近的YouBike站點並更新高亮
                  final nearbyStations = _calculateNearbyYouBikeStations(coordinates);
                  highlightedYouBikeIds = nearbyStations;
                  currentRouteRelatedYouBikeCount = nearbyStations.length;
                }
              });
            }
        ),
      );
    }
  }

  // 畫面左側列表區域-上方控制區域
  Widget _leftControlLocal() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 切換按鈕取代標題 + 登入按鈕
          Row(
            children: [
              // 切換按鈕移到左側
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(30),
                ),
                child: ToggleButtons(
                  borderRadius: BorderRadius.circular(30),
                  isSelected: [showYoubike, !showYoubike],
                  onPressed: (index) {
                    setState(() {
                      showYoubike = index == 0;
                      currentPage = 0;
                      selectedMarkerId = null; // 切換時清除 YouBike 選擇狀態
                      selectedCyclingRouteId = null; // 切換時清除自行車道選擇狀態
                      highlightedYouBikeIds.clear(); // 清除高亮狀態
                      currentRouteRelatedYouBikeCount = 0; // 重置計數
                    });
                  },
                  constraints: const BoxConstraints(
                    minWidth: 50,
                    minHeight: 40,
                  ),
                  selectedColor: Colors.white,
                  fillColor: Colors.blue,
                  color: Colors.black,
                  children: const [
                    Icon(Icons.pedal_bike),
                    Icon(Icons.alt_route),
                  ],
                ),
              ),
              const Spacer(),
              // 登入按鈕保持在右側
              FutureBuilder(
                future: IsLogin(),
                builder: (context, snapshot) {
                  bool isLoggedIn = snapshot.data ?? false;

                  if (isLoggedIn) {
                    // 已登入：顯示頭像按鈕
                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const UserPage(),
                          ),
                        );
                      },
                      child: Container(
                        width: 35,
                        height: 35,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey,
                        ),
                        child: const Icon(
                          Icons.account_circle_rounded,
                          color: Colors.white,
                          size: 25,
                        ),
                      ),
                    );
                  } else {
                    // 未登入：顯示登入按鈕
                    return ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LoginPage(),
                          ),
                        );
                      },
                      child: const Text('登入'),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 地區選擇
          Row(
            children: [
              Expanded(
                child: DropdownButton<int>(
                  value: selectedCity,
                  hint: const Text('選擇城市'),
                  isExpanded: true,
                  onChanged: (int? newCityID) {
                    setState(() {
                      selectedCity = newCityID;
                      selectedTown = null;
                      fetchTowns();
                    });
                  },
                  items:
                  cities.map<DropdownMenuItem<int>>((city) {
                    return DropdownMenuItem<int>(
                      value: city['CityID'],
                      child: Text(city['CityName']),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButton<int>(
                  value: selectedTown,
                  hint: const Text('選擇鄉鎮'),
                  isExpanded: true,
                  onChanged: (int? newTownID) {
                    setState(() {
                      selectedTown = newTownID;
                    });
                  },
                  items: [
                    if (selectedCity != null)
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('全部鄉鎮'),
                      ),
                    ...towns.map<DropdownMenuItem<int>>((town) {
                      return DropdownMenuItem<int>(
                        value: town['TownID'],
                        child: Text(town['TownName']),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 關鍵字搜尋 - 新增的部分
          TextField(
            controller: keywordController,
            decoration: const InputDecoration(
              hintText: '輸入關鍵字搜尋',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 搜尋按鈕
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (selectedCity == null && keywordController.text.trim().isEmpty) || isLoadingYoubikes
                  ? null
                  : () async {
                setState(() {
                  currentPage = 0;
                  selectedCyclingRouteId = null; // ✅ 清除已選的路線
                  highlightedYouBikeIds.clear(); // 清除高亮狀態
                  currentRouteRelatedYouBikeCount = 0; // 重置計數
                });
                await loadAllData();
              },
              child:
              isLoadingYoubikes
                  ? const CircularProgressIndicator(
                strokeWidth: 2,
              )
                  : const Text('搜尋'),
            ),
          ),
        ],
      ),
    );
  }

  // 畫面左側列表區域-下方列表區域
  Widget _leftListLocal() {
    return Expanded(
      child:
      selectedCity == null &&
          keywordController.text.trim().isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '請選擇城市或輸入關鍵字搜尋',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      )
          : Column(
        children: [
          // 分頁資訊 - 移除類型提示文字
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
            ),
            child: Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '第 ${currentPage + 1} 頁 / 共 $totalPages 頁',
                ),
                Text(
                  '共 ${showYoubike ? youbikes.length : cyclingroutesdata.length} 筆',
                ),
              ],
            ),
          ),

          // 項目列表
          Expanded(
            child:
            currentPageItems.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: [
                  Icon(
                    showYoubike
                        ? Icons.pedal_bike
                        : Icons.route,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '無資料',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: currentPageItems.length,
              itemBuilder: (context, index) {
                final item =
                currentPageItems[index];
                return _buildListItem(item);
              },
            ),
          ),

          // 分頁按鈕
          if (currentPageItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed:
                    currentPage > 0
                        ? () => setState(
                          () => currentPage--,
                    )
                        : null,
                    child: const Text('上一頁'),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed:
                    currentPage < totalPages - 1
                        ? () => setState(
                          () => currentPage++,
                    )
                        : null,
                    child: const Text('下一頁'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // 畫面右側地圖區域-Youbike標記
  Widget _youbikeMarker() {
    return MarkerLayer(
      markers:
      youbikes.map<Marker>((youbikePoint) {
        final int currentYoubikeId = int.parse(youbikePoint['YBID'].toString()); // 獲取當前 YouBike 站點的 ID

        return Marker(
          point: LatLng(
            double.parse(youbikePoint['Latitude'].toString()),
            double.parse(
              youbikePoint['Longitude'].toString(),
            ),
          ),
          width: 60,
          height: 60,
          child: GestureDetector(
            onTap: () async {
              // **關鍵修改點 1：更新 selectedMarkerId 但不清除 highlightedYouBikeIds**
              // 點擊地圖上的 YouBike 站點時，將其設定為選中，但保持自行車道相關的高亮
              setState(() {
                selectedMarkerId = currentYoubikeId;
                // 移除這行：highlightedYouBikeIds.clear(); // 不再清除高亮狀態
              });

              // 原始的收藏邏輯和對話框顯示保持不變
              bool isLog = await IsLogin();
              bool locallsFavorited = false;

              if (isLog) {
                final BMYBID = await IsBookmarkExist(
                  int.parse(youbikePoint['YBID'].toString()),
                  true,
                );
                locallsFavorited = (BMYBID == 0) ? false : true;
              } else {
                locallsFavorited = false;
              }

              showDialog(
                context: context,
                builder: (context) {
                  return StatefulBuilder(
                    builder: (context, setStateDialog) {
                      return AlertDialog(
                        content: Text(
                          '城市 : ${youbikePoint['CityName']}\n'
                              '鄉鎮 : ${youbikePoint['TownName']}\n'
                              '站點 : ${youbikePoint['Name']}\n',
                        ),
                        actions: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  bool isLogInner = await IsLogin();
                                  if (isLogInner) {
                                    await toggleFavorite(
                                      youbikePoint['YBID'],
                                      true,
                                    );
                                    setStateDialog(() {
                                      locallsFavorited = !locallsFavorited;
                                    });
                                  } else {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          title: const Text('通知'),
                                          content: const Text('請先登入帳號再繼續'),
                                          actions: <Widget>[
                                            TextButton(
                                              child: const Text('取消'),
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                            ),
                                            TextButton(
                                              child: const Text('確定'),
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => LoginPage(),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  }
                                },
                                child: Icon(
                                  locallsFavorited
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: Colors.red,
                                  size: 40,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  // **關鍵修改點 2：在關閉對話框時清除 selectedMarkerId**
                                  // 這樣點擊的站點會恢復到其高亮或默認顏色
                                  setState(() {
                                    selectedMarkerId = null;
                                  });
                                },
                                child: const Text('關閉'),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
            child: Icon(
              Icons.location_pin,
              color: (selectedMarkerId != null && selectedMarkerId == int.parse(youbikePoint['YBID'].toString()))
                  ? Colors.green
                  : (highlightedYouBikeIds.contains(int.parse(youbikePoint['YBID'].toString())))
                  ? Colors.yellow // 高亮顏色（可自訂）
                  : Colors.red, // 一般顏色
              size: 30,
            ),
          ),
        );
      }).toList(),
    );
  }

  // 修改一個方法來顯示自行車道詳細資訊
  Future<void> _showCyclingRouteDetails(dynamic data) async {
    bool isLog = await IsLogin();
    bool locallsFavorited = false;

    if (isLog) {
      final BMCRID = await IsBookmarkExist(
        int.parse(data['CRID'].toString()),
        false,
      );
      locallsFavorited = (BMCRID == 0) ? false : true;
    } else {
      locallsFavorited = false;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              content: Text(
                '路線名稱: ${data['Name'] ?? '無資料'}\n'
                    '路線別名: ${data['AlternateNames'] ?? '無資料'}\n'
                    '起　　點: ${data['Start'] ?? '無資料'}\n'
                    '終　　點: ${data['End'] ?? '無資料'}\n'
                    '長　　度: ${data['Length'] ?? '無資料'} 公尺\n'
                    '完成日期: ${data['FinishDate'] ?? '無資料'}\n'
                    '管理單位: ${data['ManagementName'] ?? '無資料'}\n'
                    '相關YouBike站點數量: $currentRouteRelatedYouBikeCount\n', // 使用儲存的計數
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        bool isLogInner = await IsLogin();
                        if (isLogInner) {
                          await toggleFavorite(
                            data['CRID'],
                            false,
                          );
                          setStateDialog(() {
                            locallsFavorited = !locallsFavorited;
                          });
                        } else {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('通知'),
                                content: const Text('請先登入帳號再繼續'),
                                actions: <Widget>[
                                  TextButton(
                                    child: const Text('取消'),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                  TextButton(
                                    child: const Text('確定'),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => LoginPage(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        }
                      },
                      child: Icon(
                        locallsFavorited ? Icons.favorite : Icons.favorite_border,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        // 在對話框關閉時清除高亮狀態和選中的自行車道ID
                        setState(() {
                          highlightedYouBikeIds.clear(); // 清除高亮
                          selectedCyclingRouteId = null; // 清除選中的自行車道ID
                          currentRouteRelatedYouBikeCount = 0; // 重置計數
                        });
                      },
                      child: const Text('關閉'),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 修改：初始化時不載入資料
  @override
  void initState() {
    super.initState();
    fetchCities();
    _checkManager();
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000; // 地球半徑（公尺）
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return (R * c).toDouble(); // 強制轉型為 double
  }

  double _deg2rad(double deg) {
    return deg * (pi / 180);
  }

  // 計算點到線段的最短距離的輔助函數
  double _distanceToSegment(LatLng p, LatLng p1, LatLng p2) {
    double x = p.longitude;
    double y = p.latitude;
    double x1 = p1.longitude;
    double y1 = p1.latitude;
    double x2 = p2.longitude;
    double y2 = p2.latitude;

    double A = x - x1;
    double B = y - y1;
    double C = x2 - x1;
    double D = y2 - y1;

    double dot = A * C + B * D;
    double len_sq = C * C + D * D;
    double param = -1.0;
    if (len_sq != 0) {
      param = dot / len_sq;
    }

    double xx, yy;

    if (param < 0) {
      xx = x1;
      yy = y1;
    } else if (param > 1) {
      xx = x2;
      yy = y2;
    } else {
      xx = x1 + param * C;
      yy = y1 + param * D;
    }

    double dx = x - xx;
    double dy = y - yy;
    return (dx * dx + dy * dy); // 返回平方距離，比較時只需比較平方距離
  }

  // 計算點到多段線的最短距離
  double _distanceToPolyline(LatLng point, List<LatLng> polylinePoints) {
    if (polylinePoints.length < 2) return double.infinity; // 線段不足，距離無限大

    double minDistanceSq = double.infinity;
    for (int i = 0; i < polylinePoints.length - 1; i++) {
      double distSq = _distanceToSegment(point, polylinePoints[i], polylinePoints[i + 1]);
      if (distSq < minDistanceSq) {
        minDistanceSq = distSq;
      }
    }
    return minDistanceSq;
  }

  // 判斷點擊位置是否在自行車道附近，並顯示其詳細資訊
  void _handleMapTap(TapPosition tapPosition, LatLng latLng) {
    // 不再判斷 showYoubike，直接處理自行車道點擊
    if (cyclingroutes.isNotEmpty) {
      double minDistanceSq = double.infinity;
      Map<String, dynamic>? closestRoute;

      for (final routeItem in cyclingroutes) {
        final List<LatLng> latlngs = routeItem['latlng'];
        final data = routeItem['data'];

        double currentDistanceSq = _distanceToPolyline(latLng, latlngs);

        // 設定一個閾值，例如，點擊距離線路很近才算點中
        // 這裡的閾值需要根據地圖縮放級別和實際測試來調整
        // 0.000005 是一個很小的經緯度距離平方，您可能需要調整它來控制點擊靈敏度
        if (currentDistanceSq < minDistanceSq && currentDistanceSq < 0.000005) {
          minDistanceSq = currentDistanceSq;
          closestRoute = data;
        }
      }

      if (closestRoute != null) {
        // 計算並設定選中路線的相關YouBike站點
        final coordinates = closestRoute['Coordinates'];
        if (coordinates != null && coordinates.isNotEmpty) {
          final nearbyStations = _calculateNearbyYouBikeStations(coordinates);
          setState(() {
            selectedCyclingRouteId = int.parse(closestRoute!['CRID'].toString());
            highlightedYouBikeIds = nearbyStations;
            currentRouteRelatedYouBikeCount = nearbyStations.length;
          });
        }
        _showCyclingRouteDetails(closestRoute);
      } else {
        // 如果沒有點中任何自行車道，清除選中的自行車道ID
        setState(() {
          selectedCyclingRouteId = null;
          highlightedYouBikeIds.clear();
          currentRouteRelatedYouBikeCount = 0;
        });
      }
    }
    // YouBike 模式下點擊空白處取消選中標記的功能保留
    if (showYoubike) {
      setState(() {
        selectedMarkerId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // 畫面左側列表區域
          SizedBox(
            width: 400,
            child: Column(
              children: [
                // 上方控制區域
                _leftControlLocal(),

                const Divider(),

                // 下方列表區域
                _leftListLocal(),
              ],
            ),
          ),

          // 畫面右側地圖區域
          Expanded(
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCameraFit: CameraFit.bounds(
                  bounds: LatLngBounds(
                    const LatLng(21.8, 119.8),
                    const LatLng(25.3, 122.0),
                  ),
                  padding: const EdgeInsets.all(0),
                ),
                onTap: _handleMapTap, // 添加地圖點擊事件回調
              ),
              children: [
                TileLayer(
                  urlTemplate:
                  'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.example.app',
                ),

                // YouBike標記
                if (selectedCity != null || keywordController.text.trim().isNotEmpty)
                  _youbikeMarker(),

                // CyclingRoute 路線
                if (selectedCity != null || keywordController.text.trim().isNotEmpty)
                  PolylineLayer(
                    polylines: cyclingroutes
                        .where((routeData) {
                      // 如果有選取某條路線，只顯示那條；否則顯示所有
                      if (selectedCyclingRouteId != null) {
                        return routeData['data']['CRID'] == selectedCyclingRouteId;
                      }
                      return true; // 沒有選擇任何路線 → 顯示全部
                    })
                        .map((routeData) {
                      final routeItem = routeData['data'];
                      final List<LatLng> latlngs = routeData['latlng'];

                      final isSelected = selectedCyclingRouteId != null &&
                          routeItem['CRID'] == selectedCyclingRouteId;

                      return Polyline(
                        points: latlngs,
                        color: isSelected ? Colors.green : Colors.blue,
                        strokeWidth: 4.0,
                      );
                    })
                        .toList(),
                  )
              ],
            ),
          ),
        ],
      ),
    );
  }
}