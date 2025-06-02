const express = require('express');
const router = express.Router();
const pool = require('../connect_db');

router.get('/', (req, res, next) => {
    
    const cityId = req.query.cityid;
    const townId = req.query.townid;
    const ybId = req.query.ybid;

    let sql = 'SELECT * FROM youbike WHERE 1';
    let params = [];
    if(ybId){
        sql = 'SELECT youbike.YBID, town.CityID, city.CityName, youbike.TownID, town.TownName, youbike.Name, youbike.Longitude, youbike.Latitude FROM youbike JOIN town ON youbike.TownID = town.TownID JOIN city ON town.CityID = city.CityID WHERE youbike.YBID = ?';
        params = [ybId];
    }else if(townId){
        sql = 'SELECT  youbike.YBID, town.CityID, city.CityName, youbike.TownID, town.TownName, youbike.Name, youbike.Longitude, youbike.Latitude FROM youbike JOIN town ON youbike.TownID = town.TownID JOIN city ON town.CityID = city.CityID WHERE youbike.TownID = ?';
        params = [townId];
    }else if(cityId){
        sql = 'SELECT youbike.YBID, town.CityID, city.CityName, youbike.TownID, town.TownName, youbike.Name, youbike.Longitude, youbike.Latitude FROM youbike JOIN town ON youbike.TownID = town.TownID JOIN city ON town.CityID = city.CityID WHERE town.CityID=?';
        params = [cityId];
    }

    pool.query(sql, params, (err, result)=>{
        if (err) {
            console.log(err);
            return next(err);
        }
        res.json(result);
    });
});

module.exports = router;