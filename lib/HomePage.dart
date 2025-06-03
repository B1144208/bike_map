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

//第2段

class _HomePageState extends State<HomePage> {
  List<dynamic> cities = [];
  List<dynamic> towns = [];
  List<dynamic> youbikes = [];
  List<dynamic> cyclingroutesdata = [];
  List<Map<String, dynamic>> cyclingroutes = [];
  List<dynamic> bookmark = [];
  int? selectedCity;
  int? selectedTown;
  bool isLoadingCities = true;
  bool isLoadingTowns = false;
  bool isLoadingYoubikes = false;
  bool isFavorited = false;
  bool showYoubike = true;
  int? selectedMarkerId;


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

  //第3段

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

  //第4段

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
        final geometryStr = route['Geometry'];
        final geometry = jsonDecode(geometryStr);
        final coordinatesGroups = geometry['coordinates'];

        for (final group in coordinatesGroups) {
          final latLngGroup =
              group.map<LatLng>((point) => LatLng(point[1], point[0])).toList();

          cyclingroutes.add({'data': route, 'latlng': latLngGroup});
        }
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
      await fetchYoubikes();
      await fetchCyclingRoutes();
    }
  }

  //第5段

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

  //第6段

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
                return Icon(Icons.location_on, color: Colors.red);
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
            // 點擊後在地圖上定位
            setState(() {
              selectedMarkerId = int.parse(item['YBID'].toString());
              // 並定位地圖
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
                return Icon(Icons.route, color: Colors.blue);
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
        ),
      );
    }
  }

  // 修改：初始化時不載入資料
  @override
  void initState() {
    super.initState();
    fetchCities();
    // 移除 loadAllData() - 只在選擇城市後才載入
    _checkManager();
  }

  //第7段

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // 左側列表區域
          SizedBox(
            width: 400,
            child: Column(
              children: [
                // 上方控制區域
                Container(
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
                                });
                              },
                              constraints: const BoxConstraints(
                                minWidth: 50,
                                minHeight: 40,
                              ),
                              selectedColor: Colors.white,
                              fillColor: Colors.blue,
                              color: Colors.black,
                              children: [
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
                                        builder: (context) => UserPage(),
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
                                    child: Icon(
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
                        /*onChanged: (value) {
                          // 可以在這裡添加即時搜尋功能，如果需要的話
                        },*/
                      ),
                      const SizedBox(height: 10),

                      // 搜尋按鈕
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                              (selectedCity == null &&
                                          keywordController.text
                                              .trim()
                                              .isEmpty) ||
                                      isLoadingYoubikes
                                  ? null
                                  : () async {
                                    setState(() => currentPage = 0);
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
                ),

                const Divider(),

                //第8段

                // 列表區域
                Expanded(
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
                ),
              ],
            ),
          ),

          //第9段

          // 右側地圖區域
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
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.example.app',
                ),

                //第10段

                // YouBike 標記 - 只在選擇城市或有關鍵字後顯示
                if (selectedCity != null ||
                    keywordController.text.trim().isNotEmpty)
                  MarkerLayer(
                    markers:
                        youbikes.map<Marker>((youbikePoint) {
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
                                bool isLog = await IsLogin();
                                bool locallsFavorited = false;

                                if (isLog) {
                                  final BMYBID = await IsBookmarkExist(
                                    int.parse(youbikePoint['YBID'].toString()),
                                    true,
                                  );
                                  locallsFavorited =
                                      (BMYBID == 0) ? false : true;
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
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              children: [
                                                GestureDetector(
                                                  onTap: () async {
                                                    bool isLogInner =
                                                        await IsLogin();
                                                    if (isLogInner) {
                                                      await toggleFavorite(
                                                        youbikePoint['YBID'],
                                                        true,
                                                      );
                                                      setStateDialog(() {
                                                        locallsFavorited =
                                                            !locallsFavorited;
                                                      });
                                                    } else {
                                                      showDialog(
                                                        context: context,
                                                        builder: (
                                                          BuildContext context,
                                                        ) {
                                                          return AlertDialog(
                                                            title: const Text(
                                                              '通知',
                                                            ),
                                                            content: const Text(
                                                              '請先登入帳號再繼續',
                                                            ),
                                                            actions: <Widget>[
                                                              TextButton(
                                                                child:
                                                                    const Text(
                                                                      '取消',
                                                                    ),
                                                                onPressed: () {
                                                                  Navigator.of(
                                                                    context,
                                                                  ).pop();
                                                                },
                                                              ),
                                                              TextButton(
                                                                child:
                                                                    const Text(
                                                                      '確定',
                                                                    ),
                                                                onPressed: () {
                                                                  Navigator.of(
                                                                    context,
                                                                  ).pop();
                                                                  Navigator.push(
                                                                    context,
                                                                    MaterialPageRoute(
                                                                      builder:
                                                                          (
                                                                            context,
                                                                          ) =>
                                                                              LoginPage(),
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
                                                  onPressed:
                                                      () =>
                                                          Navigator.of(
                                                            context,
                                                          ).pop(),
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
                                    ? Colors.yellow  // 被選中的 Marker 顏色
                                    : Colors.red,  // 預設顏色
                                size: 30,
                              ),

                            ),
                          );
                        }).toList(),
                  ),

                //第11段

                // CyclingRoute 起始點標記 - 只在選擇城市或有關鍵字後顯示
                if (selectedCity != null ||
                    keywordController.text.trim().isNotEmpty)
                  MarkerLayer(
                    markers:
                        cyclingroutes.map((routeItem) {
                          final data = routeItem['data'];
                          final latlng = routeItem['latlng'];

                          return Marker(
                            point: latlng[0],
                            width: 60,
                            height: 60,
                            child: GestureDetector(
                              onTap: () async {
                                bool isLog = await IsLogin();
                                bool locallsFavorited = false;

                                if (isLog) {
                                  final BMCRID = await IsBookmarkExist(
                                    int.parse(data['CRID'].toString()),
                                    false,
                                  );
                                  locallsFavorited =
                                      (BMCRID == 0) ? false : true;
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
                                            '管理單位: ${data['ManagementName'] ?? '無資料'}\n',
                                          ),
                                          actions: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              children: [
                                                GestureDetector(
                                                  onTap: () async {
                                                    bool isLogInner =
                                                        await IsLogin();
                                                    if (isLogInner) {
                                                      await toggleFavorite(
                                                        data['CRID'],
                                                        false,
                                                      );
                                                      setStateDialog(() {
                                                        locallsFavorited =
                                                            !locallsFavorited;
                                                      });
                                                    } else {
                                                      showDialog(
                                                        context: context,
                                                        builder: (
                                                          BuildContext context,
                                                        ) {
                                                          return AlertDialog(
                                                            title: const Text(
                                                              '通知',
                                                            ),
                                                            content: const Text(
                                                              '請先登入帳號再繼續',
                                                            ),
                                                            actions: <Widget>[
                                                              TextButton(
                                                                child:
                                                                    const Text(
                                                                      '取消',
                                                                    ),
                                                                onPressed: () {
                                                                  Navigator.of(
                                                                    context,
                                                                  ).pop();
                                                                },
                                                              ),
                                                              TextButton(
                                                                child:
                                                                    const Text(
                                                                      '確定',
                                                                    ),
                                                                onPressed: () {
                                                                  Navigator.of(
                                                                    context,
                                                                  ).pop();
                                                                  Navigator.push(
                                                                    context,
                                                                    MaterialPageRoute(
                                                                      builder:
                                                                          (
                                                                            context,
                                                                          ) =>
                                                                              LoginPage(),
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
                                                  onPressed:
                                                      () =>
                                                          Navigator.of(
                                                            context,
                                                          ).pop(),
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
                              // 修復：使用和紅色圖標完全相同的結構，只改顏色
                              child: const Icon(
                                Icons.location_pin,
                                color: Colors.blue,
                                size: 30,
                              ),
                            ),
                          );
                        }).toList(),
                  ),

                // CyclingRoute 路線 - 只在選擇城市或有關鍵字後顯示
                if (selectedCity != null ||
                    keywordController.text.trim().isNotEmpty)
                  PolylineLayer(
                    polylines:
                        cyclingroutes.map<Polyline>((route) {
                          return Polyline(
                            points: route['latlng'],
                            strokeWidth: 4,
                            color: Colors.blue,
                          );
                        }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
