-- 1. Users
CREATE TABLE app_users (
    user_id BIGSERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    phone VARCHAR(20) NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    profile_image_url TEXT,
    email_verified_at TIMESTAMPTZ,
    phone_verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Email and phone verification
CREATE TABLE verifications (
    verification_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES app_users(user_id) ON DELETE CASCADE,
    channel VARCHAR(10) NOT NULL CHECK (channel IN ('email', 'phone')),
    code_hash TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    verified_at TIMESTAMPTZ
);

-- 3. User sessions
CREATE TABLE user_sessions (
    session_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES app_users(user_id) ON DELETE CASCADE,
    refresh_token_hash TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Tasks
CREATE TABLE tasks (
    task_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES app_users(user_id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    priority VARCHAR(20),
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    due_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. Goals
CREATE TABLE goals (
    goal_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES app_users(user_id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    target_date DATE,
    progress_percent INTEGER NOT NULL DEFAULT 0
        CHECK (progress_percent BETWEEN 0 AND 100)
);

-- 6. Study sessions
CREATE TABLE study_sessions (
    study_session_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES app_users(user_id) ON DELETE CASCADE,
    subject VARCHAR(100) NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    duration_minutes INTEGER,
    notes TEXT
);

-- 7. Study places
CREATE TABLE study_places (
    place_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES app_users(user_id) ON DELETE CASCADE,
    name VARCHAR(150) NOT NULL,
    address TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION
);

-- 8. Study resources
CREATE TABLE resources (
    resource_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES app_users(user_id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    category VARCHAR(100),
    resource_type VARCHAR(30) NOT NULL,
    resource_url TEXT NOT NULL,
    visibility VARCHAR(10) NOT NULL DEFAULT 'public'
        CHECK (visibility IN ('public', 'private')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 9. Comments
CREATE TABLE comments (
    comment_id BIGSERIAL PRIMARY KEY,
    resource_id BIGINT NOT NULL REFERENCES resources(resource_id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES app_users(user_id) ON DELETE CASCADE,
    comment_text TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 10. Likes and dislikes
CREATE TABLE reactions (
    reaction_id BIGSERIAL PRIMARY KEY,
    resource_id BIGINT NOT NULL REFERENCES resources(resource_id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES app_users(user_id) ON DELETE CASCADE,
    reaction_type VARCHAR(10) NOT NULL
        CHECK (reaction_type IN ('like', 'dislike')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (resource_id, user_id)
);

-- 11. Ratings
CREATE TABLE ratings (
    rating_id BIGSERIAL PRIMARY KEY,
    resource_id BIGINT NOT NULL REFERENCES resources(resource_id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES app_users(user_id) ON DELETE CASCADE,
    rating_value INTEGER NOT NULL CHECK (rating_value BETWEEN 1 AND 5),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (resource_id, user_id)
);
