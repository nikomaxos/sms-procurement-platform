<?php

namespace App\Support;

class MccMncNormalizer
{
    /**
     * Normalize MCCMNC codes for ITU import.
     *
     * Rule:
     *  - When a 6-digit numeric code has 4th digit = '0', drop that digit
     *    to produce a 5-digit code (e.g. 202001 -> 20201).
     */
    public static function normalize(?string $code): string
    {
        $digits = preg_replace('/\D+/', '', (string) $code);

        if (strlen($digits) === 6 && substr($digits, 3, 1) === '0') {
            $digits = substr($digits, 0, 3) . substr($digits, 4);
        }

        return $digits;
    }
}
