///|
pub fn json_kind(value : Json) -> String {
  match value {
    Null => "null"
    True | False => "boolean"
    Number(_, ..) => "number"
    String(_) => "string"
    Array(_) => "array"
    Object(_) => "object"
  }
}

///|
fn number_is_integral(value : Double) -> Bool {
  value.to_int64().to_double() == value
}

///|
fn integer_in_range(value : Double, kind : JtdType) -> Bool {
  if !number_is_integral(value) {
    return false
  }
  guard kind.minimum() is Some(minimum) else { return false }
  guard kind.maximum() is Some(maximum) else { return false }
  value >= minimum && value <= maximum
}

///|
pub fn scalar_accepts(kind : JtdType, value : Json) -> Bool {
  match kind {
    BooleanType => value is True || value is False
    Float32Type | Float64Type => value is Number(_)
    StringType => value is String(_)
    TimestampType =>
      match value {
        String(text) => is_rfc3339_timestamp(text)
        _ => false
      }
    Int8Type | Uint8Type | Int16Type | Uint16Type | Int32Type | Uint32Type =>
      match value {
        Number(number, ..) => integer_in_range(number, kind)
        _ => false
      }
  }
}

///|
pub fn scalar_expectation(kind : JtdType) -> String {
  match kind {
    BooleanType => "boolean"
    Float32Type => "JSON number intended for IEEE-754 float32"
    Float64Type => "JSON number intended for IEEE-754 float64"
    Int8Type => "integer from -128 through 127"
    Uint8Type => "integer from 0 through 255"
    Int16Type => "integer from -32768 through 32767"
    Uint16Type => "integer from 0 through 65535"
    Int32Type => "integer from -2147483648 through 2147483647"
    Uint32Type => "integer from 0 through 4294967295"
    StringType => "string"
    TimestampType => "RFC 3339 timestamp string"
  }
}
