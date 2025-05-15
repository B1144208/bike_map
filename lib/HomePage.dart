import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// 連接頁面
import 'LoginPage.dart';
import 'UserPage.dart';
import 'LoginPage.dart';

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
  int? selectedCity;                            // 儲存選擇的 cityID
  int? selectedTown;                            // 儲存選擇的 townID
  bool isLoadingCities = true;                  // 是否正在加載 city 資料
  bool isLoadingTowns = false;                  // 是否正在加載 town 資料
  bool isLoadingYoubikes = false;               // 是否正在加載 youbike 資料

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
        print('✅ youbikes 資料 加載完成');
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

                // 收藏按鈕，放置在左側
                InkWell(
                  onTap: (){
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => UserPage()),
                    );
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: AssetImage('assets/images/user_icon.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
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
                    }).toList(),
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
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    content: Text(
                                      '城市 : ${youbikePoint['CityName']}\n'
                                      '鄉鎮 : ${youbikePoint['TownName']}\n'
                                      '站點 : ${youbikePoint['Name']}\n'
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(),
                                        child: const Text('關閉'),
                                      )
                                    ]
                                  ),
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

                      MarkerLayer(
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
                      ),

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