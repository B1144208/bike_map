import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';


class BookmarkPage extends StatefulWidget{
  const BookmarkPage({super.key});

  @override
  State<BookmarkPage>createState()=> _BookmarkPageState();
}

class _BookmarkPageState extends State<BookmarkPage>{

  List<dynamic> bookmark = [];

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
      setState((){
        bookmark = jsonDecode(response.body);
      });
      
      
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
              child: ListView.builder(
                itemCount: bookmark.length,
                itemBuilder: (context, index) {
                  final item = bookmark[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Card(
                      elevation: 2,
                      child: ListTile(
                        leading: const Icon(Icons.bookmark),
                        title: Text(item['BMYBID'].toString() ?? ''),
                        subtitle: Text(item['YBID'].toString() ?? ''),
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