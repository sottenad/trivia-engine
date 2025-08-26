-- DropIndex
DROP INDEX "ApiKey_lastUsedAt_idx";

-- DropIndex
DROP INDEX "Clue_categoryId_idx";

-- RenameIndex
ALTER INDEX "Category_name_key" RENAME TO "Category_title_key";
