///|
fn ascii_digit_at(text : String, index : Int) -> Int? {
  if index < 0 || index >= text.length() {
    return None
  }
  let code = text[index].to_int()
  if code >= 48 && code <= 57 {
    Some(code - 48)
  } else {
    None
  }
}

///|
fn decimal_2(text : String, start : Int) -> Int? {
  guard ascii_digit_at(text, start) is Some(a) else { return None }
  guard ascii_digit_at(text, start + 1) is Some(b) else { return None }
  Some(a * 10 + b)
}

///|
fn decimal_4(text : String, start : Int) -> Int? {
  guard ascii_digit_at(text, start) is Some(a) else { return None }
  guard ascii_digit_at(text, start + 1) is Some(b) else { return None }
  guard ascii_digit_at(text, start + 2) is Some(c) else { return None }
  guard ascii_digit_at(text, start + 3) is Some(d) else { return None }
  Some(a * 1000 + b * 100 + c * 10 + d)
}

///|
fn is_leap_year(year : Int) -> Bool {
  year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
}

///|
fn days_in_month(year : Int, month : Int) -> Int {
  match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    4 | 6 | 9 | 11 => 30
    2 => if is_leap_year(year) { 29 } else { 28 }
    _ => 0
  }
}

///|
fn valid_date(year : Int, month : Int, day : Int) -> Bool {
  year >= 0 &&
  month >= 1 &&
  month <= 12 &&
  day >= 1 &&
  day <= days_in_month(year, month)
}

///|
fn valid_clock(hour : Int, minute : Int, second : Int) -> Bool {
  hour >= 0 &&
  hour <= 23 &&
  minute >= 0 &&
  minute <= 59 &&
  second >= 0 &&
  second <= 60
}

///|
fn valid_zone_offset(hour : Int, minute : Int) -> Bool {
  hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59
}

///|
fn timestamp_separator(text : String, index : Int) -> Bool {
  if index >= text.length() {
    false
  } else {
    let value = text[index]
    value == 'T' || value == 't'
  }
}

///|
fn parse_fraction_end(text : String, start : Int) -> Int? {
  if start >= text.length() || text[start] != '.' {
    return Some(start)
  }
  let mut index = start + 1
  let first = index
  while index < text.length() {
    match ascii_digit_at(text, index) {
      Some(_) => index += 1
      None => break
    }
  }
  if index == first {
    None
  } else {
    Some(index)
  }
}

///|
fn valid_timezone(text : String, start : Int) -> Bool {
  if start >= text.length() {
    return false
  }
  let marker = text[start]
  if marker == 'Z' || marker == 'z' {
    return start + 1 == text.length()
  }
  if marker != '+' && marker != '-' {
    return false
  }
  if start + 6 != text.length() || text[start + 3] != ':' {
    return false
  }
  guard decimal_2(text, start + 1) is Some(hour) else { return false }
  guard decimal_2(text, start + 4) is Some(minute) else { return false }
  valid_zone_offset(hour, minute)
}

///|
/// Validate the RFC 3339 profile required by RFC 8927 timestamp values.
pub fn is_rfc3339_timestamp(text : String) -> Bool {
  if text.length() < 20 {
    return false
  }
  if text[4] != '-' ||
    text[7] != '-' ||
    !timestamp_separator(text, 10) ||
    text[13] != ':' ||
    text[16] != ':' {
    return false
  }
  guard decimal_4(text, 0) is Some(year) else { return false }
  guard decimal_2(text, 5) is Some(month) else { return false }
  guard decimal_2(text, 8) is Some(day) else { return false }
  guard decimal_2(text, 11) is Some(hour) else { return false }
  guard decimal_2(text, 14) is Some(minute) else { return false }
  guard decimal_2(text, 17) is Some(second) else { return false }
  if !valid_date(year, month, day) || !valid_clock(hour, minute, second) {
    return false
  }
  guard parse_fraction_end(text, 19) is Some(zone_start) else { return false }
  valid_timezone(text, zone_start)
}

///|
pub fn rfc3339_year(text : String) -> Int? {
  if is_rfc3339_timestamp(text) {
    decimal_4(text, 0)
  } else {
    None
  }
}

///|
pub fn rfc3339_month(text : String) -> Int? {
  if is_rfc3339_timestamp(text) {
    decimal_2(text, 5)
  } else {
    None
  }
}

///|
pub fn rfc3339_day(text : String) -> Int? {
  if is_rfc3339_timestamp(text) {
    decimal_2(text, 8)
  } else {
    None
  }
}

///|
pub fn rfc3339_hour(text : String) -> Int? {
  if is_rfc3339_timestamp(text) {
    decimal_2(text, 11)
  } else {
    None
  }
}

///|
pub fn rfc3339_minute(text : String) -> Int? {
  if is_rfc3339_timestamp(text) {
    decimal_2(text, 14)
  } else {
    None
  }
}

///|
pub fn rfc3339_second(text : String) -> Int? {
  if is_rfc3339_timestamp(text) {
    decimal_2(text, 17)
  } else {
    None
  }
}
