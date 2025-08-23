-- CreateTable
CREATE TABLE "TriviaQuestion" (
    "id" SERIAL NOT NULL,
    "clueId" INTEGER NOT NULL,
    "rephrased" TEXT NOT NULL,
    "explanation" TEXT NOT NULL,
    "easyWrongAnswer1" TEXT NOT NULL,
    "easyWrongAnswer2" TEXT NOT NULL,
    "easyWrongAnswer3" TEXT NOT NULL,
    "mediumWrongAnswer1" TEXT NOT NULL,
    "mediumWrongAnswer2" TEXT NOT NULL,
    "mediumWrongAnswer3" TEXT NOT NULL,
    "hardWrongAnswer1" TEXT NOT NULL,
    "hardWrongAnswer2" TEXT NOT NULL,
    "hardWrongAnswer3" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "model" TEXT NOT NULL,

    CONSTRAINT "TriviaQuestion_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "TriviaQuestion_clueId_idx" ON "TriviaQuestion"("clueId");

-- AddForeignKey
ALTER TABLE "TriviaQuestion" ADD CONSTRAINT "TriviaQuestion_clueId_fkey" FOREIGN KEY ("clueId") REFERENCES "Clue"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
