require('dotenv').config();

const crypto = require('crypto');
const express = require('express');
const { Pool } = require('pg');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const createGraphQLHandler = require('./graphql');

const app = express();
const PORT = 5000;

const pool = new Pool({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
});

// Check JWT configuration
if (!process.env.JWT_SECRET) {
    console.error('JWT_SECRET is missing from .env');
    process.exit(1);
}

// ==================================================
// GRAPHQL API
// ==================================================

app.all(
    '/graphql',
    createGraphQLHandler(pool, process.env.JWT_SECRET)
);

// Parse JSON bodies for the existing REST endpoints.
app.use(express.json());

// ==================================================
// AUTHENTICATION MIDDLEWARE
// ==================================================

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

// ==================================================
// HOME AND DATABASE HEALTH
// ==================================================

app.get('/', (req, res) => {
    res.json({
        message: 'StudyFlow Mobile Backend is running!'
    });
});

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

// ==================================================
// USERNAME AVAILABILITY
// ==================================================

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

// ==================================================
// USER REGISTRATION
// ==================================================

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
             RETURNING user_id, username, full_name, email, phone,
                       email_verified_at, phone_verified_at`,
            [
                cleanUsername,
                cleanName,
                cleanEmail,
                cleanPhone,
                passwordHash
            ]
        );

        const user = result.rows[0];

        const token = jwt.sign(
            { userId: user.user_id },
            process.env.JWT_SECRET,
            { expiresIn: '1h' }
        );

        res.status(201).json({
            message: 'Registration successful!',
            token: token,
            user: user
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

// ==================================================
// USER LOGIN
// ==================================================

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
                email: user.email,
                phone: user.phone,
                email_verified_at: user.email_verified_at,
                phone_verified_at: user.phone_verified_at
            }
        });

    } catch (error) {
        console.error('Login error:', error.message);

        res.status(500).json({
            message: 'Login failed.'
        });
    }
});

// ==================================================
// GET AUTHENTICATED USER
// ==================================================

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

// ==================================================
// SEND VERIFICATION OTP
// ==================================================

app.post('/api/auth/send-otp', authenticateToken, async (req, res) => {
    try {
        const { channel } = req.body;

        if (!['email', 'phone'].includes(channel)) {
            return res.status(400).json({
                message: 'Channel must be email or phone.'
            });
        }

        if (channel === 'email') {
            return res.status(501).json({
                message: 'Email delivery is not configured yet.'
            });
        }

        if (
            !process.env.SENDMYSMS_USERNAME ||
            !process.env.SENDMYSMS_API_KEY
        ) {
            return res.status(500).json({
                message: 'SMS service is not configured.'
            });
        }

        const userResult = await pool.query(
            `SELECT phone, phone_verified_at
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

        if (user.phone_verified_at) {
            return res.status(400).json({
                message: 'Phone number is already verified.'
            });
        }

        // Normalize the Bangladesh phone number.
        const digits = user.phone.replace(/\D/g, '');

        let phoneNumber = digits;

        if (digits.startsWith('880')) {
            phoneNumber = '0' + digits.slice(3);
        }

        if (!/^01[3-9]\d{8}$/.test(phoneNumber)) {
            return res.status(400).json({
                message: 'Please use a valid Bangladesh mobile number.'
            });
        }

        // Prevent repeated SMS requests within 60 seconds.
        const cooldownResult = await pool.query(
            `SELECT sent_at
             FROM verifications
             WHERE user_id = $1
               AND channel = 'phone'
             ORDER BY sent_at DESC
             LIMIT 1`,
            [req.user.userId]
        );

        if (cooldownResult.rows.length > 0) {
            const lastSentAt = new Date(
                cooldownResult.rows[0].sent_at
            );

            const elapsedSeconds =
                (Date.now() - lastSentAt.getTime()) / 1000;

            if (elapsedSeconds < 60) {
                return res.status(429).json({
                    message: 'Please wait before requesting another OTP.',
                    retryAfter: Math.ceil(60 - elapsedSeconds)
                });
            }
        }

        // Generate a six-digit OTP.
        const otp = crypto.randomInt(100000, 1000000).toString();

        const codeHash = crypto
            .createHash('sha256')
            .update(otp)
            .digest('hex');

        const expiresAt = new Date(Date.now() + 5 * 60 * 1000);

        // Save the new OTP before sending it.
        const insertResult = await pool.query(
            `INSERT INTO verifications
                (user_id, channel, code_hash, expires_at)
             VALUES ($1, 'phone', $2, $3)
             RETURNING verification_id`,
            [
                req.user.userId,
                codeHash,
                expiresAt
            ]
        );

        const verificationId =
            insertResult.rows[0].verification_id;

        try {
            const message =
                `Your StudyFlow verification code is ${otp}. ` +
                'It expires in 5 minutes. Do not share it.';

            const params = new URLSearchParams({
                user: process.env.SENDMYSMS_USERNAME,
                key: process.env.SENDMYSMS_API_KEY,
                to: phoneNumber,
                msg: message
            });

            const smsResponse = await fetch(
                'https://sendmysms.net/api.php',
                {
                    method: 'POST',
                    headers: {
                        'Content-Type':
                            'application/x-www-form-urlencoded'
                    },
                    body: params.toString(),
                    signal: AbortSignal.timeout(15000)
                }
            );

            const smsData = await smsResponse.json();

            if (!smsResponse.ok || smsData.status !== 'OK') {
                throw new Error(
                    smsData.response || 'SMS provider rejected the request.'
                );
            }

        } catch (smsError) {
            // Remove only the newly created OTP.
            await pool.query(
                `DELETE FROM verifications
                 WHERE verification_id = $1`,
                [verificationId]
            );

            console.error(
                'SMS delivery request failed:',
                smsError.message
            );

            return res.status(502).json({
                message: 'Could not send SMS. Please try again later.'
            });
        }

        // Invalidate older pending OTPs only after provider acceptance.
        await pool.query(
            `DELETE FROM verifications
             WHERE user_id = $1
               AND channel = 'phone'
               AND verification_id <> $2
               AND verified_at IS NULL`,
            [req.user.userId, verificationId]
        );

        return res.json({
            message: 'Verification code sent successfully.',
            channel: 'phone',
            expiresIn: 300
        });

    } catch (error) {
        console.error('OTP sending error:', error.message);

        return res.status(500).json({
            message: 'Could not send verification code.'
        });
    }
});

// ==================================================
// VERIFY EMAIL OR PHONE OTP
// ==================================================

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
            `SELECT verification_id, code_hash, expires_at, attempt_count
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
                message: 'No pending OTP found. Please request a new one.'
            });
        }

        const verification = verificationResult.rows[0];

        if (verification.attempt_count >= 5) {
            await client.query(
                `DELETE FROM verifications
                 WHERE verification_id = $1`,
                [verification.verification_id]
            );

            await client.query('COMMIT');

            return res.status(429).json({
                message: 'Too many incorrect attempts. Please request a new OTP.'
            });
        }

        if (new Date(verification.expires_at) < new Date()) {
            await client.query(
                `DELETE FROM verifications
                 WHERE verification_id = $1`,
                [verification.verification_id]
            );

            await client.query('COMMIT');

            return res.status(400).json({
                message: 'OTP has expired. Please request a new OTP.'
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
            crypto.timingSafeEqual(
                storedHash,
                submittedHashBuffer
            );

        if (!matches) {
            await client.query(
                `UPDATE verifications
                 SET attempt_count = attempt_count + 1
                 WHERE verification_id = $1`,
                [verification.verification_id]
            );

            await client.query('COMMIT');

            return res.status(400).json({
                message: 'Incorrect OTP. Please try again.',
                attemptsRemaining: 4 - verification.attempt_count
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

        return res.json({
            message: `${channel} verified successfully!`,
            channel: channel,
            verified: true
        });

    } catch (error) {
        await client.query('ROLLBACK');

        console.error('OTP verification error:', error.message);

        return res.status(500).json({
            message: 'Could not verify OTP.'
        });

    } finally {
        client.release();
    }
});

// ==================================================
// CREATE TASK
// ==================================================

app.post('/api/tasks', authenticateToken, async (req, res) => {
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
                req.user.userId,
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

// ==================================================
// UPDATE TASK STATUS
// ==================================================

app.patch('/api/tasks/:taskId', authenticateToken, async (req, res) => {
    try {
        const taskId = Number(req.params.taskId);
        const { status } = req.body;

        if (
            !Number.isSafeInteger(taskId) ||
            taskId <= 0
        ) {
            return res.status(400).json({
                message: 'Invalid task ID.'
            });
        }

        if (!['pending', 'completed'].includes(status)) {
            return res.status(400).json({
                message: 'Status must be pending or completed.'
            });
        }

        const result = await pool.query(
            `UPDATE tasks
             SET status = $1
             WHERE task_id = $2
               AND user_id = $3
             RETURNING *`,
            [
                status,
                taskId,
                req.user.userId
            ]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({
                message: 'Task not found.'
            });
        }

        res.status(200).json({
            message: 'Task status updated successfully!',
            task: result.rows[0]
        });

    } catch (error) {
        console.error('Task update error:', error.message);

        res.status(500).json({
            message: 'Failed to update task status.'
        });
    }
});

// ==================================================
// DELETE TASK
// ==================================================

app.delete('/api/tasks/:taskId', authenticateToken, async (req, res) => {
    try {
        const taskId = Number(req.params.taskId);

        if (
            !Number.isSafeInteger(taskId) ||
            taskId <= 0
        ) {
            return res.status(400).json({
                message: 'Invalid task ID.'
            });
        }

        const result = await pool.query(
            `DELETE FROM tasks
             WHERE task_id = $1
               AND user_id = $2
             RETURNING task_id`,
            [
                taskId,
                req.user.userId
            ]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({
                message: 'Task not found.'
            });
        }

        res.status(200).json({
            message: 'Task deleted successfully!',
            taskId: result.rows[0].task_id
        });

    } catch (error) {
        console.error('Task deletion error:', error.message);

        res.status(500).json({
            message: 'Failed to delete task.'
        });
    }
});

// ==================================================
// GET PAGINATED TASKS
// ==================================================

app.get('/api/tasks', authenticateToken, async (req, res) => {
    try {
        const page = Math.max(1, parseInt(req.query.page, 10) || 1);

        const requestedLimit = parseInt(req.query.limit, 10) || 2;
        const limit = Math.min(50, Math.max(1, requestedLimit));

        const offset = (page - 1) * limit;

        const userId = req.user.userId;

        const countResult = await pool.query(
            `SELECT COUNT(*) AS total
             FROM tasks
             WHERE user_id = $1`,
            [userId]
        );

        const totalTasks = parseInt(countResult.rows[0].total, 10);
        const totalPages = Math.ceil(totalTasks / limit);

        const result = await pool.query(
            `SELECT *
             FROM tasks
             WHERE user_id = $1
             ORDER BY task_id DESC
             LIMIT $2 OFFSET $3`,
            [userId, limit, offset]
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

// ==================================================
// CREATE STUDY RESOURCE
// ==================================================

app.post('/api/resources', authenticateToken, async (req, res) => {
    try {
        const {
            title,
            description,
            category,
            resourceType,
            resourceUrl,
            visibility
        } = req.body;

        if (
            typeof title !== 'string' ||
            !title.trim() ||
            typeof resourceType !== 'string' ||
            !resourceType.trim() ||
            typeof resourceUrl !== 'string' ||
            !resourceUrl.trim()
        ) {
            return res.status(400).json({
                message: 'Title, resource type and URL are required.'
            });
        }

        if (title.trim().length > 200) {
            return res.status(400).json({
                message: 'Title must not exceed 200 characters.'
            });
        }

        if (resourceType.trim().length > 30) {
            return res.status(400).json({
                message: 'Resource type must not exceed 30 characters.'
            });
        }

        let parsedUrl;

        try {
            parsedUrl = new URL(resourceUrl.trim());
        } catch {
            return res.status(400).json({
                message: 'Please provide a valid resource URL.'
            });
        }

        if (!['http:', 'https:'].includes(parsedUrl.protocol)) {
            return res.status(400).json({
                message: 'Only HTTP and HTTPS links are supported.'
            });
        }

        const resourceVisibility = visibility || 'public';

        if (!['public', 'private'].includes(resourceVisibility)) {
            return res.status(400).json({
                message: 'Visibility must be public or private.'
            });
        }

        const result = await pool.query(
            `INSERT INTO resources (
                user_id,
                title,
                description,
                category,
                resource_type,
                resource_url,
                visibility
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7)
            RETURNING *`,
            [
                req.user.userId,
                title.trim(),
                typeof description === 'string'
                    ? description.trim() || null
                    : null,
                typeof category === 'string'
                    ? category.trim() || null
                    : null,
                resourceType.trim(),
                parsedUrl.toString(),
                resourceVisibility
            ]
        );

        res.status(201).json({
            message: 'Resource created successfully!',
            resource: result.rows[0]
        });

    } catch (error) {
        console.error('Resource creation error:', error.message);

        res.status(500).json({
            message: 'Failed to create resource.'
        });
    }
});

// ==================================================
// GET RESOURCES AND RATING STATISTICS
// ==================================================

app.get('/api/resources', authenticateToken, async (req, res) => {
    try {
        const result = await pool.query(
            `SELECT
                r.resource_id,
                r.user_id,
                r.title,
                r.description,
                r.category,
                r.resource_type,
                r.resource_url,
                r.visibility,
                r.created_at,

                COALESCE(
                    ROUND(AVG(rt.rating_value)::numeric, 2),
                    0
                ) AS average_rating,

                COUNT(rt.rating_id)::integer AS rating_count,

                MAX(rt.rating_value) FILTER (
                    WHERE rt.user_id = $1
                ) AS user_rating

             FROM resources r

             LEFT JOIN ratings rt
                ON rt.resource_id = r.resource_id

             WHERE r.visibility = 'public'
                OR r.user_id = $1

             GROUP BY r.resource_id

             ORDER BY r.created_at DESC`,
            [req.user.userId]
        );

        res.status(200).json({
            message: 'Resources retrieved successfully!',
            resources: result.rows
        });

    } catch (error) {
        console.error('Resource retrieval error:', error.message);

        res.status(500).json({
            message: 'Failed to retrieve resources.'
        });
    }
});

// ==================================================
// SUBMIT OR UPDATE RESOURCE RATING
// ==================================================

app.post(
    '/api/resources/:resourceId/rating',
    authenticateToken,
    async (req, res) => {
        try {
            const resourceId = Number(req.params.resourceId);
            const ratingValue = Number(req.body.rating);

            if (
                !Number.isSafeInteger(resourceId) ||
                resourceId <= 0
            ) {
                return res.status(400).json({
                    message: 'Invalid resource ID.'
                });
            }

            if (
                !Number.isInteger(ratingValue) ||
                ratingValue < 1 ||
                ratingValue > 5
            ) {
                return res.status(400).json({
                    message: 'Rating must be a whole number from 1 to 5.'
                });
            }

            const resource = await pool.query(
                `SELECT resource_id
                 FROM resources
                 WHERE resource_id = $1
                   AND (
                       visibility = 'public'
                       OR user_id = $2
                   )`,
                [resourceId, req.user.userId]
            );

            if (resource.rows.length === 0) {
                return res.status(404).json({
                    message: 'Resource not found.'
                });
            }

            const result = await pool.query(
                `INSERT INTO ratings (
                    resource_id,
                    user_id,
                    rating_value
                )
                VALUES ($1, $2, $3)

                ON CONFLICT (resource_id, user_id)
                DO UPDATE SET
                    rating_value = EXCLUDED.rating_value,
                    created_at = NOW()

                RETURNING *`,
                [
                    resourceId,
                    req.user.userId,
                    ratingValue
                ]
            );

            res.status(200).json({
                message: 'Rating saved successfully!',
                rating: result.rows[0]
            });

        } catch (error) {
            console.error('Rating submission error:', error.message);

            res.status(500).json({
                message: 'Failed to save rating.'
            });
        }
    }
);

// ==================================================
// START SERVER
// ==================================================

app.listen(PORT, '0.0.0.0', () => {
    console.log(`StudyFlow backend running on port ${PORT}`);
});