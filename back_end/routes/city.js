const express = require('express');
const router = express.Router();
const pool = require('../connect_db');

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

module.exports = router;