import mysql.connector

# 連接到 MySQL 資料庫
def connect_to_db():
    return mysql.connector.connect(
        host="127.0.0.1",    # 資料庫地址
        user="root",         # 使用者名稱
        password="12345678", # 使用者密碼
        database="bike"      # 資料庫名稱
    )

# 步驟 1：查找 old_town 和 town 資料表，當 old_town.TownName = town.TownName 時，回傳 (old_town.TownID, town.TownID)

def fetch_matching_town_ids():
    conn = connect_to_db()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT 
            old_town.TownID AS OldTown, 
            town.TownID AS NewTown
        FROM 
            old_town
        JOIN 
            town ON old_town.TownName = town.TownName
        JOIN 
            old_city ON old_town.CityID = old_city.CityID
        JOIN 
            city ON town.CityID = city.CityID
        WHERE 
            old_city.CityName = city.CityName;
    """)
    
    # 返回所有匹配的 TownID 配對
    town_ids = cursor.fetchall()
    cursor.close()
    conn.close()
    return town_ids

# 步驟 2：用剛剛回傳的 old_town.TownID 查找 youbike 資料表，並將 TownID 更新為新的 town.TownID，並設置 isChange = TRUE
def update_youbike(town_ids):
    conn = connect_to_db()
    cursor = conn.cursor()

    for old_town_id, new_town_id in town_ids:
        cursor.execute("""
            UPDATE youbike
            SET TownID = %s, isChange = TRUE
            WHERE TownID = %s AND isChange = 0;
        """, (new_town_id, old_town_id))
    
    conn.commit()  # 提交更改
    cursor.close()
    conn.close()

# 步驟 3：用剛剛回傳的 old_town.TownID 查找 cyclingroute 資料表，並將 TownID 更新為新的 town.TownID
def update_cyclingroute(town_ids):
    conn = connect_to_db()
    cursor = conn.cursor()

    for old_town_id, new_town_id in town_ids:
        cursor.execute("""
            UPDATE cyclingroute
            SET TownID = %s, isChange = TRUE
            WHERE TownID = %s AND isChange = 0;
        """, (new_town_id, old_town_id))
    
    conn.commit()  # 提交更改
    cursor.close()
    conn.close()

# 步驟 4：刪除 old_town 資料表中的 TownID
def delete_old_town(town_ids):
    conn = connect_to_db()
    cursor = conn.cursor()

    for old_town_id, _ in town_ids:
        cursor.execute("""
            DELETE FROM old_town
            WHERE TownID = %s;
        """, (old_town_id,))
    
    conn.commit()  # 提交更改
    cursor.close()
    conn.close()


# 主程序執行步驟
def main():
    # 步驟 1：查找符合條件的 TownID 配對
    town_ids = fetch_matching_town_ids()

    # 步驟 2：根據 TownID 更新 youbike 資料表
    update_youbike(town_ids)

    # 步驟 3：根據 TownID 更新 cyclingroute 資料表
    update_cyclingroute(town_ids)

    # 步驟 4：刪除 old_town 資料表中的 TownID
    delete_old_town(town_ids)

    print("操作完成，資料已更新。")

# 執行主程序
if __name__ == "__main__":
    main()
