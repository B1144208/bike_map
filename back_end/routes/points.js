const express = require('express');
const router = express.Router();
const pool = require('../connect_db');

// GET all points (optionally filter by CRID)
router.get('/', (req, res, next) => {
    const crid = req.query.crid;
    let sql = 'SELECT * FROM cyclingroute_point WHERE 1';
    let params = [];

    if (crid) {
        sql += ' AND CRID = ?';
        params = [crid];
    }

    // 加入排序確保結果一致性
    sql += ' ORDER BY PointID';

    pool.query(sql, params, (err, results) => {
        if (err) return next(err);
        res.json(results);
    });
});

// INSERT a new point (更新為支援 TownID)
router.post('/insertPoint', (req, res, next) => {
    const { CRID, Longitude, Latitude, TownID } = req.body;

    if (!CRID || Longitude === undefined || Latitude === undefined) {
        return res.status(400).json({ error: 'CRID, Longitude, and Latitude are required' });
    }

    const sql = 'INSERT INTO cyclingroute_point (CRID, Longitude, Latitude, TownID) VALUES (?, ?, ?, ?)';
    const params = [CRID, Longitude, Latitude, TownID || null];

    pool.query(sql, params, (err, result) => {
        if (err) return next(err);
        res.json({ message: 'Inserted successfully', id: result.insertId });
    });
});

// DELETE all points by CRID
router.delete('/deleteRoute/:crid', (req, res, next) => {
    const crid = req.params.crid;
    const sql = 'DELETE FROM cyclingroute_point WHERE CRID = ?';
    pool.query(sql, [crid], (err, result) => {
        if (err) return next(err);
        res.json({ message: 'All points for CRID deleted successfully' });
    });
});

// DELETE point by PointID
router.delete('/deletePoint/:id', (req, res, next) => {
    const id = req.params.id;
    const sql = 'DELETE FROM cyclingroute_point WHERE PointID = ?';
    pool.query(sql, [id], (err, result) => {
        if (err) return next(err);
        res.json({ message: 'Deleted successfully' });
    });
});

// 新增：UPDATE point (支援更新鄉鎮資訊)
router.put('/updatePoint/:id', (req, res, next) => {
    const id = req.params.id;
    const { Longitude, Latitude, TownID } = req.body;

    if (Longitude === undefined || Latitude === undefined) {
        return res.status(400).json({ error: 'Longitude and Latitude are required' });
    }

    const sql = `
        UPDATE cyclingroute_point
        SET Longitude = ?, Latitude = ?, TownID = ?
        WHERE PointID = ?
    `;
    const params = [Longitude, Latitude, TownID || null, id];

    pool.query(sql, params, (err, result) => {
        if (err) return next(err);

        if (result.affectedRows === 0) {
            return res.status(404).json({ error: 'Point not found' });
        }

        res.json({ message: 'Point updated successfully' });
    });
});

// 新增：查詢跨區域的路線統計
router.get('/cross-region-stats', async (req, res, next) => {
    try {
        const sql = `
            SELECT
                cr.CRID,
                cr.Name,
                COUNT(DISTINCT crp.TownID) AS unique_towns,
                COUNT(DISTINCT c.CityID) AS unique_cities,
                GROUP_CONCAT(DISTINCT t.TownName) AS towns,
                GROUP_CONCAT(DISTINCT c.CityName) AS cities
            FROM cyclingroute cr
            LEFT JOIN cyclingroute_point crp ON cr.CRID = crp.CRID
            LEFT JOIN town t ON crp.TownID = t.TownID
            LEFT JOIN city c ON t.CityID = c.CityID
            WHERE crp.TownID IS NOT NULL
            GROUP BY cr.CRID, cr.Name
            HAVING unique_towns > 1 OR unique_cities > 1
            ORDER BY unique_cities DESC, unique_towns DESC
        `;

        const [results] = await pool.promise().query(sql);
        res.json(results);
    } catch (err) {
        console.error('Error fetching cross-region stats:', err);
        next(err);
    }
});

// 新增：根據城市或鄉鎮查詢相關的路線ID
router.get('/routes-by-region', async (req, res, next) => {
    const { cityid, townid } = req.query;

    if (!cityid && !townid) {
        return res.status(400).json({ error: 'Either cityid or townid is required' });
    }

    try {
        let sql = `
            SELECT DISTINCT crp.CRID, cr.Name as RouteName, c.CityName, t.TownName
            FROM cyclingroute_point crp
            LEFT JOIN cyclingroute cr ON crp.CRID = cr.CRID
            LEFT JOIN town t ON crp.TownID = t.TownID
            LEFT JOIN city c ON t.CityID = c.CityID
            WHERE 1=1
        `;
        let params = [];

        if (townid) {
            sql += ' AND crp.TownID = ?';
            params.push(townid);
        } else if (cityid) {
            sql += ' AND t.CityID = ?';
            params.push(cityid);
        }

        sql += ' ORDER BY crp.CRID';

        const [results] = await pool.promise().query(sql, params);
        res.json(results);
    } catch (err) {
        console.error('Error fetching routes by region:', err);
        next(err);
    }
});

// 新增：批量更新座標點的鄉鎮資訊
router.put('/batch-update-regions', async (req, res, next) => {
    const { updates } = req.body; // updates 應該是一個包含 {pointId, townID} 的陣列

    if (!updates || !Array.isArray(updates)) {
        return res.status(400).json({ error: 'Updates array is required' });
    }

    const connection = await pool.promise().getConnection();

    try {
        await connection.beginTransaction();

        for (const update of updates) {
            const { pointId, townID } = update;

            if (!pointId) continue;

            const sql = `
                UPDATE cyclingroute_point
                SET TownID = ?
                WHERE PointID = ?
            `;

            await connection.query(sql, [townID || null, pointId]);
        }

        await connection.commit();
        res.json({
            message: 'Batch update completed successfully',
            updatedCount: updates.length
        });

    } catch (err) {
        await connection.rollback();
        console.error('Error in batch update:', err);
        res.status(500).json({ error: 'Failed to batch update regions' });
    } finally {
        connection.release();
    }
});

module.exports = router;