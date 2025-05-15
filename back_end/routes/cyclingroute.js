const express = require('express');
const router = express.Router();
const pool = require('../connect_db');

router.get('/', (req, res, next) => {

    const cityID = req.query.cityid;
    const townID = req.query.townid;
    const crID = req.query.crid;

    let sql = 'SELECT * FROM cyclingroute WHERE 1';
    let params = [];
    if(crID){
        sql = 'SELECT * FROM cyclingroute WHERE CRID=?';
        params = [crID];
    }else if(townID){
        sql = 'SELECT * FROM cyclingroute WHERE TownID=?';
        params = [townID];
    }else if(cityID){
        sql = 'SELECT * FROM cyclingroute WHERE CityID=?';
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