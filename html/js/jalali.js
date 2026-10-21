/* Jalali date conversion for the Asternic report filter. */
(function (window) {
    'use strict';

    function div(a, b) {
        return Math.floor(a / b);
    }

    window.gregorianToJalali = function (gy, gm, gd) {
        var gDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
        var jDays = [31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 29];
        gy -= 1600; gm -= 1; gd -= 1;
        var day = 365 * gy + div(gy + 3, 4) - div(gy + 99, 100) + div(gy + 399, 400);
        for (var i = 0; i < gm; i++) { day += gDays[i]; }
        if (gm > 1 && ((gy % 4 === 0 && gy % 100 !== 0) || gy % 400 === 0)) { day++; }
        day += gd;
        day -= 79;
        var cycle = div(day, 12053);
        day %= 12053;
        var jy = 979 + 33 * cycle + 4 * div(day, 1461);
        day %= 1461;
        if (day >= 366) { jy += div(day - 1, 365); day = (day - 1) % 365; }
        for (i = 0; i < 11 && day >= jDays[i]; i++) { day -= jDays[i]; }
        return [jy, i + 1, day + 1];
    };

    window.jalaliToGregorian = function (jy, jm, jd) {
        var gDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
        var jDays = [31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 29];
        jy -= 979; jm -= 1; jd -= 1;
        var day = 365 * jy + div(jy, 33) * 8 + div((jy % 33) + 3, 4);
        for (var i = 0; i < jm; i++) { day += jDays[i]; }
        day += jd + 79;
        var gy = 1600 + 400 * div(day, 146097);
        day %= 146097;
        var leap = true;
        if (day >= 36525) {
            day--; gy += 100 * div(day, 36524); day %= 36524;
            if (day >= 365) { day++; } else { leap = false; }
        }
        gy += 4 * div(day, 1461); day %= 1461;
        if (day >= 366) { leap = false; day--; gy += div(day, 365); day %= 365; }
        for (i = 0; day >= gDays[i] + (i === 1 && leap ? 1 : 0); i++) {
            day -= gDays[i] + (i === 1 && leap ? 1 : 0);
        }
        return [gy, i + 1, day + 1];
    };

    window.jalaliMonthLength = function (year, month) {
        if (month <= 6) { return 31; }
        if (month <= 11) { return 30; }
        return ((year % 33) % 4 === 1) ? 30 : 29;
    };
}(window));
