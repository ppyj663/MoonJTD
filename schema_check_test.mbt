///|
fn checked_errors(text : StringView) -> Array[@moonjtd.Diagnostic] {
  match @moonjtd.parse_schema(text) {
    Ok(document) => @moonjtd.check_schema(document)
    Err(_) => abort("unexpected parse error")
  }
}

///|
test "well formed schema passes semantic checks" {
  let errors = checked_errors(
    "{\"definitions\":{\"id\":{\"type\":\"uint32\"}},\"properties\":{\"id\":{\"ref\":\"id\"}}}",
  )
  assert_eq(errors.length(), 0)
}

///|
test "unknown ref is reported" {
  let errors = checked_errors("{\"ref\":\"missing\"}")
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].code(), @moonjtd.UnknownReference)
  assert_eq(errors[0].schema_path().to_string(), "/ref")
}

///|
test "enum cannot be empty" {
  let errors = checked_errors("{\"enum\":[]}")
  assert_eq(errors[0].code(), @moonjtd.EmptyEnum)
}

///|
test "enum values must be unique" {
  let errors = checked_errors("{\"enum\":[\"x\",\"y\",\"x\"]}")
  assert_eq(errors[0].code(), @moonjtd.DuplicateEnumValue)
  assert_eq(errors[0].schema_path().to_string(), "/enum/2")
}

///|
test "required and optional property names cannot overlap" {
  let errors = checked_errors(
    "{\"properties\":{\"name\":{\"type\":\"string\"}},\"optionalProperties\":{\"name\":{\"type\":\"string\"}}}",
  )
  assert_eq(errors[0].code(), @moonjtd.PropertyOverlap)
}

///|
test "mapping branch cannot redeclare discriminator" {
  let errors = checked_errors(
    "{\"discriminator\":\"kind\",\"mapping\":{\"circle\":{\"properties\":{\"kind\":{\"type\":\"string\"}}}}}",
  )
  assert_eq(errors[0].code(), @moonjtd.DuplicateDiscriminatorProperty)
}

///|
test "parse checked schema combines phases" {
  guard @moonjtd.parse_checked_schema("{\"ref\":\"missing\"}") is Err(errors) else {
    abort("expected semantic errors")
  }
  assert_eq(errors[0].code(), @moonjtd.UnknownReference)
}

///|
test "invalid limits fail closed" {
  let document = match @moonjtd.parse_schema("{}") {
    Ok(value) => value
    Err(_) => abort("parse")
  }
  let errors = @moonjtd.check_schema_with(
    document,
    @moonjtd.SchemaCheckOptions::new(max_nodes=0),
  )
  assert_eq(errors[0].code(), @moonjtd.ResourceLimitExceeded)
}
