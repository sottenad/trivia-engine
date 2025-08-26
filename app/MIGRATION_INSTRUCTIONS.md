# Migration Instructions

## Schema Changes Required

This migration fixes several schema inconsistencies and improves performance:

1. **Category field rename**: `name` → `title`
2. **RateLimit window type**: `String` → `Int`
3. **New indexes** for improved query performance

## Steps to Apply Migration

### 1. Backup Your Database
```bash
pg_dump -U postgres -d jservice > backup_$(date +%Y%m%d_%H%M%S).sql
```

### 2. Apply the Migration
```bash
# From the app directory
cd app

# Apply the migration SQL
psql -U postgres -d jservice < prisma/migrations/20250324_fix_schema_inconsistencies.sql

# Generate new Prisma client
npx prisma generate

# Optional: Validate the schema
npx prisma validate
```

### 3. Verify the Changes
```sql
-- Check Category table
\d "Category"

-- Check RateLimit table  
\d "RateLimit"

-- Verify indexes
\di
```

## Important Notes

- The migration converts existing string window values to integers in RateLimit table
- Make sure to update any external scripts that directly query these tables
- After migration, all new rate limit windows must be integers (seconds)
- The Category field is now `title` instead of `name`

## Rollback (if needed)

If you need to rollback:
1. Restore from backup: `psql -U postgres -d jservice < backup_[timestamp].sql`
2. Revert code changes
3. Regenerate Prisma client with old schema