<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        // Create or replace function that normalizes MCC/MNC:
        // - Build raw MCCMNC from padded MCC(3) + MNC(3)
        // - If 6 digits and 4th digit is '0', drop that '0' => 5-digit code
        // - Recompute MCC (first 3) and MNC (last 2 or 3) from normalized value
        DB::unprepared(<<<'SQL'
CREATE OR REPLACE FUNCTION normalize_network_mncs()
RETURNS trigger AS $$
DECLARE
    v_mcc   text;
    v_mnc   text;
    v_raw   text;
    v_norm  text;
    v_len   int;
BEGIN
    IF NEW.mcc IS NULL OR NEW.mnc IS NULL THEN
        RETURN NEW;
    END IF;

    -- Strip to digits
    v_mcc := regexp_replace(COALESCE(NEW.mcc::text, ''), '\D', '', 'g');
    v_mnc := regexp_replace(COALESCE(NEW.mnc::text, ''), '\D', '', 'g');

    IF v_mcc = '' OR v_mnc = '' THEN
        RETURN NEW;
    END IF;

    -- Build raw MCCMNC as 6 digits: MCC(3) + MNC(3)
    v_raw := lpad(v_mcc, 3, '0') || lpad(v_mnc, 3, '0');

    -- Keep only digits, max 6 chars
    v_norm := regexp_replace(v_raw, '\D', '', 'g');
    v_len  := length(v_norm);

    IF v_len > 6 THEN
        v_norm := substring(v_norm from 1 for 6);
        v_len  := 6;
    END IF;

    -- If 6 digits and 4th digit is '0', drop that '0' => 5-digit composite
    IF v_len = 6 AND substring(v_norm from 4 for 1) = '0' THEN
        v_norm := substring(v_norm from 1 for 3) || substring(v_norm from 5);
        v_len  := 5;
    END IF;

    -- If we ended up with fewer than 5 digits, just store what we have in mcc_mnc
    IF v_len < 5 THEN
        NEW.mcc_mnc := v_norm;
        RETURN NEW;
    END IF;

    -- MCC is always first 3
    NEW.mcc := substring(v_norm from 1 for 3)::integer;

    -- For 5-digit: MCC(3) + MNC(2)
    -- For 6-digit: MCC(3) + MNC(3)
    IF v_len = 5 THEN
        NEW.mnc := substring(v_norm from 4 for 2)::integer;
    ELSE
        NEW.mnc := substring(v_norm from 4)::integer;
    END IF;

    NEW.mcc_mnc := v_norm;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_network_mncs_normalize ON network_mncs;

CREATE TRIGGER trg_network_mncs_normalize
BEFORE INSERT OR UPDATE ON network_mncs
FOR EACH ROW EXECUTE FUNCTION normalize_network_mncs();
SQL
        );

        // Retro-normalize all existing rows by forcing an UPDATE
        DB::unprepared("UPDATE network_mncs SET mcc = mcc WHERE mcc IS NOT NULL AND mnc IS NOT NULL;");
    }

    public function down(): void
    {
        DB::unprepared(<<<'SQL'
DROP TRIGGER IF EXISTS trg_network_mncs_normalize ON network_mncs;
DROP FUNCTION IF EXISTS normalize_network_mncs();
SQL
        );
    }
};
