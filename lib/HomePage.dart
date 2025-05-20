import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 連接頁面
import 'LoginPage.dart';
import 'UserPage.dart';

Future<bool> IsLogin() async{
  final prefs = await SharedPreferences.getInstance();
  final exists = prefs.getInt('UserID');
  if(exists != null) 
    return true;
  return false;
}

class HomePage extends StatefulWidget{
  const HomePage({super.key});

  @override
  State<HomePage>createState()=> _HomePageState();
}

class _HomePageState extends State<HomePage>{
  List<dynamic> cities = [];                    // 儲存 city 資料
  List<dynamic> towns = [];                     // 儲存 town 資料
  List<dynamic> youbikes = [];                  // 儲存 youbike 資料
  List<dynamic> cyclingroutesdata = [];         // 儲存 cyclingroute 資料
  List<List<LatLng>> cyclingrouteslatlng = [];  // 儲存 cyclingroute latlng資料
  List<dynamic> bookmark = [];                  // 儲存 bookmark 資料
  int? selectedCity;                            // 儲存選擇的 cityID
  int? selectedTown;                            // 儲存選擇的 townID
  bool isLoadingCities = true;                  // 是否正在加載 city 資料
  bool isLoadingTowns = false;                  // 是否正在加載 town 資料
  bool isLoadingYoubikes = false;               // 是否正在加載 youbadike 資料
  bool isFavorited = false;                     // bookmark_暫存用

  final mapController = MapController();
  
  // 獲取 city 資料
  Future<void> fetchCities() async{
    final response = await http.get(Uri.parse('http://localhost:3000/city'));

    if(response.statusCode == 200){
      setState(() {
        cities = jsonDecode(response.body); // 解析回傳的JSON
        isLoadingCities = false; // 資料加載完成
      }); 
    }else{
      setState(() {
        isLoadingCities = false; // 資料加載完成，但發生錯誤
      });
      throw Exception('Failed to load cities');
    }
  }

  // 獲取 town 資料
  Future<void> fetchTowns() async{
    if (selectedCity == null) return;

    isLoadingTowns = true;

    final response = await http.get(Uri.parse('http://localhost:3000/town?cityid=$selectedCity'));

    if(response.statusCode == 200){
      setState(() {
        towns = jsonDecode(response.body); // 解析回傳的JSON
        isLoadingTowns = false; // 資料加載完成
      }); 
    }else{
      setState(() {
        isLoadingTowns = false; // 資料加載完成，但發生錯誤
      });
      throw Exception('Failed to load towns');
    }
  }

  // 獲取 youbike 資料
  Future<void> fetchYoubikes() async{

    if (selectedCity == null) return;

    String url;
    if (selectedTown == null){
      url = 'http://localhost:3000/youbike?cityid=$selectedCity';
    }else{
      url = 'http://localhost:3000/youbike?townid=$selectedTown';
    }
    final response = await http.get(Uri.parse(url));

    if(response.statusCode == 200){
      setState(() {
        youbikes = jsonDecode(response.body); // 解析回傳的JSON
        isLoadingYoubikes = false; // 資料加載完成
      }); 
    }else{
      setState(() {
        isLoadingYoubikes = false; // 資料加載完成，但發生錯誤
        throw Exception('Failed to load youbikes');
      });
    }
  }

  // 獲取 cyclingroute 資料
  Future<void> fetchCyclingRoutes() async {
    if (selectedCity == null) return;

    String url;
    if (selectedTown == null){
      url = 'http://localhost:3000/cyclingroute?cityid=$selectedCity';
    }else{
      url = 'http://localhost:3000/cyclingroute?townid=$selectedTown';
    }
    final response = await http.get(Uri.parse(url));


    if (response.statusCode == 200) {
      cyclingroutesdata = jsonDecode(response.body);
      final List<List<LatLng>> parsedRoutes = [];

      for (final route in cyclingroutesdata) {
        final geometryStr = route['Geometry'];
        final geometry = jsonDecode(geometryStr); // decode GeoJSON string
        final List coordinatesGroups = geometry['coordinates'];

        for (final group in coordinatesGroups) {
          final List<LatLng> latLngGroup = group.map<LatLng>((point) {
            return LatLng(point[1], point[0]); // [lon, lat] → LatLng(lat, lon)
          }).toList();

          parsedRoutes.add(latLngGroup);
        }
      }

      setState(() {
        cyclingrouteslatlng = parsedRoutes;
      });
    } else {
      throw Exception('Failed to load cycling routes');
    }
  }

  Future<int> IsBookmarkExist(int BMID, bool IsYB) async {
    final prefs = await SharedPreferences.getInstance();
    final userID = prefs.getInt('UserID') ?? 0;

    String url;
    if(IsYB) url = 'http://localhost:3000/bmyb?userid=$userID&ybid=$BMID';
    else url = 'http://localhost:3000/bmcr?userid=$userID&crid=$BMID';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final bookmark = jsonDecode(response.body);
      if (bookmark.isEmpty) {
        return 0;
      } else if(IsYB) {
        return bookmark[0]['BMYBID'];
      }else {
        return bookmark[0]['BMCRID'];
      }
    } else {
      throw Exception('Failed to load bookmark');
    }
  }

  Future<bool> insertBookmark(int userID, int BMID, bool IsYB) async {
    String url;
    if(IsYB) url = 'http://localhost:3000/bmyb/insertBMYB';
    else url = 'http://localhost:3000/bmcr/insertBMCR';

    // Prepare the request body as a Map
    final Map<String, int> body = {
      'UserID': userID,
      IsYB ? 'YBID' : 'CRID': BMID,
    };

    // Make the HTTP POST request
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json', // Set the content type to JSON
      },
      body: jsonEncode(body), // Convert the Map to JSON
    );

    // Check the response status
    if(response.statusCode == 201){
      // Successfully added bookmark
      return true;
    }else{
      // Failed to add bookmark
      
      // 嘗試解析回應內容，如果不是有效的 JSON，顯示錯誤訊息
      try {
        final errorResponse = jsonDecode(response.body);
        print('Error: ${errorResponse['error']}');
      } catch (e) {
        // 如果回應不是有效的 JSON，顯示純文本錯誤
        print('Error: ${response.body}');
      }
      return false;
    }
  }

  Future<bool> removeBookmark(int userID, int BMID, bool IsYB) async {
    String url;
    if(IsYB) url = 'http://localhost:3000/bmyb/deleteBMYB?userid=$userID&ybid=$BMID';
    else url = 'http://localhost:3000/bmcr/deleteBMCR?userid=$userID&crid=$BMID';
    final response = await http.delete(Uri.parse(url));

    if(response.statusCode == 200){
      print('Bookmark deleted successfully');
      return true;
    } else {
      print('Failed to delete Bookmark: ${response.body}');
      return false;
    }
  }
  
  Future<void> toggleFavorite(int BMID, bool IsYB) async {
    final prefs = await SharedPreferences.getInstance();
    final userID = prefs.getInt('UserID') ?? 0;

    int exists = await IsBookmarkExist(BMID, IsYB);
    if(exists==0) isFavorited = false;
    else isFavorited = true;

    setState(() {
      isFavorited = !isFavorited;
      try {
        if (isFavorited) {
          // TODO: 加入資料庫
          insertBookmark(userID, BMID, IsYB);
          print('已加入收藏');
        } else {
          // TODO: 移除收藏紀錄
          removeBookmark(userID, BMID, IsYB);
          print('取消收藏');
        }
      }catch (e){
        print('❌ 收藏操作失敗: $e');
      }
    });
  }

  // 初始化
  @override
  void initState() {
    super.initState();
    fetchCities();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: const Text('自行車趴趴走')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column( // 垂直排列其他 UI 元件的容器
          mainAxisAlignment: MainAxisAlignment.start, // 內容在垂直方向上居中對齊
          children: <Widget> [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget> [

                // 個人帳號，放置在左側
                FutureBuilder(
                  future: IsLogin(),
                  builder:(context, snapshot) {
                    bool isLoggedIn = snapshot.data ?? false;
                    return InkWell(
                      onTap: (){
                        if(isLoggedIn){
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => UserPage()),
                          );
                        }else{
                          // 跳出提示框要求登入
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('通知'),
                                content: const Text('請先登入帳號再繼續'),
                                actions: <Widget>[
                                  TextButton(
                                    child: const Text('取消'),
                                    onPressed: (){
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                  TextButton(
                                    child: const Text('確定'),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => LoginPage()),
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        }
                      },
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).scaffoldBackgroundColor,
                        ),
                        child: Icon(
                          isLoggedIn ? Icons.account_circle_rounded : Icons.account_circle_outlined,
                          color: Colors.black,
                          size: 40,
                        ),
                      ),
                      
                    );
                  },
                ),

                const Spacer(),

                // city 選擇器 (下拉選單)
                DropdownButton<int>(
                  value: selectedCity,
                  hint: const Text('選擇城市'), onChanged: (int? newCityID){
                    setState(() {
                      selectedCity = newCityID;
                      selectedTown = null;
                      fetchTowns();
                    });
                  },
                  items: cities.map<DropdownMenuItem<int>>((city){
                    return DropdownMenuItem<int>(
                      value: city['CityID'],          // 使用 CityID   作為值
                      child: Text(city['CityName']),  // 顯示 CityName 作為選項
                    );
                  }).toList(),
                ),
              
                const SizedBox(width: 30),

                // town 選擇器 (下拉選單)
                DropdownButton<int>(
                  value: selectedTown,
                  hint: const Text('選擇鄉鎮'), onChanged: (int? newTownID){
                    setState(() {
                      selectedTown = newTownID;
                    });
                  },
                  items: [
                    if(selectedCity != null)
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('選擇鄉鎮'),
                      ),
                    ...towns.map<DropdownMenuItem<int>>((town){
                      return DropdownMenuItem<int>(
                        value: town['TownID'],
                        child: Text(town['TownName']),
                      );
                    }),
                  ],
                ),

                const SizedBox(width: 30),

                // 搜尋
                ElevatedButton(
                  onPressed: () async {
                    if (selectedCity == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('請先選擇城市')),
                      );
                      return;
                    }
                    setState(() {
                      isLoadingYoubikes = true;
                    });
                    await fetchYoubikes();
                    await fetchCyclingRoutes();
                  },
                  child: const Text('搜尋')
                ),
                
                const Spacer(),  // 用來推動登入按鈕到右側

                // 登入按鈕，放置在右側
                ElevatedButton(
                  onPressed: () {
                    // 這裡可以放登入頁面的跳轉邏輯
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LoginPage()),
                    );
                  },
                  child: const Text('登入'),
                ),
              ],
            ),

            // 地圖渲染
            Expanded(
              // youbike渲染
              child: isLoadingYoubikes
                ? const Center(child: CircularProgressIndicator())
                : FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      initialCameraFit: CameraFit.bounds(
                        bounds: LatLngBounds(
                          const LatLng(21.8, 119.8),
                          const LatLng(25.3, 122.0),
                        ),
                        padding: EdgeInsets.all(0),
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: ['a', 'b', 'c'],
                        userAgentPackageName: 'com.example.app',
                      ),

                      // 將 youbikes 的 MarkerLayer 放在 cyclingrouteslatlng 上方
                      MarkerLayer(
                        markers: youbikes.map<Marker>((youbikePoint) {
                          return Marker(
                            point: LatLng(
                              double.parse(youbikePoint['Latitude'].toString()),
                              double.parse(youbikePoint['Longitude'].toString()),
                            ),
                            width: 60,
                            height: 60,
                            child: GestureDetector(
                              onTap: () async {
                                bool isLog = await IsLogin();
                                bool locallsFavorited = false;

                                if (isLog) {
                                  final BMYBID = await IsBookmarkExist(int.parse(youbikePoint['YBID'].toString()), true);
                                  locallsFavorited = (BMYBID==0)? false: true;
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
                                                      await toggleFavorite(youbikePoint['YBID'], true);
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
                                                                onPressed: (){
                                                                  Navigator.of(context).pop();
                                                                },
                                                              ),
                                                              TextButton(
                                                                child: const Text('確定'),
                                                                onPressed: () {
                                                                  Navigator.of(context).pop();
                                                                  Navigator.push(
                                                                    context,
                                                                    MaterialPageRoute(builder: (context) => LoginPage()),
                                                                  );
                                                                },
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      );
                                                      /*Navigator.of(context).pop();
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(builder: (context) => LoginPage()),
                                                      );*/
                                                    }
                                                  },
                                                  child: Image.asset(
                                                    locallsFavorited
                                                        ? 'assets/images/heart_filled.png'
                                                        : 'assets/images/heart_outlined.png',
                                                    width: 40,
                                                    height: 40,
                                                  ),
                                                ),
                                                const Spacer(),
                                                TextButton(
                                                  onPressed: () => Navigator.of(context).pop(),
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
                              child: const Icon(
                                Icons.location_pin,
                                color: Colors.red,
                                size: 30,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      
                      // cyclingroute 的起始點
                      MarkerLayer(
                        markers: cyclingrouteslatlng.asMap().map((routeIndex, route) {
                          return MapEntry(
                            routeIndex,
                            [
                              Marker(
                                point: route[0],  // 只用第一個 LatLng 點
                                width: 60,
                                height: 60,
                                child: GestureDetector(
                                  onTap: () async {
                                    bool isLog = await IsLogin();
                                    bool locallsFavorited = false;

                                    if (isLog) {
                                      final BMCRID = await IsBookmarkExist(int.parse(cyclingroutesdata[routeIndex]['CRID'].toString()), false);
                                      locallsFavorited = (BMCRID==0)? false: true;
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
                                                '路線名稱: ${cyclingroutesdata[routeIndex]['Name'] ?? '無資料'}\n'
                                                '路線別名: ${cyclingroutesdata[routeIndex]['AlternateNames'] ?? '無資料'}\n'
                                                '起　　點: ${cyclingroutesdata[routeIndex]['Start'] ?? '無資料'}\n'
                                                '終　　點: ${cyclingroutesdata[routeIndex]['End'] ?? '無資料'}\n'
                                                '長　　度: ${cyclingroutesdata[routeIndex]['Length'] ?? '無資料'} 公尺\n'
                                                '完成日期: ${cyclingroutesdata[routeIndex]['FinishDate'] ?? '無資料'}\n'
                                                '管理單位: ${cyclingroutesdata[routeIndex]['Management'] ?? '無資料'}\n'
                                              ),
                                              actions: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.start,
                                                  children: [
                                                    GestureDetector(
                                                      onTap: () async {
                                                        bool isLogInner = await IsLogin();
                                                        if (isLogInner) {
                                                          await toggleFavorite(cyclingroutesdata[routeIndex]['CRID'], false);
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
                                                                    onPressed: (){
                                                                      Navigator.of(context).pop();
                                                                    },
                                                                  ),
                                                                  TextButton(
                                                                    child: const Text('確定'),
                                                                    onPressed: () {
                                                                      Navigator.of(context).pop();
                                                                      Navigator.push(
                                                                        context,
                                                                        MaterialPageRoute(builder: (context) => LoginPage()),
                                                                      );
                                                                    },
                                                                  ),
                                                                ],
                                                              );
                                                            },
                                                          );
                                                          /*Navigator.of(context).pop();
                                                          Navigator.push(
                                                            context,
                                                            MaterialPageRoute(builder: (context) => LoginPage()),
                                                          );*/
                                                        }
                                                      },
                                                      child: Image.asset(
                                                        locallsFavorited
                                                            ? 'assets/images/heart_filled.png'
                                                            : 'assets/images/heart_outlined.png',
                                                        width: 40,
                                                        height: 40,
                                                      ),
                                                    ),
                                                    const Spacer(),
                                                    TextButton(
                                                      onPressed: () => Navigator.of(context).pop(),
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
                                  child: Opacity(
                                    opacity: 1.0, // 完全透明
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.blue,
                                      size: 30,
                                    ),
                                  ),
                                ),
                              )
                            ],
                          );
                        }).values.expand((element) => element).toList(),
                      ),
                      // 全部的 cyclingroute 點
                      /*MarkerLayer(
                        markers: cyclingrouteslatlng.asMap().map((routeIndex, route) {
                          return MapEntry(
                            routeIndex,
                            route.map<Marker>((latLng) {
                              return Marker(
                                point: latLng,  // 每个 LatLng 点
                                width: 60,
                                height: 60,
                                child: GestureDetector(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) => AlertDialog(
                                        title: Text("路線詳細資料"),
                                        content: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('路線名稱: ${cyclingroutesdata[routeIndex]['Name']}'),
                                            Text('起點: ${cyclingroutesdata[routeIndex]['Start']}'),
                                            Text('終點: ${cyclingroutesdata[routeIndex]['End']}'),
                                            Text('長度: ${cyclingroutesdata[routeIndex]['Length']} 公尺'),
                                            Text('完成日期: ${cyclingroutesdata[routeIndex]['FinishDate']}'),
                                            Text('管理單位: ${cyclingroutesdata[routeIndex]['Management']}'),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                            child: Text("關閉"),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  child: Opacity(
                                    opacity: 0.0, // 設置透明度為 0，完全透明
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.blue,
                                      size: 30,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        }).values.expand((element) => element).toList(),
                      ),*/

                      PolylineLayer(
                        polylines:
                          cyclingrouteslatlng.asMap().map((index, route){
                            return MapEntry(
                              index,
                              Polyline(
                                points: route,
                                strokeWidth: 4,
                                color: Colors.blue,
                                
                              ),
                            );
                          }).values.toList(),
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