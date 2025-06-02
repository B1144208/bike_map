const express = require('express');
const router = express.Router();
const pool = require('../connect_db');

router.get('/', async (req, res, next) => {
    const cityID = req.query.cityid;
    const townID = req.query.townid;
    const crID = req.query.crid;

    let sql = `
        SELECT cyclingroute.CRID, city.CityID, city.CityName, town.TownID, town.TownName,
               management.ManagementID, management.ManagementName, cyclingroute.Name,
               cyclingroute.AlternateNames, cyclingroute.Geometry, cyclingroute.Start,
               cyclingroute.End, cyclingroute.Length, cyclingroute.Direction, cyclingroute.FinishDate
        FROM cyclingroute
        LEFT JOIN city ON cyclingroute.CityID = city.CityID
        LEFT JOIN town ON cyclingroute.TownID = town.TownID
        LEFT JOIN management ON cyclingroute.ManagementID = management.ManagementID
        WHERE 1
    `;
    let params = [];

    if (crID) {
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

module.exports = router;
