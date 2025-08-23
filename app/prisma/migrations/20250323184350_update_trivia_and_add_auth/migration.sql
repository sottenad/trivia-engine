/*
  Warnings:

  - You are about to drop the column `easyWrongAnswer1` on the `TriviaQuestion` table. All the data in the column will be lost.
  - You are about to drop the column `easyWrongAnswer2` on the `TriviaQuestion` table. All the data in the column will be lost.
  - You are about to drop the column `easyWrongAnswer3` on the `TriviaQuestion` table. All the data in the column will be lost.
  - You are about to drop the column `explanation` on the `TriviaQuestion` table. All the data in the column will be lost.
  - You are about to drop the column `hardWrongAnswer1` on the `TriviaQuestion` table. All the data in the column will be lost.
  - You are about to drop the column `hardWrongAnswer2` on the `TriviaQuestion` table. All the data in the column will be lost.
  - You are about to drop the column `hardWrongAnswer3` on the `TriviaQuestion` table. All the data in the column will be lost.
  - You are about to drop the column `mediumWrongAnswer1` on the `TriviaQuestion` table. All the data in the column will be lost.
  - You are about to drop the column `mediumWrongAnswer2` on the `TriviaQuestion` table. All the data in the column will be lost.
  - You are about to drop the column `mediumWrongAnswer3` on the `TriviaQuestion` table. All the data in the column will be lost.
  - Added the required column `correctAnswer` to the `TriviaQuestion` table without a default value. This is not possible if the table is not empty.
  - Added the required column `wrongAnswer1` to the `TriviaQuestion` table without a default value. This is not possible if the table is not empty.
  - Added the required column `wrongAnswer2` to the `TriviaQuestion` table without a default value. This is not possible if the table is not empty.
  - Added the required column `wrongAnswer3` to the `TriviaQuestion` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE "TriviaQuestion" DROP COLUMN "easyWrongAnswer1",
DROP COLUMN "easyWrongAnswer2",
DROP COLUMN "easyWrongAnswer3",
DROP COLUMN "explanation",
DROP COLUMN "hardWrongAnswer1",
DROP COLUMN "hardWrongAnswer2",
DROP COLUMN "hardWrongAnswer3",
DROP COLUMN "mediumWrongAnswer1",
DROP COLUMN "mediumWrongAnswer2",
DROP COLUMN "mediumWrongAnswer3",
ADD COLUMN     "correctAnswer" TEXT NOT NULL,
ADD COLUMN     "wrongAnswer1" TEXT NOT NULL,
ADD COLUMN     "wrongAnswer2" TEXT NOT NULL,
ADD COLUMN     "wrongAnswer3" TEXT NOT NULL;

-- CreateTable
CREATE TABLE "User" (
    "id" SERIAL NOT NULL,
    "email" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "password" TEXT NOT NULL,
    "isAdmin" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ApiKey" (
    "id" SERIAL NOT NULL,
    "key" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "userId" INTEGER NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "lastUsedAt" TIMESTAMP(3),

    CONSTRAINT "ApiKey_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RateLimit" (
    "id" SERIAL NOT NULL,
    "apiKeyId" INTEGER NOT NULL,
    "requests" INTEGER NOT NULL DEFAULT 0,
    "window" TEXT NOT NULL DEFAULT 'hour',
    "limit" INTEGER NOT NULL DEFAULT 100,
    "resetAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "RateLimit_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE UNIQUE INDEX "ApiKey_key_key" ON "ApiKey"("key");

-- CreateIndex
CREATE INDEX "ApiKey_userId_idx" ON "ApiKey"("userId");

-- CreateIndex
CREATE INDEX "RateLimit_apiKeyId_idx" ON "RateLimit"("apiKeyId");

-- CreateIndex
CREATE UNIQUE INDEX "RateLimit_apiKeyId_window_key" ON "RateLimit"("apiKeyId", "window");

-- AddForeignKey
ALTER TABLE "ApiKey" ADD CONSTRAINT "ApiKey_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RateLimit" ADD CONSTRAINT "RateLimit_apiKeyId_fkey" FOREIGN KEY ("apiKeyId") REFERENCES "ApiKey"("id") ON DELETE CASCADE ON UPDATE CASCADE;
