import mysql.connector
from datetime import datetime

# 函数：将民国日期转换为西元日期
def convert_to_gregorian(date_str):
    try:
        # 假设日期格式为「民国年(YY) + 月(MM) + 日(DD)」
        year = int(date_str[:3]) + 1911  # 民国年份转换为西元年份
        month = int(date_str[3:5])
        day = int(date_str[5:])
        
        # 转换为西元日期格式
        return datetime(year, month, day).strftime('%Y-%m-%d')
    except ValueError:
        print(f"日期格式错误: {date_str}")
        return None

# 连接到 MySQL 数据库
def connect_to_db():
    try:
        return mysql.connector.connect(
            host="127.0.0.1",    # 数据库地址
            user="root",         # 用户名
            password="12345678", # 密码
            database="bike"      # 数据库名称
        )
    except mysql.connector.Error as err:
        print(f"数据库连接错误: {err}")
        return None

# 更新数据表中的日期
def update_finish_date(finish_date, row_id):
    conn = connect_to_db()
    if conn is None:
        return

    cursor = conn.cursor()

    # 更新数据表中的 FinishDate 字段
    update_query = """UPDATE cyclingroute 
                      SET FinishDate = %s 
                      WHERE CRID = %s"""
    try:
        cursor.execute(update_query, (finish_date, row_id))
        conn.commit()
    except mysql.connector.Error as err:
        print(f"更新失败: {err}")
    finally:
        cursor.close()
        conn.close()

# 读取数据并显示
def fetch_and_convert_dates():
    conn = connect_to_db()
    if conn is None:
        return

    cursor = conn.cursor()

    try:
        # 假设有一个名为 `cyclingroute` 的表格，并且有一个 `FinishDate` 字段需要转换
        cursor.execute("SELECT CRID, FinishDate FROM cyclingroute")

        # 获取查询结果
        rows = cursor.fetchall()

        # 转换并更新数据
        for row in rows:
            row_id = row[0]         # 假设 `id` 是每条数据的唯一标识
            original_date = row[1]  # `FinishDate` 是第二个字段
            if original_date:
                converted_date = convert_to_gregorian(str(original_date))  # 转换日期
                if converted_date:
                    print(f"原始日期: {original_date} -> 转换后: {converted_date}")
                    # 更新数据库中的 FinishDate 字段
                    update_finish_date(converted_date, row_id)
            else:
                print(f"无效日期: {original_date}")

    except mysql.connector.Error as err:
        print(f"查询错误: {err}")

    finally:
        cursor.close()
        conn.close()

# 执行数据读取并转换日期
fetch_and_convert_dates()
