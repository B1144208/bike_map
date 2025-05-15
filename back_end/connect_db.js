const mysql = require('mysql2');

const pool = mysql.createPool({
    host: 'localhost',
    user: 'root',
    password: '12345678',
    database: 'bike',
    waitForConnections: true,
    connectionLimit: 10,  // 最大連接數
    queueLimit: 0         // 排隊請求的最大數量
})

module.exports = pool;