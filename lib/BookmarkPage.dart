import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:project/UserPage.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';


Future<bool> insertBookmark(int BMID, bool IsYB) async {
  String url;
  final userID = await searchUserID();

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

Future<bool> removeBookmark(int BMID, bool IsYB) async {
  String url;
  final userID = await searchUserID();

  if(IsYB) url = 'http://localhost:3000/bmyb/deleteBMYB?userid=$userID&ybid=$BMID';
  else url = 'http://localhost:3000/bmcr/deleteBMCR?userid=$userID&crid=$BMID';
  final response = await http.delete(Uri.parse(url));
  
  if(response.statusCode == 200){
    return true;
  } else {
    return false;
  }
}
  

class BookmarkPage extends StatefulWidget{
  const BookmarkPage({super.key});

  @override
  State<BookmarkPage>createState()=> _BookmarkPageState();
}

class _BookmarkPageState extends State<BookmarkPage>{

  List<dynamic> BM_YB = [];
  List<dynamic> BM_CR = [];
  Set<int> favoritedYBIDs = {};
  Set<int> favoritedCRIDs = {};
  

  bool showYoubike = true;

  Future<int> searchUserID() async{
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('UserID') ?? 0;
  }


  Future<void> FetchBookmark(int userID, bool IsYB) async {
    String url;
    if(IsYB) url = 'http://localhost:3000/bmyb?userid=$userID';
    else url = 'http://localhost:3000/bmcr?userid=$userID';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      if(IsYB){
        setState((){
          BM_YB = jsonDecode(response.body);
          favoritedYBIDs = BM_YB.map<int>((e) => e['YBID'] as int).toSet();
        });
      }else{
        setState((){
          BM_CR = jsonDecode(response.body);
          favoritedCRIDs = BM_CR.map<int>((e) => e['CRID'] as int).toSet();
        });
      }
      
    } else {
      throw Exception('Failed to load bookmark');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadBookmark();
    
  }
  void _loadBookmark() async{
    FetchBookmark(await searchUserID(), true);
    FetchBookmark(await searchUserID(), false);
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的收藏'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Row(
              children: [
                (showYoubike)? Text('YouBike微笑單車'): Text('自行車道'),
                const Spacer(),
                Container(
                  // 定義容器外觀
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: ToggleButtons(
                    borderRadius: BorderRadius.circular(30),
                    isSelected: [showYoubike, !showYoubike],
                    onPressed: (index) {
                      setState(() {
                        showYoubike = index==0;
                        _loadBookmark();
                      });
                    },
                    constraints: const BoxConstraints(minWidth: 50, minHeight: 40),
                    selectedColor: Colors.white,
                    fillColor: Colors.blue,
                    color: Colors.black,
                    children: const [
                      Icon(Icons.pedal_bike), // YouBike
                      Icon(Icons.alt_route),  // CyclingRoute
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Scrollable content
            Expanded(
              
              child: 
              showYoubike
              ? ListView.builder(
                  itemCount: BM_YB.length,
                  itemBuilder: (context, index) {
                    final item = BM_YB[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Card(
                        elevation: 2,
                        child: ListTile(
                          leading:  GestureDetector(
                            onTap: () {
                              final ybid = item['YBID'];
                              setState(() {
                                if (favoritedYBIDs.contains(ybid)) {
                                  favoritedYBIDs.remove(ybid);
                                  removeBookmark(ybid, true);
                                } else {
                                  favoritedYBIDs.add(ybid);
                                  insertBookmark(ybid, true);
                                }
                              });
                            },
                            child: Icon(
                              favoritedYBIDs.contains(item['YBID']) ? Icons.bookmark : Icons.bookmark_border,
                              color: Colors.blue,
                            ),
                          ),

                          title: Text(item['Name'].toString()),
                          subtitle: 
                              Text('${item['CityName']}\t${item['TownName']}'),
                        ),
                      ),
                    );
                  },
                )
              : ListView.builder(
                  itemCount: BM_CR.length,
                  itemBuilder: (context, index) {
                    final item = BM_CR[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Card(
                        elevation: 2,
                        child: ListTile(
                          leading:  GestureDetector(
                            onTap: () {
                              final crid = item['CRID'];
                              setState(() {
                                if (favoritedCRIDs.contains(crid)) {
                                  favoritedCRIDs.remove(crid);
                                  removeBookmark(crid, false);
                                } else {
                                  favoritedCRIDs.add(crid);
                                  insertBookmark(crid, false);
                                }
                              });
                            },
                            child: Icon(
                              favoritedCRIDs.contains(item['CRID']) ? Icons.bookmark : Icons.bookmark_border,
                              color: Colors.blue,
                            ),
                          ),
                          /*leading: const Icon(Icons.bookmark),*/
                          title: Text(item['Name'].toString()),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${item['CityName']}\t${item['TownName']}'),
                              Text('路線別名: ${item['AlternateNames'] ?? '無資料'}'),
                              Text('起　　點: ${item['Start'] ?? '無資料'}'),
                              Text('終　　點: ${item['End'] ?? '無資料'}'),
                              Text('長　　度: ${item['Length'] ?? '無資料'}'),
                              Text('完成日期: ${item['FinishDate'] ?? '無資料'}'),
                              Text('管理單位: ${item['Management'] ?? '無資料'}'),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ),
            
          ],
        ),
      )
      
      
      

    );
  }
  
}