const express = require('express');
const router = express.Router();
const pool = require('../connect_db');

router.get('/', (req, res, next) => {
    const userID = req.query.userid;
    const crID = req.query.crid;

    let sql = 'SELECT * FROM bookmark_cyclingroute WHERE 1';
    let params = [];
    if(userID && crID){
        sql = 'SELECT * FROM bookmark_cyclingroute WHERE UserID=? AND CRID=?';
        params = [userID, crID];
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