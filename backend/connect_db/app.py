from flask import Flask, jsonify
import mysql.connector

app = Flask(__name__)

# 資料庫連線設定
db = mysql.connector.connect(
    host='localhost',
    user='root',
    password='12345678',
    database='bike'
)

@app.route('/')
def home():
    return 'Hello, Flask!'

@app.route('/cities', methods=['GET'])
def get_cities():
    cursor = db.cursor(dictionary=True)
    cursor.execute("SELECT * FROM city")
    rows = cursor.fetchall()
    return jsonify(rows)

if __name__ == '__main__':
    app.run(debug=True)


