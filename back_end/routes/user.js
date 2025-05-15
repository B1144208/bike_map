const express = require('express');
const router = express.Router();
const pool = require('../connect_db');

router.get('/', (req, res, next) => {
    const userID = req.query.userid;

    let sql = 'SELECT * FROM user WHERE 1';
    let params = [];
    if(userID){
        sql = 'SELECT * FROM user WHERE UserID=?';
        params = [userID];
    }

    pool.query(sql, params, (err, result) => {
        if (err) {
            console.log(err);
            return next(err);
        }
        res.json(result);
    })
});

// 用來檢查帳號是否已經存在的路由
router.get('/checkname', (req, res, next) => {
    const account = req.query.account;

    if (!account) {
        return res.status(400).json({ error: '帳號不能為空' });
    }

    // 使用 SQL 查詢檢查帳號是否已存在
    const sql = 'SELECT * FROM user WHERE Account = ?';
    const params = [account];

    pool.query(sql, params, (err, result) => {
        if (err) {
            console.log(err);
            return next(err);
        }
        // 如果查詢結果有資料，表示帳號已經存在
        if (result.length > 0) {
            return res.json({ exists: true });  // 回傳帳號已存在
        }
        // 如果查詢結果為空，表示帳號不存在
        res.json({ exists: false });  // 回傳帳號不存在
    });
});

// 檢查登入帳號密碼是否正確
router.get('/checkuser', (req, res, next) => {
    const account = req.query.account;
    const password = req.query.password;
    
    if (!account || !password) {
        return res.status(400).json({ error: '帳號密碼不能為空' });
    }

    const sql = 'SELECT * FROM user WHERE Account = ? AND Password = ?';
    const params = [account, password];

    pool.query(sql, params, (err, result) => {
        if (err) {
            console.log(err);
            return next(err);
        }
        // 如果查詢結果有資料，表示帳號密碼正確
        if (result.length > 0) {
            return res.json({ exists: result[0]['UserID'] });  // 回傳帳號已存在
        }
        // 如果查詢結果為空，表示帳號密碼不正確
        res.json({ exists: 0 });  // 回傳帳號不存在
    });
});

// Insert a user
router.post('/insertUser', (req, res) => {

    const { Account, Password } = req.body;
    
    if (!Account || !Password) {
        return res.status(400).send({ error: 'Account and Password are required' });
    }

    let sql = 'INSERT INTO user (Account, Password) VALUES (?, ?)';
    let param = [Account, Password];
    pool.query(sql, param, (err, result) => {
        if (err) {
            console.error('Error inserting user:', err);
            return res.status(500).send({ error: 'Failed to add user' });
        }
        res.status(201).send({ message: 'User added successfully', userId: result.insertId });
    });
});

// Update a user
router.put('/updateUser/:userId', (req, res) => {
    const userId = req.params.userId;
    const { Account, Password, IsManager } = req.body;

    if (!Account || !Password) {
        return res.status(400).send({ error: 'Account and Password are required' });
    }

    let sql = 'UPDATE user SET Account = ?, Password = ?, IsManager = ? WHERE UserID = ?';
    let param = [Account, Password, IsManager || 0, userId];
    pool.query(sql, param, (err, result) => {
        if (err) {
            console.error('Error updating user:', err);
            return res.status(500).send({ error: 'Failed to update user' });
        }
        if (result.affectedRows === 0) {
            return res.status(404).send({ error: 'User not found' });
        }
        res.status(200).send({ message: 'User updated successfully' });
    });
});

// Delete a user
router.delete('/deleteUser/:userId', (req, res) => {

    const userId = req.params.userId;

    let sql = 'DELETE FROM user WHERE UserID = ?';
    let param = [userId];
    pool.query(sql, param, (err, result) => {
        if (err) {
            console.error('Error deleting user:', err);
            return res.status(500).send({ error: 'Failed to delete user' });
        }
        if (result.affectedRows === 0) {
            return res.status(404).send({ error: 'User not found' });
        }
        res.status(200).send({ message: 'User deleted successfully' });
    });
});

module.exports = router;