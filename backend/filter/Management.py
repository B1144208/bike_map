import mysql.connector

# 連接到 MySQL 資料庫
def connect_to_db():
    return mysql.connector.connect(
        host="127.0.0.1",    # 資料庫地址
        user="root",         # 使用者名稱
        password="12345678", # 使用者密碼
        database="bike"      # 資料庫名稱
    )

# 步驟：將舊的 ManagementID 轉換為新的 ManagementID
def update_management_ids(id_list):
    conn = connect_to_db()
    cursor = conn.cursor()

    for old_id, new_id in id_list:
        # 更新 cyclingroute 資料表中的 ManagementID
        cursor.execute("""
            UPDATE cyclingroute
            SET ManagementID = %s
            WHERE ManagementID = %s;
        """, (new_id, old_id))

        # 刪除 management 資料表中的舊 ManagementID
        cursor.execute("""
            DELETE FROM management
            WHERE ManagementID = %s;
        """, (old_id,))
    
    conn.commit()  # 提交更改
    cursor.close()
    conn.close()

# 主程序執行步驟
def main():
    # 提供的舊 ManagementID 和新 ManagementID 對應列表
    id_list = [
        (188, 185),
        (210, 209),
        (364, 338),
        (255, 209),
        (254, 209),
        (230, 209),
        (229, 209),
        (226, 209),
        (220, 209),
        (219, 209),
        (210, 209)
    ]
    
    # 根據舊的 ManagementID 和新的 ManagementID 更新資料表
    update_management_ids(id_list)

    print("資料已更新，舊的 ManagementID 已轉換為新的 ManagementID，並刪除了舊的 ManagementID。")

# 執行主程序
if __name__ == "__main__":
    main()
