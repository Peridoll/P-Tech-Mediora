CREATE TABLE IF NOT EXISTS `ptech_mediora_core_accounts` (
    `citizenid` VARCHAR(64) NOT NULL,
    `mp_balance` BIGINT NOT NULL DEFAULT 0,
    `mp_earned` BIGINT NOT NULL DEFAULT 0,
    `duty_seconds` BIGINT NOT NULL DEFAULT 0,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`)
);

CREATE TABLE IF NOT EXISTS `ptech_mediora_core_point_log` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(64) NOT NULL,
    `delta` BIGINT NOT NULL,
    `balance_after` BIGINT NOT NULL,
    `action` VARCHAR(24) NOT NULL,
    `source_resource` VARCHAR(64) NOT NULL,
    `reason` VARCHAR(255) NOT NULL,
    `actor_citizenid` VARCHAR(64) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_mediora_core_point_log_citizenid` (`citizenid`),
    KEY `idx_mediora_core_point_log_created_at` (`created_at`)
);

CREATE TABLE IF NOT EXISTS `ptech_mediora_core_activity_stats` (
    `citizenid` VARCHAR(64) NOT NULL,
    `metric_key` VARCHAR(64) NOT NULL,
    `total` DECIMAL(20, 3) NOT NULL DEFAULT 0,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`, `metric_key`),
    KEY `idx_mediora_core_activity_metric_total` (`metric_key`, `total`)
);

CREATE TABLE IF NOT EXISTS `ptech_mediora_core_activity_log` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(64) NOT NULL,
    `metric_key` VARCHAR(64) NOT NULL,
    `amount` DECIMAL(20, 3) NOT NULL,
    `source_resource` VARCHAR(64) NOT NULL,
    `reason` VARCHAR(255) NOT NULL DEFAULT '',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_mediora_core_activity_log_citizenid` (`citizenid`),
    KEY `idx_mediora_core_activity_log_metric` (`metric_key`),
    KEY `idx_mediora_core_activity_log_created_at` (`created_at`)
);
