const express = require('express');
const router = express.Router();
const pool = require('../connect_db');

router.get('/', async (req, res, next) => {
    const cityID = req.query.cityid;
    const townID = req.query.townid;
    const crID = req.query.crid;
    const keyword = req.query.keyword;

    let sql = `
        SELECT DISTINCT cyclingroute.CRID, town.CityID, city.CityName, town.TownID, town.TownName,
               management.ManagementID, management.ManagementName, cyclingroute.Name,
               cyclingroute.AlternateNames, cyclingroute.Start,
               cyclingroute.End, cyclingroute.Length, cyclingroute.Direction,
               cyclingroute.FinishDate
        FROM cyclingroute
        LEFT JOIN town ON cyclingroute.TownID = town.TownID
        LEFT JOIN city ON town.CityID = city.CityID
        LEFT JOIN management ON cyclingroute.ManagementID = management.ManagementID
    `;
    let params = [];
    let whereConditions = ['1=1']; // 改用陣列來管理條件

    if (keyword) {
        whereConditions.push('cyclingroute.Name LIKE ?');
        params.push(`%${keyword}%`);
    } else if (crID) {
        whereConditions.push('cyclingroute.CRID = ?');
        params.push(crID);
    } else if (townID) {
        // 修改：查詢主要路線資料或任何座標點在此鄉鎮的路線
        sql += `
            LEFT JOIN cyclingroute_point ON cyclingroute.CRID = cyclingroute_point.CRID
        `;
        whereConditions.push('(cyclingroute.TownID = ? OR cyclingroute_point.TownID = ?)');
        params.push(townID, townID);
    } else if (cityID) {
        // 修改：查詢主要路線資料或任何座標點在此城市的路線
        // 通過 town 表關聯查詢城市，或通過座標點的鄉鎮查詢城市
        sql += `
            LEFT JOIN cyclingroute_point ON cyclingroute.CRID = cyclingroute_point.CRID
            LEFT JOIN town t2 ON cyclingroute_point.TownID = t2.TownID
        `;
        whereConditions.push('(city.CityID = ? OR t2.CityID = ?)');
        params.push(cityID, cityID);
    }

    // 組合 WHERE 條件
    if (whereConditions.length > 0) {
        sql += ' WHERE ' + whereConditions.join(' AND ');
    }

    // 加入排序確保結果一致性
    sql += ' ORDER BY cyclingroute.CRID';

    try {
        const [routes] = await pool.promise().query(sql, params);

        // 查所有點
        const [points] = await pool.promise().query(
            'SELECT CRID, Longitude, Latitude FROM cyclingroute_point ORDER BY CRID, PointID'
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

// Insert cyclingroute (修正 SQL 語句的欄位數量問題)
router.post('/insertCyclingroute', (req, res, next) => {
  const {
    TownID,
    ManagementID,
    Name,
    AlternateNames,
    Start,
    End,
    Length,
    Direction,
    FinishDate,
  } = req.body;

  if (!Name) {
    return res.status(400).json({ message: '缺少必要欄位：路線名稱' });
  }

  const sql = `
    INSERT INTO cyclingroute
    (TownID, Name, AlternateNames, Start, End, Length, Direction, FinishDate, ManagementID)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
  `;

  const params = [
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

// Update cyclingroute (移除不需要的 CityID 參數)
router.put('/updateCyclingroute/:crid', (req, res, next) => {
  const crid = req.params.crid;
  const {
    TownID,
    ManagementID,
    Name,
    AlternateNames,
    Start,
    End,
    Length,
    Direction,
    FinishDate,
  } = req.body;

  const sql = `
    UPDATE cyclingroute
    SET TownID = ?, Name = ?, AlternateNames = ?,
    Start = ?, End = ?, Length = ?, Direction = ?, FinishDate = ?, ManagementID = ?
    WHERE CRID = ?
  `;

    const params = [
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

// Delete cyclingroute
router.delete('/deleteCyclingroute/:crid', (req, res, next) => {
  const crid = req.params.crid;

  const sql = 'DELETE FROM cyclingroute WHERE CRID = ?';
  pool.query(sql, [crid], (err, result) => {
    if (err) return next(err);
    res.json({ message: '刪除 CyclingRoute 成功' });
  });
});

module.exports = router;