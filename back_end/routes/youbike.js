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
        sql = 'SELECT YBID, youbike.CityID, CityName, youbike.TownID, TownName, Name, Longitude, Latitude FROM youbike, city, town WHERE YBID=? and youbike.CityID=city.CityID and youbike.TownID=town.TownID';
        params = [ybId];
    }else if(townId){
        sql = 'SELECT YBID, youbike.CityID, CityName, youbike.TownID, TownName, Name, Longitude, Latitude FROM youbike, city, town WHERE youbike.TownID=? and youbike.CityID=city.CityID and youbike.TownID=town.TownID';
        params = [townId];
    }else if(cityId){
        sql = 'SELECT YBID, youbike.CityID, CityName, youbike.TownID, TownName, Name, Longitude, Latitude FROM youbike, city, town WHERE youbike.CityID=? and youbike.CityID=city.CityID and youbike.TownID=town.TownID';
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