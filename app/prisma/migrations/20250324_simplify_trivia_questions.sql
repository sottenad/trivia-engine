-- First add the new columns with defaults
ALTER TABLE "TriviaQuestion" ADD COLUMN "wrongAnswer1" TEXT;
ALTER TABLE "TriviaQuestion" ADD COLUMN "wrongAnswer2" TEXT;
ALTER TABLE "TriviaQuestion" ADD COLUMN "wrongAnswer3" TEXT;

-- Migrate data from medium difficulty to new columns
UPDATE "TriviaQuestion" SET 
  "wrongAnswer1" = "mediumWrongAnswer1",
  "wrongAnswer2" = "mediumWrongAnswer2",
  "wrongAnswer3" = "mediumWrongAnswer3";

-- Make the new columns NOT NULL now that they have data
ALTER TABLE "TriviaQuestion" ALTER COLUMN "wrongAnswer1" SET NOT NULL;
ALTER TABLE "TriviaQuestion" ALTER COLUMN "wrongAnswer2" SET NOT NULL;
ALTER TABLE "TriviaQuestion" ALTER COLUMN "wrongAnswer3" SET NOT NULL;

-- Remove the old columns
ALTER TABLE "TriviaQuestion" DROP COLUMN "easyWrongAnswer1";
ALTER TABLE "TriviaQuestion" DROP COLUMN "easyWrongAnswer2";
ALTER TABLE "TriviaQuestion" DROP COLUMN "easyWrongAnswer3";
ALTER TABLE "TriviaQuestion" DROP COLUMN "mediumWrongAnswer1";
ALTER TABLE "TriviaQuestion" DROP COLUMN "mediumWrongAnswer2";
ALTER TABLE "TriviaQuestion" DROP COLUMN "mediumWrongAnswer3";
ALTER TABLE "TriviaQuestion" DROP COLUMN "hardWrongAnswer1";
ALTER TABLE "TriviaQuestion" DROP COLUMN "hardWrongAnswer2";
ALTER TABLE "TriviaQuestion" DROP COLUMN "hardWrongAnswer3"; 