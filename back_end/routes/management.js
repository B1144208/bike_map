const express = require('express');
const router = express.Router();
const pool = require('../connect_db');


router.get('/', (req, res, next) => {
    const id = req.query.id;
    const name = req.query.name;
    
    let sql = 'SELECT * FROM management WHERE 1';
    let params = [];
    
    if(id){
        sql = 'SELECT * FROM management WHERE ManagementID=?';
        params = [id];
    } else if(name){
        sql = 'SELECT * FROM management WHERE ManagementName=?';
        params = [name];
    }
    pool.query(sql, params, (err, results) => {
        if (err) return next(err);
        if (results.length === 0) {
        return res.status(404).json({ error: 'Not Found' });
        }
        res.json(results);
    });
});

// INSERT a new management
router.post('/insertManagement', (req, res, next) => {
  const { ManagementName } = req.body;
  if (!ManagementName) {
    return res.status(400).json({ error: 'Missing fields' });
  }

  const sql = 'INSERT INTO management (ManagementName) VALUES (?)';
  pool.query(sql, [ManagementName], (err, result) => {
    if (err) return next(err);
    res.json({ message: 'Inserted successfully', id: result.insertId });
  });
});

// UPDATE management
router.put('/updateManagement/:id', (req, res, next) => {
  const id = req.params.id;
  const { ManagementName } = req.body;
  const sql = 'UPDATE management SET ManagementName = ? WHERE ManagementID = ?';
  pool.query(sql, [ManagementName, id], (err, result) => {
    if (err) return next(err);
    res.json({ message: 'Updated successfully' });
  });
});

// DELETE a management
router.delete('/deleteManagement/:id', (req, res, next) => {
  const id = req.params.id;
  const sql = 'DELETE FROM management WHERE ManagementID = ?';
  pool.query(sql, [id], (err, result) => {
    if (err) return next(err);
    res.json({ message: 'Deleted successfully' });
  });
});

module.exports = router;
