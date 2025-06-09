const express = require('express');
const router = express.Router();
const pool = require('../connect_db');

router.get('/', (req, res, next) => {
    
    const cityId = req.query.cityid;
    const townId = req.query.townid;
    const ybId = req.query.ybid;
    const keyword = req.query.keyword;

    let sql = `
    SELECT 
        youbike.YBID, town.CityID, city.CityName, 
        youbike.TownID, town.TownName, 
        youbike.Name, youbike.Longitude, youbike.Latitude 
    FROM youbike 
    JOIN town ON youbike.TownID = town.TownID 
    JOIN city ON town.CityID = city.CityID 
    WHERE 1
    `;

    let params = [];

    if (keyword) {
        sql += ' AND youbike.Name LIKE ?';
        params = [`%${keyword}%`];
    } else if (ybId) {
        sql += ' AND youbike.YBID = ?';
        params = [ybId];
    } else if (townId) {
        sql += ' AND youbike.TownID = ?';
        params = [townId];
    } else if (cityId) {
        sql += ' AND town.CityID = ?';
        params = [cityId];
    }

    pool.query(sql, params, (err, result)=>{
        if (err) {
            console.log(err);
            return next(err);
        }
        res.json(result);
    });
});

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

router.get('/isChange', (req, res, next) => {
    

    let sql = `
    SELECT 
        youbike.YBID, youbike.Name, youbike.Longitude, youbike.Latitude 
    FROM youbike 
    WHERE isChange=0
    `;

    let params = [];

    pool.query(sql, params, (err, result)=>{
        if (err) {
            console.log(err);
            return next(err);
        }
        res.json(result);
    });
});

router.put('/updateYBTown/:ybid', (req, res, next) => {
    const ybid = req.params.ybid;
    const { TownID } = req.body;


    if (!TownID) {
        return res.status(400).json({ message: 'TownID 為必填項目' }); // 確保 TownID 存在
    }


    const sql = `
        UPDATE youbike 
        SET TownID = ?, isChange = TRUE
        WHERE YBID = ?
    `;
    const params = [TownID, ybid];

    pool.query(sql, params, (err, result) => {
        if (err) return next(err);
        res.json({ message: '更新 Youbike 成功' });
    });
});




////////////////////////////////////////////////////////////////////////////////////////////////////////////////////



// Insert a youbike
router.post('/insertYoubike', (req, res, next) => {
    const { TownID, Name, Longitude, Latitude } = req.body;

    if (!TownID || !Name || !Longitude || !Latitude) {
        return res.status(400).json({ message: '缺少必要欄位' });
    }

    const sql = 'INSERT INTO youbike (TownID, Name, Longitude, Latitude) VALUES (?, ?, ?, ?)';
    const params = [TownID, Name, Longitude, Latitude];

    pool.query(sql, params, (err, result) => {
        if (err) return next(err);
        res.json({ message: '新增 Youbike 成功', insertedId: result.insertId });
    });
});

// Update a youbike
router.put('/updateYoubike/:ybid', (req, res, next) => {
    const ybid = req.params.ybid;
    const { TownID, Name, Longitude, Latitude } = req.body;

    const sql = `
        UPDATE youbike 
        SET TownID = ?, Name = ?, Longitude = ?, Latitude = ?
        WHERE YBID = ?
    `;
    const params = [TownID, Name, Longitude, Latitude, ybid];

    pool.query(sql, params, (err, result) => {
        if (err) return next(err);
        res.json({ message: '更新 Youbike 成功' });
    });
});

// Delete a youbike
router.delete('/deleteYoubike/:ybid', (req, res, next) => {
    const ybid = req.params.ybid;

    const sql = 'DELETE FROM youbike WHERE YBID = ?';
    pool.query(sql, [ybid], (err, result) => {
        if (err) return next(err);
        res.json({ message: '刪除 Youbike 成功' });
    });
});

module.exports = router;