-- Fix schema inconsistencies migration

-- 1. Rename Category.name to Category.title
ALTER TABLE "Category" RENAME COLUMN "name" TO "title";

-- 2. Add index on Category.title for better query performance
CREATE INDEX "Category_title_idx" ON "Category"("title");

-- 3. Change RateLimit.window from String to Int
-- First, we need to convert existing string values to integers
ALTER TABLE "RateLimit" ADD COLUMN "window_temp" INTEGER;
UPDATE "RateLimit" SET "window_temp" = CAST("window" AS INTEGER);
ALTER TABLE "RateLimit" DROP COLUMN "window";
ALTER TABLE "RateLimit" RENAME COLUMN "window_temp" TO "window";

-- 4. Remove the unique constraint on (apiKeyId, window) since window is now an integer
ALTER TABLE "RateLimit" DROP CONSTRAINT IF EXISTS "RateLimit_apiKeyId_window_key";

-- 5. Add index on RateLimit.resetAt for better query performance
CREATE INDEX "RateLimit_resetAt_idx" ON "RateLimit"("resetAt");

-- 6. Add missing indexes for better performance
CREATE INDEX IF NOT EXISTS "Clue_categoryId_idx" ON "Clue"("categoryId");
CREATE INDEX IF NOT EXISTS "TriviaQuestion_clueId_idx" ON "TriviaQuestion"("clueId");
CREATE INDEX IF NOT EXISTS "ApiKey_lastUsedAt_idx" ON "ApiKey"("lastUsedAt");

-- Update migration lock
UPDATE "_prisma_migrations" SET "applied_steps_count" = 1 WHERE "migration_name" = '20250324_fix_schema_inconsistencies';