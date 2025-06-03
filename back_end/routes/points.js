const express = require('express');
const router = express.Router();
const pool = require('../connect_db');

// GET all points (optionally filter by CRID)
router.get('/', (req, res, next) => {
    const crid = req.query.crid;
    let sql = 'SELECT * FROM cyclingroute_point';
    const params = [];

    if (crid) {
        sql += ' WHERE CRID = ?';
        params = [crid];
    }

    pool.query(sql, params, (err, results) => {
        if (err) return next(err);
        res.json(results);
    });
});

// INSERT a new point
router.post('/insertPoint', (req, res, next) => {
    const { CRID, Longitude, Latitude } = req.body;
    if (!CRID || !Longitude || !Latitude) {
        return res.status(400).json({ error: 'Missing fields' });
    }
    const sql = 'INSERT INTO cyclingroute_point (CRID, Longitude, Latitude) VALUES (?, ?, ?)';
    pool.query(sql, [CRID, Longitude, Latitude], (err, result) => {
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

module.exports = router;
