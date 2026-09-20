///|
fn validation_document(text : StringView) -> @moonjtd.SchemaDocument {
  match @moonjtd.parse_checked_schema(text) {
    Ok(document) => document
    Err(_) => abort("invalid test schema")
  }
}

///|
fn validation_errors(
  schema : StringView,
  instance : StringView,
) -> Array[@moonjtd.Diagnostic] {
  let document = validation_document(schema)
  match @moonjtd.validate_json_text(document, instance) {
    Ok(errors) => errors
    Err(_) => abort("invalid test instance JSON")
  }
}

///|
test "empty form accepts every JSON kind" {
  let document = validation_document("{}")
  let values = [
    Json::null(),
    Json::boolean(true),
    Json::number(1.0),
    Json::string("x"),
    Json::array([]),
    Json::object(Map([])),
  ]
  for value in values {
    assert_eq(@moonjtd.validate(document, value).length(), 0)
  }
}

///|
test "nullable short circuits non-empty forms" {
  assert_eq(
    validation_errors("{\"type\":\"string\",\"nullable\":true}", "null").length(),
    0,
  )
  assert_eq(
    validation_errors("{\"type\":\"string\"}", "null")[0].code(),
    @moonjtd.ValidationMismatch,
  )
}

///|
test "primitive type errors carry standard paths" {
  let errors = validation_errors("{\"type\":\"uint8\"}", "256")
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].instance_path().to_string(), "")
  assert_eq(errors[0].schema_path().to_string(), "/type")
}

///|
test "enum accepts members and rejects other values" {
  assert_eq(
    validation_errors("{\"enum\":[\"red\",\"blue\"]}", "\"red\"").length(),
    0,
  )
  assert_eq(
    validation_errors("{\"enum\":[\"red\",\"blue\"]}", "\"green\"")[0].code(),
    @moonjtd.ValidationMismatch,
  )
}

///|
test "elements reports array index" {
  let errors = validation_errors(
    "{\"elements\":{\"type\":\"boolean\"}}", "[true,false,0]",
  )
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].instance_path().to_string(), "/2")
  assert_eq(errors[0].schema_path().to_string(), "/elements/type")
}

///|
test "values validates every object member" {
  let errors = validation_errors(
    "{\"values\":{\"type\":\"int8\"}}", "{\"ok\":1,\"bad\":200}",
  )
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].instance_path().to_string(), "/bad")
}

///|
test "properties checks required optional and additional members" {
  let schema = "{\"properties\":{\"id\":{\"type\":\"uint32\"}},\"optionalProperties\":{\"name\":{\"type\":\"string\"}}}"
  assert_eq(
    validation_errors(schema, "{\"id\":1,\"name\":\"Ada\"}").length(),
    0,
  )
  let missing = validation_errors(schema, "{}")
  assert_eq(missing[0].code(), @moonjtd.MissingProperty)
  let additional = validation_errors(schema, "{\"id\":1,\"extra\":true}")
  assert_eq(additional[0].code(), @moonjtd.AdditionalProperty)
  assert_eq(additional[0].instance_path().to_string(), "/extra")
}

///|
test "additionalProperties permits unknown members" {
  let errors = validation_errors(
    "{\"optionalProperties\":{},\"additionalProperties\":true}", "{\"anything\":42}",
  )
  assert_eq(errors.length(), 0)
}

///|
test "refs resolve through root definitions" {
  let errors = validation_errors(
    "{\"definitions\":{\"id\":{\"type\":\"uint16\"}},\"ref\":\"id\"}", "70000",
  )
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].schema_path().to_string(), "/definitions/id/type")
}

///|
test "discriminator selects branch and treats tag as implicit" {
  let schema = "{\"discriminator\":\"kind\",\"mapping\":{\"circle\":{\"properties\":{\"radius\":{\"type\":\"float64\"}}},\"point\":{\"properties\":{\"x\":{\"type\":\"float64\"},\"y\":{\"type\":\"float64\"}}}}}"
  assert_eq(
    validation_errors(schema, "{\"kind\":\"circle\",\"radius\":2.5}").length(),
    0,
  )
  let errors = validation_errors(schema, "{\"kind\":\"point\",\"x\":1}")
  assert_eq(errors[0].code(), @moonjtd.MissingProperty)
  assert_eq(errors[0].schema_path().to_string(), "/mapping/point/properties/y")
}

///|
test "discriminator rejects missing non-string and unknown tags" {
  let schema = "{\"discriminator\":\"kind\",\"mapping\":{\"x\":{\"properties\":{}}}}"
  assert_eq(
    validation_errors(schema, "{}")[0].code(),
    @moonjtd.InvalidDiscriminatorTag,
  )
  assert_eq(
    validation_errors(schema, "{\"kind\":1}")[0].code(),
    @moonjtd.InvalidDiscriminatorTag,
  )
  assert_eq(
    validation_errors(schema, "{\"kind\":\"y\"}")[0].code(),
    @moonjtd.UnknownDiscriminatorValue,
  )
}

///|
test "maximum error count truncates deterministic traversal" {
  let document = validation_document("{\"elements\":{\"type\":\"boolean\"}}")
  let report = @moonjtd.validate_with(
    document,
    Json::array([Json::number(1.0), Json::number(2.0), Json::number(3.0)]),
    @moonjtd.ValidationOptions::new(max_errors=2),
  )
  assert_eq(report.errors().length(), 2)
}

///|
test "reference depth is bounded" {
  let document = validation_document(
    "{\"definitions\":{\"loop\":{\"ref\":\"loop\"}},\"ref\":\"loop\"}",
  )
  let report = @moonjtd.validate_with(
    document,
    Json::null(),
    @moonjtd.ValidationOptions::new(max_ref_depth=3),
  )
  assert_eq(report.errors()[0].code(), @moonjtd.ResourceLimitExceeded)
  assert_true(report.is_truncated())
}

///|
test "invalid validation options fail closed" {
  let report = @moonjtd.validate_with(
    validation_document("{}"),
    Json::null(),
    @moonjtd.ValidationOptions::new(max_nodes=0),
  )
  assert_false(report.is_valid())
  assert_true(report.is_truncated())
}
