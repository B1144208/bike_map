import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


//連接頁面
import 'config.dart';

class ManageYoubikePage extends StatefulWidget {
  const ManageYoubikePage({super.key});

  @override
  State<ManageYoubikePage> createState() => _ManagerYoubikeState();
}



class _ManagerYoubikeState extends State<ManageYoubikePage> {
  List<dynamic> cities = [];                    // 儲存 city 資料
  List<dynamic> towns = [];                     // 儲存 town 資料
  List<dynamic> youbikes = [];
  int? selectedCity;                            // 儲存選擇的 cityID
  int? selectedTown;                            // 儲存選擇的 townID
  bool isLoadingCities = true;                  // 是否正在加載 city 資料
  bool isLoadingTowns = false;                  // 是否正在加載 town 資料
  bool isLoadingYoubikes = true;                // 是否正在加載 youbike 資料
  

  @override
  void initState() {
    super.initState();
    fetchCities();
    fetchYoubikes();
  }

  // 獲取 youbike 資料
  Future<void> fetchYoubikes() async {
    String url;

    if (selectedCity == null) {
      url = '$baseUrl/youbike'; // 沒有指定 city，撈全部
    } else if (selectedTown == null) {
      url = '$baseUrl/youbike?cityid=$selectedCity';
    } else {
      url = '$baseUrl/youbike?townid=$selectedTown';
    }

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      setState(() {
        youbikes = jsonDecode(response.body);
        isLoadingYoubikes = false;
      });
    } else {
      setState(() {
        isLoadingYoubikes = false;
      });
      throw Exception('Failed to load youbikes');
    }
  }

  // 獲取 city 資料
  Future<void> fetchCities() async{
    final response = await http.get(Uri.parse('$baseUrl/city'));

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

    final response = await http.get(Uri.parse('$baseUrl/town?cityid=$selectedCity'));

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理 YouBike'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column( // 垂直排列其他 UI 元件的容器
          mainAxisAlignment: MainAxisAlignment.start, // 內容在垂直方向上居中對齊
          children: <Widget> [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget> [
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
                  },
                  child: const Text('搜尋')
                ),
                
              ]
            ),
            Expanded(
              child: isLoadingYoubikes
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: youbikes.length,
                  itemBuilder: (context, index) {
                    final item = youbikes[index];
                    return ListTile(
                      title: Text(item['Name'] ?? '未命名'),
                      subtitle: Text(
                        '經度: ${item['Longitude']}、緯度: ${item['Latitude']}',
                      ),
                    );
                  },
                ),
            ),
          ]
        )
      )
    );
  }
}