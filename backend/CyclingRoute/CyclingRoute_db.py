import mysql.connector
import json

def get_city_id(city_name, cursor, connection):
    # 查詢 city 是否存在
    cursor.execute("SELECT CityID FROM city WHERE CityName = %s", (city_name,))
    result = cursor.fetchone()
    
    if result:
        # 如果 city 存在，返回 CityID
        return result[0]
    else:
        # 如果 city 不存在，插入 city 並返回新的 CityID
        cursor.execute("INSERT INTO city (CityName) VALUES (%s)", (city_name,))
        connection.commit()  # 提交新增操作
        # 獲取新插入的 CityID
        cursor.execute("SELECT LAST_INSERT_ID()")
        return cursor.fetchone()[0]

def get_town_id(city_id, town_name, cursor, connection):
    # 查詢 town 是否存在
    cursor.execute("SELECT TownID FROM town WHERE TownName = %s and CityID = %s", (town_name, city_id))
    result = cursor.fetchone()
    
    if result:
        # 如果 town 存在，返回 TownID
        return result[0]
    else:
        # 如果 town 不存在，插入 town 並返回新的 TownID
        cursor.execute("INSERT INTO town (CityID, TownName) VALUES (%s, %s)", (city_id, town_name))
        connection.commit()  # 提交新增操作
        # 獲取新插入的 TownID
        cursor.execute("SELECT LAST_INSERT_ID()")
        return cursor.fetchone()[0]

# 設定MySQL資料庫連接
def connect_to_db():
    return mysql.connector.connect(
        host="127.0.0.1",  # 資料庫的IP
        user="root",  # 資料庫的使用者名稱
        password="12345678",  # 資料庫的密碼
        database="bike"  # 資料庫名稱
    )

# 匯入資料的函式
def import_data_to_db(data):
    # 連接到資料庫
    db_connection = connect_to_db()
    cursor = db_connection.cursor()
    

    # 插入資料的SQL語句
    insert_sql = """
    INSERT INTO cyclingroute (CityID, TownID, Name, AlternateNames, Geometry, Start, End, Length, Direction, FinishDate, Management)
    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """
    error_nodes = []
    for item in data:
        try:
            CityID = get_city_id(item['properties']['CITY'], cursor, db_connection)
            TownID = item['properties'].get('TOWN') or None
            if TownID:
                TownID = get_town_id(CityID, TownID, cursor, db_connection)
            Name   = item['properties'].get('NAME') or None
            AlternateNames = item['properties'].get('ROAD_ALIAS') or None
            Geometry = json.dumps(item['geometry'])
            Start = item['properties'].get('SP_DESC') or None
            End = item['properties'].get('EP_DESC') or None
            Length = item['properties'].get('B_LENGTH') or None
            Direction = item['properties'].get('B_DIR') or None
            FinishDate = item['properties'].get('FIN_DT') or None
            Management = item['properties'].get('MGR_MCH') or None
        
            cursor.execute(insert_sql, (
                CityID, TownID, Name, AlternateNames, Geometry,
                Start, End, Length, Direction, FinishDate, Management
            ))
        except Exception  as e:
            print(f"插入錯誤：{e}")
            error_nodes.append({
                "id": item.get("id"),
                "name": item["properties"].get("NAME")
            })
            print("錯誤資料： id = ", item['id'], ", name = ", item['properties']['NAME'])
    
    # 提交到資料庫並關閉
    db_connection.commit()
    cursor.close()
    db_connection.close()
    print("資料已成功匯入！")

# 讀取JSON檔案並匯入資料
def read_json_and_import():

    file_name = ['202306_NORTH.geojson', '202306_MIDDLE.geojson', '202306_SOUTH.geojson', '202306_EAST.geojson', ]
    
    for filename in file_name:
        with open(filename, 'r', encoding='utf-8') as file:
            geojson_data = json.load(file)
            import_data_to_db(geojson_data["features"])
    

read_json_and_import()