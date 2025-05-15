const express = require('express');
const router = express.Router();
const pool = require('../connect_db');

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
})

module.exports = router;