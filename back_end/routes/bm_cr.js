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

// insert a BMCR
router.post('/insertBMCR', (req, res) => {

    const { UserID, CRID } = req.body;

    if (!UserID || !CRID) {
        return res.status(400).send({ error: 'UserID and CRID are required' });
    }

    let sql = 'INSERT INTO bookmark_cyclingroute (UserID, CRID) VALUES (?, ?)';
    let param = [UserID, CRID];
    pool.query(sql, param, (err, result) => {
        if (err) {
            console.error('Error inserting bookmark_cyclingroute:', err);
            return res.status(500).send({ error: 'Failed to insert bookmark_cyclingroute' });
        }
        res.status(201).send({ message: 'bookmark_cyclingroute added successfully', BMCRID: result.insertId });
    });
});


// Delete a BMCR
router.delete('/deleteBMCR', (req, res) => {
  const { userid, crid } = req.query;

  if (!userid || !crid) {
    return res.status(400).send({ error: 'UserID and CRID are required' });
  }

  const sql = 'DELETE FROM bookmark_cyclingroute WHERE UserID = ? AND CRID = ?';
  const param = [userid, crid];

  pool.query(sql, param, (err, result) => {
    if (err) {
      console.error('Error deleting BMCR:', err);
      return res.status(500).send({ error: 'Failed to delete BMCR' });
    }
    if (result.affectedRows === 0) {
      return res.status(404).send({ error: 'No matching bookmark found' });
    }
    res.status(200).send({ message: 'BMCR deleted successfully' });
  });
});

/*
router.delete('/deleteBMCR/:BMCRId', (req, res) => {

    const BMCRId = req.params.BMCRId;

    let sql = 'DELETE FROM bookmark_cyclingroute WHERE BMCRId = ?';
    let param = [BMCRId];
    pool.query(sql, param, (err, result) => {
        if (err) {
            console.error('Error deleting BMCR:', err);
            return res.status(500).send({ error: 'Failed to delete BMCR' });
        }
        if (result.affectedRows === 0) {
            return res.status(404).send({ error: 'BMCR not found' });
        }
        res.status(200).send({ message: 'BMCR deleted successfully' });
    });
});
*/

module.exports = router;