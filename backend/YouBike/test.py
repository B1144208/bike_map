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
        host="localhost",  # 資料庫的IP
        user="root",  # 資料庫的使用者名稱
        password="12345678",  # 資料庫的密碼
        database="bike",  # 資料庫名稱
    )

# 匯入資料的函式
def import_data_to_db(data):
    # 連接到資料庫
    db_connection = connect_to_db()
    cursor = db_connection.cursor()

    # 插入資料的SQL語句
    select_sql = """SELECT * FROM city"""
    cursor.execute(select_sql)

    result = cursor.fetchall()
    print(result)
    
    # 提交到資料庫並關閉
    db_connection.commit()
    cursor.close()
    db_connection.close()

# 讀取JSON檔案並匯入資料
def read_json_and_import():
    with open('YouBike_List.json', 'r', encoding='utf-8') as file:
        data = json.load(file)
        import_data_to_db(data)

read_json_and_import()