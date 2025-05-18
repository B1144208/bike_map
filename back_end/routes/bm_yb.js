const express = require('express');
const router = express.Router();
const pool = require('../connect_db');

router.get('/', (req, res, next) => {
    const userID = req.query.userid;
    const ybID = req.query.ybid;

    let sql = 'SELECT * FROM bookmark_youbike WHERE UserID=? ORDER BY YBID ASC';
    let params = [userID];
    if(userID && ybID){
        sql = 'SELECT * FROM bookmark_youbike WHERE UserID=? AND YBID=?';
        params = [userID, ybID];
    }

    pool.query(sql, params, (err, result) => {
        if (err) {
            console.log(err);
            return next(err);
        }
        res.json(result);
    })
});

// insert a BMYB
router.post('/insertBMYB', (req, res) => {

    const { UserID, YBID } = req.body;

    if (!UserID || !YBID) {
        return res.status(400).send({ error: 'UserID and YBID are required' });
    }

    let sql = 'INSERT INTO bookmark_youbike (UserID, YBID) VALUES (?, ?)';
    let param = [UserID, YBID];
    pool.query(sql, param, (err, result) => {
        if (err) {
            console.error('Error inserting bookmark_youbike:', err);
            return res.status(500).send({ error: 'Failed to insert bookmark_youbike' });
        }
        res.status(201).send({ message: 'bookmark_youbike added successfully', BMYBID: result.insertId });
    });
});


// Delete a BMYB
router.delete('/deleteBMYB', (req, res) => {
  const { userid, ybid } = req.query;

  if (!userid || !ybid) {
    return res.status(400).send({ error: 'UserID and YBID are required' });
  }

  const sql = 'DELETE FROM bookmark_youbike WHERE UserID = ? AND YBID = ?';
  const param = [userid, ybid];

  pool.query(sql, param, (err, result) => {
    if (err) {
      console.error('Error deleting BMYB:', err);
      return res.status(500).send({ error: 'Failed to delete BMYB' });
    }
    if (result.affectedRows === 0) {
      return res.status(404).send({ error: 'No matching bookmark found' });
    }
    res.status(200).send({ message: 'Bookmark deleted successfully' });
  });
});

module.exports = router;