-- ==============================================================================
-- TRIVIA ENGINE - DATABASE SEED DATA
-- ==============================================================================
-- Optional seed data for development/testing
-- Run with: psql $DATABASE_URL < seed.sql
-- ==============================================================================

-- Insert test user (password: 'testpassword123')
-- Note: This hash is for demonstration only. Generate real hashes with bcrypt
INSERT INTO "User" (id, email, username, password_hash, created_at, updated_at)
VALUES 
    (gen_random_uuid(), 'admin@trivia-engine.com', 'admin', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5L2iNNQRfaRSC', NOW(), NOW()),
    (gen_random_uuid(), 'test@trivia-engine.com', 'testuser', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5L2iNNQRfaRSC', NOW(), NOW())
ON CONFLICT (email) DO NOTHING;

-- Insert sample categories
INSERT INTO "Category" (id, name, created_at, updated_at)
VALUES 
    (1, 'Science', NOW(), NOW()),
    (2, 'History', NOW(), NOW()),
    (3, 'Geography', NOW(), NOW()),
    (4, 'Literature', NOW(), NOW()),
    (5, 'Sports', NOW(), NOW()),
    (6, 'Movies', NOW(), NOW()),
    (7, 'Music', NOW(), NOW()),
    (8, 'Technology', NOW(), NOW()),
    (9, 'Art', NOW(), NOW()),
    (10, 'General Knowledge', NOW(), NOW())
ON CONFLICT (id) DO UPDATE SET 
    name = EXCLUDED.name,
    updated_at = NOW();

-- Insert sample clues
INSERT INTO "Clue" (id, category_id, question, answer, value, airdate, created_at, updated_at)
VALUES 
    (gen_random_uuid(), 1, 'This planet is known as the Red Planet', 'Mars', 200, '2024-01-01', NOW(), NOW()),
    (gen_random_uuid(), 1, 'The chemical symbol for gold', 'Au', 400, '2024-01-01', NOW(), NOW()),
    (gen_random_uuid(), 2, 'Year Christopher Columbus reached the Americas', '1492', 200, '2024-01-01', NOW(), NOW()),
    (gen_random_uuid(), 2, 'The ancient wonder located in Egypt', 'The Great Pyramid of Giza', 600, '2024-01-01', NOW(), NOW()),
    (gen_random_uuid(), 3, 'The longest river in the world', 'The Nile', 200, '2024-01-01', NOW(), NOW()),
    (gen_random_uuid(), 3, 'Capital city of Australia', 'Canberra', 400, '2024-01-01', NOW(), NOW()),
    (gen_random_uuid(), 4, 'Author of "Romeo and Juliet"', 'William Shakespeare', 200, '2024-01-01', NOW(), NOW()),
    (gen_random_uuid(), 4, 'The novel that begins "Call me Ishmael"', 'Moby-Dick', 600, '2024-01-01', NOW(), NOW()),
    (gen_random_uuid(), 5, 'Number of players on a basketball team', '5', 200, '2024-01-01', NOW(), NOW()),
    (gen_random_uuid(), 5, 'Host country of the 2016 Summer Olympics', 'Brazil', 400, '2024-01-01', NOW(), NOW())
ON CONFLICT DO NOTHING;

-- Insert sample trivia questions (generated from clues)
WITH clue_data AS (
    SELECT id, category_id, question, answer FROM "Clue" LIMIT 10
)
INSERT INTO "TriviaQuestion" (id, clue_id, category_id, question, correct_answer, wrong_answer1, wrong_answer2, wrong_answer3, difficulty, created_at, updated_at)
SELECT 
    gen_random_uuid(),
    id,
    category_id,
    question,
    answer,
    CASE 
        WHEN answer = 'Mars' THEN 'Venus'
        WHEN answer = 'Au' THEN 'Ag'
        WHEN answer = '1492' THEN '1500'
        WHEN answer = 'The Nile' THEN 'Amazon'
        WHEN answer = 'Canberra' THEN 'Sydney'
        WHEN answer = 'William Shakespeare' THEN 'Charles Dickens'
        WHEN answer = '5' THEN '6'
        ELSE 'Option A'
    END,
    CASE 
        WHEN answer = 'Mars' THEN 'Jupiter'
        WHEN answer = 'Au' THEN 'Fe'
        WHEN answer = '1492' THEN '1485'
        WHEN answer = 'The Nile' THEN 'Mississippi'
        WHEN answer = 'Canberra' THEN 'Melbourne'
        WHEN answer = 'William Shakespeare' THEN 'Mark Twain'
        WHEN answer = '5' THEN '4'
        ELSE 'Option B'
    END,
    CASE 
        WHEN answer = 'Mars' THEN 'Saturn'
        WHEN answer = 'Au' THEN 'Cu'
        WHEN answer = '1492' THEN '1512'
        WHEN answer = 'The Nile' THEN 'Yangtze'
        WHEN answer = 'Canberra' THEN 'Brisbane'
        WHEN answer = 'William Shakespeare' THEN 'Jane Austen'
        WHEN answer = '5' THEN '7'
        ELSE 'Option C'
    END,
    'medium',
    NOW(),
    NOW()
FROM clue_data
ON CONFLICT DO NOTHING;

-- Insert API keys for test users
INSERT INTO "ApiKey" (id, user_id, key, name, created_at, updated_at, last_used_at, is_active)
SELECT 
    gen_random_uuid(),
    u.id,
    'test_' || encode(gen_random_bytes(16), 'hex'),
    'Test API Key',
    NOW(),
    NOW(),
    NULL,
    true
FROM "User" u
WHERE u.email IN ('admin@trivia-engine.com', 'test@trivia-engine.com')
ON CONFLICT DO NOTHING;

-- Insert rate limit records for API keys
INSERT INTO "RateLimit" (id, api_key_id, requests_count, window_start, created_at, updated_at)
SELECT 
    gen_random_uuid(),
    ak.id,
    0,
    NOW(),
    NOW(),
    NOW()
FROM "ApiKey" ak
ON CONFLICT DO NOTHING;

-- Display summary
DO $$
DECLARE
    user_count INTEGER;
    category_count INTEGER;
    clue_count INTEGER;
    question_count INTEGER;
    api_key_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO user_count FROM "User";
    SELECT COUNT(*) INTO category_count FROM "Category";
    SELECT COUNT(*) INTO clue_count FROM "Clue";
    SELECT COUNT(*) INTO question_count FROM "TriviaQuestion";
    SELECT COUNT(*) INTO api_key_count FROM "ApiKey";
    
    RAISE NOTICE '';
    RAISE NOTICE '=================================';
    RAISE NOTICE 'Seed Data Summary:';
    RAISE NOTICE '=================================';
    RAISE NOTICE 'Users: %', user_count;
    RAISE NOTICE 'Categories: %', category_count;
    RAISE NOTICE 'Clues: %', clue_count;
    RAISE NOTICE 'Trivia Questions: %', question_count;
    RAISE NOTICE 'API Keys: %', api_key_count;
    RAISE NOTICE '=================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Test Credentials:';
    RAISE NOTICE 'Email: admin@trivia-engine.com';
    RAISE NOTICE 'Password: testpassword123';
    RAISE NOTICE '=================================';
END $$;