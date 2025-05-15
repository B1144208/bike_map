import requests
import mysql.connector
import json

def get_city_name(city_id, cursor, connection):
    # 查詢 city 是否存在
    cursor.execute("SELECT CityName FROM city WHERE CityID = %s", (city_id,))
    result = cursor.fetchone()
    
    if result:
        # 如果 city 存在，返回 CityName
        return result[0]
    else:
        return -1

def get_town_name(town_id, cursor, connection):
    # 查詢 town 是否存在
    cursor.execute("SELECT TownName FROM town WHERE TownID = %s", (town_id,))
    result = cursor.fetchone()
    
    if result:
        # 如果 town 存在，返回 TownName
        return result[0]
    else:
        return -1

def insert_youbike_latlng(yb_id, lat, lng, cursor, connection):
    # 插入latlng
    try:
        cursor.execute("UPDATE `youbike` SET Longitude=(%s),Latitude=(%s) WHERE YBID=(%s) ", (lng, lat, yb_id))
        connection.commit()
    except Exception as e:
        print(f"更新失敗：YBID = {yb_id}，錯誤訊息：{e}")
        return yb_id
    return 0



# 設定MySQL資料庫連接
def connect_to_db():
    return mysql.connector.connect(
        host="localhost",  # 資料庫的IP
        user="root",  # 資料庫的使用者名稱
        password="12345678",  # 資料庫的密碼
        database="bike",  # 資料庫名稱
    )

# 查找YouBlike
def select_youbike():
    # 連接到資料庫
    db_connection = connect_to_db()
    cursor = db_connection.cursor()

    # 插入資料的SQL語句
    select_sql = """SELECT * FROM youbike"""
    cursor.execute(select_sql)

    API_KEY = "API金鑰"

    error = []
    result = cursor.fetchall()

    
    for item in result:
        city = get_city_name(item[1], cursor, db_connection)
        town = get_town_name(item[2], cursor, db_connection)
        address = "YouBike微笑單車 : "+city+town+item[3]
        url = f"https://maps.googleapis.com/maps/api/place/textsearch/json?query={address}&key={API_KEY}"
        response = requests.get(url)
        data = response.json()
        if data["status"] == "OK" and data["results"]:
            lat = data['results'][0]['geometry']['location']['lat']
            lng = data['results'][0]['geometry']['location']['lng']
            err = insert_youbike_latlng(item[0], lat, lng, cursor, db_connection)
            if err:
                error.append(err)
        else:
            print(f"找不到位址：{address}")
            error.append(item[0])
    print(error)


    # 提交到資料庫並關閉
    db_connection.commit()
    cursor.close()
    db_connection.close()

select_youbike()




