const express = require('express');
const router = express.Router();
const pool = require('../connect_db');

// 查詢城市
router.get('/', (req, res, next) => {
    const cityID = req.query.cityid;

    let sql = 'SELECT * FROM city WHERE 1';
    let params = [];
    if(cityID){
        sql = 'SELECT CityID, CityName FROM city WHERE CityID=?';
        params = [cityID];
    }

    pool.query(sql, params, (err, result) => {
        if (err) {
            console.log(err);
            return next(err);
        }
        res.json(result);
    })
});

// 新增城市
router.post('/insertCity', (req, res) => {
    const { CityName } = req.body;

    if (!CityName) {
        return res.status(400).send({ error: 'CityName is required' });
    }

    let sql = 'INSERT INTO city (CityName) VALUES (?)';
    let param = [CityName];

    pool.query(sql, param, (err, result) => {
        if (err) {
            console.error('Error inserting city:', err);
            return res.status(500).send({ error: 'Failed to add city' });
        }
        res.status(201).send({ message: 'City added successfully', cityId: result.insertId });
    });
});

// 修改城市
router.put('/updateCity/:cityId', (req, res) => {
    const cityId = req.params.cityId;
    const { CityName } = req.body;

    if (!CityName) {
        return res.status(400).send({ error: 'CityName is required' });
    }

    let sql = 'UPDATE city SET CityName = ? WHERE CityID = ?';
    let param = [CityName, cityId];

    pool.query(sql, param, (err, result) => {
        if (err) {
            console.error('Error updating city:', err);
            return res.status(500).send({ error: 'Failed to update city' });
        }
        if (result.affectedRows === 0) {
            return res.status(404).send({ error: 'City not found' });
        }
        res.status(200).send({ message: 'City updated successfully' });
    });
});

// 刪除城市
router.delete('/deleteCity/:cityId', (req, res) => {
    const cityId = req.params.cityId;

    let sql = 'DELETE FROM city WHERE CityID = ?';
    let param = [cityId];

    pool.query(sql, param, (err, result) => {
        if (err) {
            console.error('Error deleting city:', err);
            return res.status(500).send({ error: 'Failed to delete city' });
        }
        if (result.affectedRows === 0) {
            return res.status(404).send({ error: 'City not found' });
        }
        res.status(200).send({ message: 'City deleted successfully' });
    });
});

module.exports = router;