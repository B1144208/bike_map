const express = require('express');
const cors = require('cors');
const app = express();
const port = 3000;


app.use(cors());            // 啟用 CORS，允許來自任何來源的請求
app.use(express.json());    // 設置 JSON body 解析中介軟體，處理 application/json 格式的請求

// 路由模組
const cityRoutes = require('./routes/city');
const townRoutes = require('./routes/town');
const youbikeRoutes = require('./routes/youbike');
const cyclingrouteRoutes = require('./routes/cyclingroute');
const userRoutes = require('./routes/user');

// 使用路由
app.use('/city', cityRoutes);
app.use('/town', townRoutes);
app.use('/youbike', youbikeRoutes);
app.use('/cyclingroute', cyclingrouteRoutes);
app.use('/user', userRoutes);

// 測試首頁
app.get('/', (req, res) => {
    res.send('Hello, World!');
});

// 全局錯誤處理中間件
app.use((err, req, res, next) => {
    console.error(err);  // 記錄錯誤
    res.status(500).send('資料庫查詢錯誤');
});

app.listen(port, () => {
    console.log(`Server running at http://localhost:${port}`);
});



