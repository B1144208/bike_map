import mysql.connector
import json

def connect_to_db():
    return mysql.connector.connect(
        host="127.0.0.1",
        user="root",
        password="12345678",
        database="bike"
    )

# 取得或插入 management 並回傳 ID
def get_management_id(management_name, cursor, connection):
    cursor.execute("SELECT ManagementID FROM management WHERE ManagementName = %s", (management_name,))
    result = cursor.fetchone()

    if result:
        return result[0]  # 已存在，回傳 ID
    else:
        # 插入新資料
        cursor.execute("INSERT INTO management (ManagementName) VALUES (%s)", (management_name,))
        connection.commit()
        return cursor.lastrowid  # 回傳新插入的 ID

# 取得 cyclingroute 並更新 ManagementID
def process_cycling_routes():
    db_connection = connect_to_db()
    cursor = db_connection.cursor()

    # 取得欄位名稱
    cursor.execute("SELECT * FROM cyclingroute")
    results = cursor.fetchall()
    columns = cursor.column_names

    for row in results:
        row_dict = dict(zip(columns, row))
        management_name = row_dict.get("Management")

        if management_name:
            management_id = get_management_id(management_name, cursor, db_connection)

            # 更新 cyclingroute 的 ManagementID 欄位
            cursor.execute(
                "UPDATE cyclingroute SET ManagementID = %s WHERE CRID = %s",
                (management_id, row_dict["CRID"])
            )

    db_connection.commit()
    cursor.close()
    db_connection.close()
    print("cyclingroute 資料已成功更新！")

# 執行主流程
process_cycling_routes()
