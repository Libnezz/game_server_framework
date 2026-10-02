-- Additive, independent of player_profiles and legacy Redis balances.
CREATE TABLE IF NOT EXISTS player_exploration (
    record_id VARBINARY(64) NOT NULL PRIMARY KEY,
    schema_version INT UNSIGNED NOT NULL,
    revision BIGINT UNSIGNED NOT NULL,
    body JSON NOT NULL,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB;
