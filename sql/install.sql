-- tlw_cattle_herding Database Schema
-- MySQL/MariaDB for RSG-Core

-- Player cattle herding statistics and progression
CREATE TABLE IF NOT EXISTS `tlw_cattle_players` (
    `citizenid` VARCHAR(50) NOT NULL,
    `xp` INT NOT NULL DEFAULT 0,
    `level` INT NOT NULL DEFAULT 1,
    `total_deliveries` INT NOT NULL DEFAULT 0,
    `cattle_saved` INT NOT NULL DEFAULT 0,
    `cattle_lost` INT NOT NULL DEFAULT 0,
    `rustlers_defeated` INT NOT NULL DEFAULT 0,
    `total_earned` INT NOT NULL DEFAULT 0,
    `total_distance` FLOAT NOT NULL DEFAULT 0.0,
    `perfect_deliveries` INT NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`),
    INDEX `level` (`level`),
    INDEX `xp` (`xp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Market demand and pricing data
CREATE TABLE IF NOT EXISTS `tlw_cattle_market` (
    `location_id` VARCHAR(50) NOT NULL,
    `location_name` VARCHAR(100) NOT NULL,
    `demand` DECIMAL(5,3) NOT NULL DEFAULT 1.000,
    `price_multiplier` DECIMAL(5,3) NOT NULL DEFAULT 1.000,
    `last_sale_time` TIMESTAMP NULL DEFAULT NULL,
    `total_sales` INT NOT NULL DEFAULT 0,
    `last_update` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`location_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Active contracts and herds
CREATE TABLE IF NOT EXISTS `tlw_cattle_contracts` (
    `id` INT AUTO_INCREMENT,
    `citizenid` VARCHAR(50) NOT NULL,
    `contract_token` VARCHAR(64) NOT NULL UNIQUE,
    `cattle_type` VARCHAR(50) NOT NULL,
    `herd_size` INT NOT NULL,
    `buy_location` VARCHAR(50) NOT NULL,
    `sell_location` VARCHAR(50) NULL,
    `buy_price_total` INT NOT NULL,
    `cattle_alive` INT NOT NULL,
    `distance_traveled` FLOAT NOT NULL DEFAULT 0.0,
    `cowboys_hired` INT NOT NULL DEFAULT 0,
    `cowboy_cost` INT NOT NULL DEFAULT 0,
    `rustler_encounters` INT NOT NULL DEFAULT 0,
    `status` ENUM('active', 'completed', 'failed', 'abandoned') NOT NULL DEFAULT 'active',
    `started_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `completed_at` TIMESTAMP NULL DEFAULT NULL,
    `final_payout` INT NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    INDEX `citizenid` (`citizenid`),
    INDEX `status` (`status`),
    INDEX `contract_token` (`contract_token`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert default market locations
INSERT INTO `tlw_cattle_market` (`location_id`, `location_name`, `demand`, `price_multiplier`) VALUES
    ('valentine', 'Valentine Auction Yard', 1.000, 1.000),
    ('blackwater', 'Blackwater Market', 1.000, 1.050),
    ('saint_denis', 'Saint Denis Market', 1.000, 1.200),
    ('rhodes', 'Rhodes Market', 1.000, 1.020),
    ('strawberry', 'Strawberry', 1.000, 1.080),
    ('tumbleweed', 'Tumbleweed', 1.000, 0.950),
    ('annesburg', 'Annesburg', 1.000, 1.150)
ON DUPLICATE KEY UPDATE `location_name` = VALUES(`location_name`);

-- Optional: Create indexes for performance
CREATE INDEX IF NOT EXISTS `idx_contracts_active` ON `tlw_cattle_contracts` (`citizenid`, `status`);
CREATE INDEX IF NOT EXISTS `idx_players_level_xp` ON `tlw_cattle_players` (`level`, `xp`);
