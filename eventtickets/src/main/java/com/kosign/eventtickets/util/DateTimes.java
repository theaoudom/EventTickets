package com.kosign.eventtickets.util;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/** Converts between LocalDateTime and the VARCHAR(14) YYYYMMDDHH24MISS column format. */
public final class DateTimes {

    private static final DateTimeFormatter DB_FORMAT = DateTimeFormatter.ofPattern("yyyyMMddHHmmss");

    private DateTimes() {
    }

    public static String now() {
        return format(LocalDateTime.now());
    }

    public static String format(LocalDateTime dateTime) {
        return dateTime == null ? null : dateTime.format(DB_FORMAT);
    }

    public static LocalDateTime parse(String value) {
        return value == null ? null : LocalDateTime.parse(value, DB_FORMAT);
    }
}
