const express = require('express');
const router = express.Router();
const pool = require('../connect_db'); // 確認這裡引入的是 connect_db 並使用 pool 變數

router.get('/', (req, res, next) => { // 注意：這裡不再是 async 函式了
    const crid = req.query.crid; // 從查詢參數獲取 CRID

    if (!crid) {
        return res.status(400).json({ error: 'Missing crid parameter' });
    }

    // 使用您提供的資料庫結構來構建 SQL 查詢
    const query = `
        SELECT
            yb.YBID,
            yb.Name,
            yb.Latitude,
            yb.Longitude
        FROM
            youbike AS yb  -- YouBike 站點的實際表名
        JOIN
            yb_near_cr AS relation ON yb.YBID = relation.YBID -- 使用您提供的關聯表名 'yb_near_cr'
        WHERE
            relation.CRID = ?; -- 根據 CRID 進行過濾
    `;

    // 使用 callback 模式的 pool.query
    pool.query(query, [crid], (err, rows) => { // 注意這裡的參數順序：(err, result)
        if (err) {
            console.error('Error fetching nearby YouBike stations:', err);
            return next(err); // 將錯誤傳遞給 Express 的全局錯誤處理器
        }

        // 如果您希望在響應中也包含 CRID (儘管前端已經知道)
        const responseData = rows.map(youbike => ({
            ...youbike,
            CRID_associated: parseInt(crid) // 將請求中的 CRID 加入每個結果，可選
        }));

        if (responseData.length === 0) {
            console.log(`No nearby YouBike stations found for CRID: ${crid}`);
            return res.status(200).json([]); // 沒有找到相關站點，返回空陣列
        }

        console.log(`Found ${responseData.length} nearby YouBike stations for CRID: ${crid}`);
        res.json(responseData); // 返回 YouBike 站點列表
    });
});

module.exports = router;