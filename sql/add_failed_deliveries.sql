-- Migration: Add failed_deliveries column to track when players kill their own cattle
-- This can be safely run on existing databases

ALTER TABLE `tlw_cattle_players` 
ADD COLUMN IF NOT EXISTS `failed_deliveries` INT NOT NULL DEFAULT 0 AFTER `perfect_deliveries`;

-- Optional: Add index for better query performance
CREATE INDEX IF NOT EXISTS `idx_failed_deliveries` ON `tlw_cattle_players` (`failed_deliveries`);
