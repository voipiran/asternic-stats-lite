<?php
/*
 * Small PHP 5.4-compatible Jalali conversion helper.
 * Database timestamps remain Gregorian; Jalali is used for display and input.
 */

function jalali_div($value, $divisor)
{
    return (int) floor($value / $divisor);
}

function gregorian_to_jalali($gy, $gm, $gd)
{
    $g_days_in_month = array(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
    $j_days_in_month = array(31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 29);

    $gy -= 1600;
    $gm -= 1;
    $gd -= 1;
    $g_day_no = 365 * $gy + jalali_div($gy + 3, 4) - jalali_div($gy + 99, 100) + jalali_div($gy + 399, 400);

    for ($i = 0; $i < $gm; $i++) {
        $g_day_no += $g_days_in_month[$i];
    }
    if ($gm > 1 && (($gy % 4) == 0 && ($gy % 100) != 0 || ($gy % 400) == 0)) {
        $g_day_no++;
    }
    $g_day_no += $gd;

    $j_day_no = $g_day_no - 79;
    $j_np = jalali_div($j_day_no, 12053);
    $j_day_no %= 12053;
    $jy = 979 + 33 * $j_np + 4 * jalali_div($j_day_no, 1461);
    $j_day_no %= 1461;

    if ($j_day_no >= 366) {
        $jy += jalali_div($j_day_no - 1, 365);
        $j_day_no = ($j_day_no - 1) % 365;
    }

    for ($i = 0; $i < 11 && $j_day_no >= $j_days_in_month[$i]; $i++) {
        $j_day_no -= $j_days_in_month[$i];
    }
    return array($jy, $i + 1, $j_day_no + 1);
}

function jalali_to_gregorian($jy, $jm, $jd)
{
    $g_days_in_month = array(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
    $j_days_in_month = array(31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 29);

    $jy -= 979;
    $jm -= 1;
    $jd -= 1;
    $j_day_no = 365 * $jy + jalali_div($jy, 33) * 8 + jalali_div(($jy % 33) + 3, 4);
    for ($i = 0; $i < $jm; $i++) {
        $j_day_no += $j_days_in_month[$i];
    }
    $j_day_no += $jd;

    $g_day_no = $j_day_no + 79;
    $gy = 1600 + 400 * jalali_div($g_day_no, 146097);
    $g_day_no %= 146097;
    $leap = true;

    if ($g_day_no >= 36525) {
        $g_day_no--;
        $gy += 100 * jalali_div($g_day_no, 36524);
        $g_day_no %= 36524;
        if ($g_day_no >= 365) {
            $g_day_no++;
        } else {
            $leap = false;
        }
    }

    $gy += 4 * jalali_div($g_day_no, 1461);
    $g_day_no %= 1461;
    if ($g_day_no >= 366) {
        $leap = false;
        $g_day_no--;
        $gy += jalali_div($g_day_no, 365);
        $g_day_no %= 365;
    }

    for ($i = 0; $g_day_no >= $g_days_in_month[$i] + ($i == 1 && $leap ? 1 : 0); $i++) {
        $g_day_no -= $g_days_in_month[$i] + ($i == 1 && $leap ? 1 : 0);
    }
    return array($gy, $i + 1, $g_day_no + 1);
}

function jalali_from_gregorian_datetime($datetime)
{
    $parts = preg_split('/[-: ]/', $datetime);
    $date = gregorian_to_jalali((int) $parts[0], (int) $parts[1], (int) $parts[2]);
    $result = sprintf('%04d/%02d/%02d', $date[0], $date[1], $date[2]);
    if (isset($parts[3])) {
        $result .= sprintf(' %02d:%02d:%02d', $parts[3], $parts[4], $parts[5]);
    }
    return $result;
}

function jalali_month_names()
{
    return array(
        'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
        'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'
    );
}
