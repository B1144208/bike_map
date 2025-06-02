const express = require('express');
const router = express.Router();
const pool = require('../connect_db');

// 查詢鄉鎮
router.get('/', (req, res, next)=> {
    const cityID = req.query.cityid;
    const townID = req.query.townid;

    let sql = 'SELECT TownID, TownName FROM town WHERE 1';
    let params = [];
    if(townID){
        sql = 'SELECT TownID, TownName FROM town WHERE TownID=?';
        params = [townID];
    }
    if(cityID){
        sql = 'SELECT TownID, TownName FROM town WHERE CityID=?';
        params = [cityID];
    }

    pool.query(sql, params, (err, result)=>{
        if (err) {
            console.log(err);
            return next(err);
        }
        res.json(result);
    })
});

// 新增鄉鎮
router.post('/insertTown', (req, res) => {
    const { CityID, TownName } = req.body;

    if (!CityID || !TownName) {
        return res.status(400).send({ error: 'CityID and TownName are required' });
    }

    let sql = 'INSERT INTO town (CityID, TownName) VALUES (?, ?)';
    let param = [CityID, TownName];

    pool.query(sql, param, (err, result) => {
        if (err) {
            console.error('Error inserting town:', err);
            return res.status(500).send({ error: 'Failed to add town' });
        }
        res.status(201).send({ message: 'Town added successfully', townId: result.insertId });
    });
});

// 修改鄉鎮
router.put('/updateTown/:townId', (req, res) => {
    const townId = req.params.townId;
    const { CityID, TownName } = req.body;

    if (!CityID || !TownName) {
        return res.status(400).send({ error: 'CityID and TownName are required' });
    }

    let sql = 'UPDATE town SET CityID = ?, TownName = ? WHERE TownID = ?';
    let param = [CityID, TownName, townId];

    pool.query(sql, param, (err, result) => {
        if (err) {
            console.error('Error updating town:', err);
            return res.status(500).send({ error: 'Failed to update town' });
        }
        if (result.affectedRows === 0) {
            return res.status(404).send({ error: 'Town not found' });
        }
        res.status(200).send({ message: 'Town updated successfully' });
    });
});

// 刪除鄉鎮
router.delete('/deleteTown/:townId', (req, res) => {
    const townId = req.params.townId;

    let sql = 'DELETE FROM town WHERE TownID = ?';
    let param = [townId];

    pool.query(sql, param, (err, result) => {
        if (err) {
            console.error('Error deleting town:', err);
            return res.status(500).send({ error: 'Failed to delete town' });
        }
        if (result.affectedRows === 0) {
            return res.status(404).send({ error: 'Town not found' });
        }
        res.status(200).send({ message: 'Town deleted successfully' });
    });
});

module.exports = router;