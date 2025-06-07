const express = require('express');
const router = express.Router();
const pool = require('../connect_db');

router.get('/', async (req, res, next) => {
    const cityID = req.query.cityid;
    const townID = req.query.townid;
    const crID = req.query.crid;
    const keyword = req.query.keyword;

    let sql = `
        SELECT cyclingroute.CRID, city.CityID, city.CityName, town.TownID, town.TownName,
               management.ManagementID, management.ManagementName, cyclingroute.Name,
               cyclingroute.AlternateNames, cyclingroute.Start,
               cyclingroute.End, cyclingroute.Length, cyclingroute.Direction, cyclingroute.FinishDate
        FROM cyclingroute
        LEFT JOIN city ON cyclingroute.CityID = city.CityID
        LEFT JOIN town ON cyclingroute.TownID = town.TownID
        LEFT JOIN management ON cyclingroute.ManagementID = management.ManagementID
        WHERE 1
    `;
    let params = [];
    

    if (keyword) {
        sql += ' AND cyclingroute.Name LIKE ?';
        params = [`%${keyword}%`];
    } else if (crID) {
        sql += ' AND cyclingroute.CRID = ?';
        params = [crID];
    } else if (townID) {
        sql += ' AND cyclingroute.TownID = ?';
        params = [townID];
    } else if (cityID) {
        sql += ' AND cyclingroute.CityID = ?';
        params = [cityID];
    }

    try {
        const [routes] = await pool.promise().query(sql, params);

        // 查所有點
        const [points] = await pool.promise().query(
            'SELECT CRID, Longitude, Latitude FROM cyclingroute_point'
        );

        // 將點資料依照 CRID 分組
        const pointMap = {};
        for (const p of points) {
            if (!pointMap[p.CRID]) pointMap[p.CRID] = [];
            pointMap[p.CRID].push([p.Longitude, p.Latitude]);
        }

        // 將每筆 route 加入 Coordinates 陣列
        for (const route of routes) {
            route.Coordinates = pointMap[route.CRID] || [];
        }

        res.json(routes);
    } catch (err) {
        console.error(err);
        next(err);
    }
});

// ✅ Insert cyclingroute
router.post('/insertCyclingroute', (req, res, next) => {
  const {
    CityID,
    TownID,
    ManagementID,
    Name,
    AlternateNames,
    Start,
    End,
    Length,
    Direction,
    FinishDate
  } = req.body;

  if (!CityID || !Name ) {
    return res.status(400).json({ message: '缺少必要欄位' });
  }

  const sql = `
    INSERT INTO cyclingroute 
    (CityID, TownID, Name, AlternateNames, Start, End, Length, Direction, FinishDate, ManagementID)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `;

  const params = [
    CityID,
    TownID || null,
    Name,
    AlternateNames || null,
    Start || null,
    End || null,
    Length || null,
    Direction || null,
    FinishDate || null,
    ManagementID || null,
  ];

  pool.query(sql, params, (err, result) => {
    if (err) return next(err);
    res.json({ message: '新增 CyclingRoute 成功', insertedId: result.insertId });
  });
});


// ✅ Update cyclingroute
router.put('/updateCyclingroute/:crid', (req, res, next) => {
  const crid = req.params.crid;
  const {
    CityID,
    TownID,
    ManagementID,
    Name,
    AlternateNames,
    
    Start,
    End,
    Length,
    Direction,
    FinishDate
  } = req.body;

  const sql = `
    UPDATE cyclingroute 
    SET CityID = ?, TownID = ?, Name = ?, AlternateNames = ?, 
    Start = ?, End = ?, Length = ?, Direction = ?, FinishDate = ?, ManagementID = ?
    WHERE CRID = ?
  `;

    const params = [
        CityID,
        TownID || null,
        Name,
        AlternateNames || null,
        Start || null,
        End || null,
        Length || null,
        Direction || null,
        FinishDate || null,
        ManagementID || null,
        crid,
    ];

  pool.query(sql, params, (err, result) => {
    if (err) return next(err);
    res.json({ message: '更新 CyclingRoute 成功' });
  });
});


// ✅ Delete cyclingroute
router.delete('/deleteCyclingroute/:crid', (req, res, next) => {
  const crid = req.params.crid;

  const sql = 'DELETE FROM cyclingroute WHERE CRID = ?';
  pool.query(sql, [crid], (err, result) => {
    if (err) return next(err);
    res.json({ message: '刪除 CyclingRoute 成功' });
  });
});

module.exports = router;
