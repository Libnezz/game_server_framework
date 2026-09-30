-- Apply explicitly to existing development volumes; init.sql only runs on first boot.
-- Additive migration. No legacy Redis coins or client archives are removed.
CREATE TABLE IF NOT EXISTS player_profiles (
    record_id VARBINARY(64) NOT NULL PRIMARY KEY,
    schema_version INT UNSIGNED NOT NULL,
    revision BIGINT UNSIGNED NOT NULL,
    body JSON NOT NULL,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB;
