import mysql.connector
import json

def connect_to_db():
    return mysql.connector.connect(
        host="127.0.0.1",
        user="root",
        password="12345678",
        database="bike"
    )

def extract_and_insert_points():
    db = connect_to_db()
    cursor = db.cursor()

    # 查詢所有 cyclingroute 的 CRID 和 Geometry 欄位
    cursor.execute("SELECT CRID, Geometry FROM cyclingroute")
    rows = cursor.fetchall()

    for crid, geometry_json in rows:
        try:
            geometry = json.loads(geometry_json)  # 將 JSON 字串轉為 dict
            if geometry["type"] == "MultiLineString":
                for line in geometry["coordinates"]:
                    for coord in line:
                        longitude, latitude = coord
                        cursor.execute(
                            "INSERT INTO cyclingroute_point (CRID, Longitude, Latitude) VALUES (%s, %s, %s)",
                            (crid, longitude, latitude)
                        )
        except Exception as e:
            print(f"解析錯誤 CRID={crid}: {e}")

    db.commit()
    cursor.close()
    db.close()
    print("所有座標點已成功匯入 cyclingroute_point 表中。")

extract_and_insert_points()
