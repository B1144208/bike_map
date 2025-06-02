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
        sql = 'SELECT cyclingroute.CRID, city.CityID, city.CityName, town.TownID, town.TownName, management.ManagementID, management.ManagementName, cyclingroute.Name, cyclingroute.AlternateNames, cyclingroute.Geometry, cyclingroute.Start, cyclingroute.End, cyclingroute.Length, cyclingroute.Direction, cyclingroute.FinishDate FROM cyclingroute JOIN city ON cyclingroute.CityID = city.CityID JOIN town ON cyclingroute.TownID = town.TownID LEFT JOIN management ON cyclingroute.ManagementID = management.ManagementID WHERE cyclingroute.CRID = ?;';
        params = [crID];
    }else if(townID){
        sql = 'SELECT cyclingroute.CRID, city.CityID, city.CityName, town.TownID, town.TownName, management.ManagementID, management.ManagementName, cyclingroute.Name, cyclingroute.AlternateNames, cyclingroute.Geometry, cyclingroute.Start, cyclingroute.End, cyclingroute.Length, cyclingroute.Direction, cyclingroute.FinishDate FROM cyclingroute JOIN city ON cyclingroute.CityID = city.CityID JOIN town ON cyclingroute.TownID = town.TownID LEFT JOIN management ON cyclingroute.ManagementID = management.ManagementID WHERE cyclingroute.TownID = ?;';
        params = [townID];
    }else if(cityID){
        sql = 'SELECT cyclingroute.CRID, city.CityID, city.CityName, town.TownID, town.TownName, management.ManagementID, management.ManagementName, cyclingroute.Name, cyclingroute.AlternateNames, cyclingroute.Geometry, cyclingroute.Start, cyclingroute.End, cyclingroute.Length, cyclingroute.Direction, cyclingroute.FinishDate FROM cyclingroute JOIN city ON cyclingroute.CityID = city.CityID JOIN town ON cyclingroute.TownID = town.TownID LEFT JOIN management ON cyclingroute.ManagementID = management.ManagementID WHERE cyclingroute.CityID = ?;';
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