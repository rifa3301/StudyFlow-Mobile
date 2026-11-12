require('dotenv').config();

const crypto = require('crypto');
const express = require('express');
const { Pool } = require('pg');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const app = express();
const PORT = 5000;

const pool = new Pool({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
});

app.use(express.json());

// Check JWT configuration
if (!process.env.JWT_SECRET) {
    console.error('JWT_SECRET is missing from .env');
    process.exit(1);
}

// JWT authentication middleware
function authenticateToken(req, res, next) {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
        return res.status(401).json({
            message: 'Authentication token required.'
        });
    }

    jwt.verify(token, process.env.JWT_SECRET, (error, user) => {
        if (error) {
            return res.status(403).json({
                message: 'Invalid or expired token.'
            });
        }

        req.user = user;
        next();
    });
}

// Home endpoint
app.get('/', (req, res) => {
    res.json({
        message: 'StudyFlow Mobile Backend is running!'
    });
});

// Database health check
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

// Check username availability
app.get('/api/auth/check-username', async (req, res) => {
    try {
        const username = (req.query.username || '').trim();

        if (!/^[a-zA-Z0-9_]{3,50}$/.test(username)) {
            return res.status(400).json({
                message: 'Username must contain 3-50 letters, numbers, or underscores.'
            });
        }

        const result = await pool.query(
            'SELECT user_id FROM app_users WHERE LOWER(username) = LOWER($1)',
            [username]
        );

        res.json({
            username: username,
            available: result.rows.length === 0
        });

    } catch (error) {
        console.error('Username check error:', error.message);

        res.status(500).json({
            message: 'Could not check username.'
        });
    }
});

// Register a new user
app.post('/api/auth/register', async (req, res) => {
    try {
        const {
            username,
            fullName,
            email,
            phone,
            password
        } = req.body;

        if (!username || !fullName || !email || !phone || !password) {
            return res.status(400).json({
                message: 'Please provide all required registration fields.'
            });
        }

        const cleanUsername = username.trim();
        const cleanName = fullName.trim();
        const cleanEmail = email.trim().toLowerCase();
        const cleanPhone = phone.trim();

        if (!/^[a-zA-Z0-9_]{3,50}$/.test(cleanUsername)) {
            return res.status(400).json({
                message: 'Invalid username format.'
            });
        }

        if (password.length < 8) {
            return res.status(400).json({
                message: 'Password must contain at least 8 characters.'
            });
        }

        const passwordHash = await bcrypt.hash(password, 12);

        const result = await pool.query(
            `INSERT INTO app_users
                (username, full_name, email, phone, password_hash)
             VALUES ($1, $2, $3, $4, $5)
             RETURNING user_id, username, full_name, email, phone`,
            [
                cleanUsername,
                cleanName,
                cleanEmail,
                cleanPhone,
                passwordHash
            ]
        );

        res.status(201).json({
            message: 'Registration successful!',
            user: result.rows[0]
        });

    } catch (error) {
        console.error('Registration error:', error.message);

        if (error.code === '23505') {
            return res.status(409).json({
                message: 'Username, email, or phone number already exists.'
            });
        }

        res.status(500).json({
            message: 'Registration failed.'
        });
    }
});

// Login
app.post('/api/auth/login', async (req, res) => {
    try {
        const { identifier, password } = req.body;

        if (!identifier || !password) {
            return res.status(400).json({
                message: 'Please provide username/email and password.'
            });
        }

        const result = await pool.query(
            `SELECT *
             FROM app_users
             WHERE LOWER(username) = LOWER($1)
                OR LOWER(email) = LOWER($1)`,
            [identifier.trim()]
        );

        if (result.rows.length === 0) {
            return res.status(401).json({
                message: 'Invalid login credentials.'
            });
        }

        const user = result.rows[0];

        const passwordMatches = await bcrypt.compare(
            password,
            user.password_hash
        );

        if (!passwordMatches) {
            return res.status(401).json({
                message: 'Invalid login credentials.'
            });
        }

        const token = jwt.sign(
            { userId: user.user_id },
            process.env.JWT_SECRET,
            { expiresIn: '1h' }
        );

        res.json({
            message: 'Login successful!',
            token: token,
            user: {
                user_id: user.user_id,
                username: user.username,
                full_name: user.full_name,
                email: user.email
            }
        });

    } catch (error) {
        console.error('Login error:', error.message);

        res.status(500).json({
            message: 'Login failed.'
        });
    }
});

// Get currently authenticated user
app.get('/api/auth/me', authenticateToken, async (req, res) => {
    try {
        const result = await pool.query(
            `SELECT user_id, username, full_name, email, phone,
                    email_verified_at, phone_verified_at
             FROM app_users
             WHERE user_id = $1`,
            [req.user.userId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({
                message: 'User not found.'
            });
        }

        res.json({
            message: 'Authenticated user retrieved successfully!',
            user: result.rows[0]
        });

    } catch (error) {
        console.error('User retrieval error:', error.message);

        res.status(500).json({
            message: 'Could not retrieve user information.'
        });
    }
});

// Generate an email or phone verification OTP
app.post('/api/auth/send-otp', authenticateToken, async (req, res) => {
    try {
        const { channel } = req.body;

        if (!['email', 'phone'].includes(channel)) {
            return res.status(400).json({
                message: 'Channel must be email or phone.'
            });
        }

        const userResult = await pool.query(
            `SELECT email, phone, email_verified_at, phone_verified_at
             FROM app_users
             WHERE user_id = $1`,
            [req.user.userId]
        );

        if (userResult.rows.length === 0) {
            return res.status(404).json({
                message: 'User not found.'
            });
        }

        const user = userResult.rows[0];

        const verifiedAt = channel === 'email'
            ? user.email_verified_at
            : user.phone_verified_at;

        if (verifiedAt) {
            return res.status(400).json({
                message: `${channel} is already verified.`
            });
        }

        const otp = crypto.randomInt(100000, 1000000).toString();

        const codeHash = crypto
            .createHash('sha256')
            .update(otp)
            .digest('hex');

        const expiresAt = new Date(Date.now() + 5 * 60 * 1000);

        // Remove previous unused OTPs for this channel
        await pool.query(
            `DELETE FROM verifications
             WHERE user_id = $1
               AND channel = $2
               AND verified_at IS NULL`,
            [req.user.userId, channel]
        );

        await pool.query(
            `INSERT INTO verifications
                (user_id, channel, code_hash, expires_at)
             VALUES ($1, $2, $3, $4)`,
            [
                req.user.userId,
                channel,
                codeHash,
                expiresAt
            ]
        );

        const destination = channel === 'email'
            ? user.email
            : user.phone;

        res.json({
            message: `OTP generated for ${channel} verification.`,
            channel: channel,
            destination: destination,
            otp: otp,
            expiresIn: 300,
            note: 'Demo mode: OTP is displayed by the API and is not sent through email or SMS.'
        });

    } catch (error) {
        console.error('OTP generation error:', error.message);

        res.status(500).json({
            message: 'Could not generate verification OTP.'
        });
    }
});

// Verify an email or phone OTP
app.post('/api/auth/verify-otp', authenticateToken, async (req, res) => {
    const client = await pool.connect();

    try {
        const { channel, otp } = req.body;

        if (!['email', 'phone'].includes(channel)) {
            return res.status(400).json({
                message: 'Channel must be email or phone.'
            });
        }

        if (!/^\d{6}$/.test(String(otp || ''))) {
            return res.status(400).json({
                message: 'Please provide a valid six-digit OTP.'
            });
        }

        await client.query('BEGIN');

        const verificationResult = await client.query(
            `SELECT verification_id, code_hash, expires_at
             FROM verifications
             WHERE user_id = $1
               AND channel = $2
               AND verified_at IS NULL
             ORDER BY verification_id DESC
             LIMIT 1
             FOR UPDATE`,
            [req.user.userId, channel]
        );

        if (verificationResult.rows.length === 0) {
            await client.query('ROLLBACK');

            return res.status(400).json({
                message: 'No pending OTP found. Please generate a new OTP.'
            });
        }

        const verification = verificationResult.rows[0];

        if (new Date(verification.expires_at) < new Date()) {
            await client.query(
                `DELETE FROM verifications
                 WHERE verification_id = $1`,
                [verification.verification_id]
            );

            await client.query('COMMIT');

            return res.status(400).json({
                message: 'OTP has expired. Please generate a new OTP.'
            });
        }

        const submittedHash = crypto
            .createHash('sha256')
            .update(String(otp))
            .digest('hex');

        const storedHash = Buffer.from(
            verification.code_hash,
            'hex'
        );

        const submittedHashBuffer = Buffer.from(
            submittedHash,
            'hex'
        );

        const matches =
            storedHash.length === submittedHashBuffer.length &&
            crypto.timingSafeEqual(storedHash, submittedHashBuffer);

        if (!matches) {
            await client.query('ROLLBACK');

            return res.status(400).json({
                message: 'Incorrect OTP. Please try again.'
            });
        }

        const verifiedColumn = channel === 'email'
            ? 'email_verified_at'
            : 'phone_verified_at';

        await client.query(
            `UPDATE app_users
             SET ${verifiedColumn} = NOW()
             WHERE user_id = $1`,
            [req.user.userId]
        );

        await client.query(
            `UPDATE verifications
             SET verified_at = NOW()
             WHERE verification_id = $1`,
            [verification.verification_id]
        );

        await client.query('COMMIT');

        res.json({
            message: `${channel} verified successfully!`,
            channel: channel,
            verified: true
        });

    } catch (error) {
        await client.query('ROLLBACK');

        console.error('OTP verification error:', error.message);

        res.status(500).json({
            message: 'Could not verify OTP.'
        });

    } finally {
        client.release();
    }
});

// Create a new task
app.post('/api/tasks', async (req, res) => {
    try {
        const {
            title,
            description,
            subject,
            priority,
            dueDate
        } = req.body;

        if (!title || !subject || !priority || !dueDate) {
            return res.status(400).json({
                message: 'Please provide all required task fields.'
            });
        }

        const result = await pool.query(
            `INSERT INTO tasks (
                user_id,
                title,
                description,
                subject,
                priority,
                due_date
            )
            VALUES ($1, $2, $3, $4, $5, $6)
            RETURNING *`,
            [
                1,
                title.trim(),
                description || null,
                subject,
                priority,
                dueDate
            ]
        );

        res.status(201).json({
            message: 'Task created successfully!',
            task: result.rows[0]
        });

    } catch (error) {
        console.error('Task creation error:', error.message);

        res.status(500).json({
            message: 'Failed to create task.'
        });
    }
});

// Get tasks with pagination
app.get('/api/tasks', async (req, res) => {
    try {
        const page = Math.max(1, parseInt(req.query.page, 10) || 1);

        const requestedLimit = parseInt(req.query.limit, 10) || 2;
        const limit = Math.min(50, Math.max(1, requestedLimit));

        const offset = (page - 1) * limit;

        const countResult = await pool.query(
            `SELECT COUNT(*) AS total
             FROM tasks
             WHERE user_id = $1`,
            [1]
        );

        const totalTasks = parseInt(countResult.rows[0].total, 10);
        const totalPages = Math.ceil(totalTasks / limit);

        const result = await pool.query(
            `SELECT *
             FROM tasks
             WHERE user_id = $1
             ORDER BY task_id DESC
             LIMIT $2 OFFSET $3`,
            [1, limit, offset]
        );

        res.status(200).json({
            message: 'Tasks retrieved successfully!',
            tasks: result.rows,
            pagination: {
                currentPage: page,
                totalPages: totalPages,
                totalTasks: totalTasks,
                limit: limit
            }
        });

    } catch (error) {
        console.error('Task retrieval error:', error.message);

        res.status(500).json({
            message: 'Failed to retrieve tasks.'
        });
    }
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
    console.log(`StudyFlow backend running on port ${PORT}`);
});