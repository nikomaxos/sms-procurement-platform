<?php

namespace App\Support;

/**
 * Normalize MCC/MNC composite codes.
 *
 * Rules:
 * - Strip all non-digits.
 * - Consider at most 6 digits (MCC(3) + MNC(2-3)).
 * - If we have 6 digits and the 4th digit is '0', drop that '0' => 5-digit code.
 *   Example: 202001 => 20201 (MCC 202, MNC 001 -> MCC 202, MNC 01).
 * - Otherwise: return the digits as-is.
 */
class MccMncNormalizer
{
    public static function normalize(?string $value): string
    {
        $digits = preg_replace('/\D/', '', (string) $value);

        if ($digits === '') {
            return '';
        }

        $len = strlen($digits);

        // Focus on up to 6 digits, as MCC(3) + MNC(2-3)
        if ($len > 6) {
            $digits = substr($digits, 0, 6);
            $len = 6;
        }

        // If 6 digits and the 4th digit (index 3) is '0',
        // drop that '0' so result is 5 digits (MCC + last 2 digits of MNC).
        if ($len === 6 && $digits[3] === '0') {
            return substr($digits, 0, 3) . substr($digits, 4); // 3 + 2 = 5 digits
        }

        // For 5 digits (3+2) or 6 digits (3+3) without the special 0 rule, keep as-is.
        return $digits;
    }
}
