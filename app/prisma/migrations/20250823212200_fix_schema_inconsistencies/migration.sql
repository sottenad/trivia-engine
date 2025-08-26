-- Fix schema inconsistencies migration

-- 1. Rename Category.name to Category.title (preserving data)
ALTER TABLE "Category" RENAME COLUMN "name" TO "title";

-- 2. Add index on Category.title for better query performance
CREATE INDEX "Category_title_idx" ON "Category"("title");

-- 3. Change RateLimit.window from String/Text to Int
-- First, add a temporary integer column
ALTER TABLE "RateLimit" ADD COLUMN "window_temp" INTEGER;

-- Convert existing string values to integers (handle common formats)
UPDATE "RateLimit" SET "window_temp" = 
  CASE 
    WHEN "window" = 'hour' THEN 3600
    WHEN "window" = 'minute' THEN 60
    WHEN "window" = 'day' THEN 86400
    WHEN "window" ~ '^\d+$' THEN CAST("window" AS INTEGER)
    ELSE 3600 -- Default to 1 hour
  END;

-- Drop the old column and rename the new one
ALTER TABLE "RateLimit" DROP COLUMN "window";
ALTER TABLE "RateLimit" RENAME COLUMN "window_temp" TO "window";

-- Set NOT NULL constraint and default
ALTER TABLE "RateLimit" ALTER COLUMN "window" SET NOT NULL;
ALTER TABLE "RateLimit" ALTER COLUMN "window" SET DEFAULT 3600;

-- 4. Remove the unique constraint on (apiKeyId, window) if it exists
ALTER TABLE "RateLimit" DROP CONSTRAINT IF EXISTS "RateLimit_apiKeyId_window_key";

-- 5. Add index on RateLimit.resetAt for better query performance
CREATE INDEX "RateLimit_resetAt_idx" ON "RateLimit"("resetAt");

-- 6. Add missing indexes for better performance (if they don't exist)
CREATE INDEX IF NOT EXISTS "Clue_categoryId_idx" ON "Clue"("categoryId");
CREATE INDEX IF NOT EXISTS "TriviaQuestion_clueId_idx" ON "TriviaQuestion"("clueId");
CREATE INDEX IF NOT EXISTS "ApiKey_lastUsedAt_idx" ON "ApiKey"("lastUsedAt");