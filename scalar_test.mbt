///|
test "rfc3339 timestamps accept calendar and zone forms" {
  let valid = [
    "1985-04-12T23:20:50.52Z", "1996-12-19T16:39:57-08:00", "2024-02-29t00:00:00z",
    "2020-01-01T00:00:60+00:00",
  ]
  for text in valid {
    assert_true(@moonjtd.is_rfc3339_timestamp(text))
  }
}

///|
test "rfc3339 timestamps reject invalid dates and shapes" {
  let invalid = [
    "", "2023-02-29T00:00:00Z", "2024-13-01T00:00:00Z", "2024-01-00T00:00:00Z", "2024-01-01 00:00:00Z",
    "2024-01-01T24:00:00Z", "2024-01-01T00:60:00Z", "2024-01-01T00:00:61Z", "2024-01-01T00:00:00.Z",
    "2024-01-01T00:00:00+24:00",
  ]
  for text in invalid {
    assert_false(@moonjtd.is_rfc3339_timestamp(text))
  }
}

///|
test "timestamp component helpers are guarded" {
  let text = "2026-09-19T08:07:06Z"
  assert_eq(@moonjtd.rfc3339_year(text), Some(2026))
  assert_eq(@moonjtd.rfc3339_month(text), Some(9))
  assert_eq(@moonjtd.rfc3339_day(text), Some(19))
  assert_eq(@moonjtd.rfc3339_hour(text), Some(8))
  assert_eq(@moonjtd.rfc3339_minute(text), Some(7))
  assert_eq(@moonjtd.rfc3339_second(text), Some(6))
  assert_eq(@moonjtd.rfc3339_year("invalid"), None)
}

///|
test "integer scalar boundaries are exact" {
  assert_true(@moonjtd.scalar_accepts(@moonjtd.Int8Type, Json::number(-128.0)))
  assert_true(@moonjtd.scalar_accepts(@moonjtd.Int8Type, Json::number(127.0)))
  assert_false(@moonjtd.scalar_accepts(@moonjtd.Int8Type, Json::number(128.0)))
  assert_false(@moonjtd.scalar_accepts(@moonjtd.Uint8Type, Json::number(-1.0)))
  assert_true(
    @moonjtd.scalar_accepts(@moonjtd.Uint32Type, Json::number(4294967295.0)),
  )
  assert_false(
    @moonjtd.scalar_accepts(@moonjtd.Uint32Type, Json::number(4294967296.0)),
  )
}

///|
test "integer scalar rejects fractions and strings" {
  assert_false(@moonjtd.scalar_accepts(@moonjtd.Int16Type, Json::number(1.5)))
  assert_false(@moonjtd.scalar_accepts(@moonjtd.Int16Type, Json::string("1")))
}

///|
test "timestamp scalar validates content" {
  assert_true(
    @moonjtd.scalar_accepts(
      @moonjtd.TimestampType,
      Json::string("2026-09-19T12:00:00Z"),
    ),
  )
  assert_false(
    @moonjtd.scalar_accepts(@moonjtd.TimestampType, Json::string("today")),
  )
}
