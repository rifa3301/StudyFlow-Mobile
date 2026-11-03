require('dotenv').config();

const express = require('express');
const { Pool } = require('pg');

const app = express();

const PORT = 5000;

// PostgreSQL connection pool
const pool = new Pool({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
});

// Middleware
app.use(express.json());

// Test endpoint
app.get('/', (req, res) => {
    res.json({
        message: 'StudyFlow Mobile Backend is running!'
    });
});

// Test PostgreSQL connection
app.get('/api/health/db', async (req, res) => {
    try {
        const result = await pool.query(
            'SELECT current_database() AS database, NOW() AS server_time'
        );

        res.json({
            message: 'PostgreSQL connected successfully!',
            database: result.rows[0].database,
            serverTime: result.rows[0].server_time
        });

    } catch (error) {
        console.error('Database connection error:', error.message);

        res.status(500).json({
            message: 'Database connection failed.'
        });
    }
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
    console.log(`StudyFlow backend running on port ${PORT}`);
});