///|
fn parsed(text : StringView) -> @moonjtd.SchemaDocument {
  match @moonjtd.parse_schema(text) {
    Ok(document) => document
    Err(_) => abort("unexpected schema parse error")
  }
}

///|
fn parse_error_code(text : StringView) -> @moonjtd.DiagnosticCode {
  match @moonjtd.parse_schema(text) {
    Err(@moonjtd.SchemaDiagnostic(diagnostic)) => diagnostic.code()
    Ok(_) => abort("expected schema parse error")
  }
}

///|
test "parse empty form" {
  assert_eq(parsed("{}").root().form_name(), "empty")
}

///|
test "parse ref form and definitions" {
  let document = parsed(
    "{\"definitions\":{\"user\":{\"type\":\"string\"}},\"ref\":\"user\"}",
  )
  assert_eq(document.root().ref_name(), Some("user"))
  assert_true(document.has_definition("user"))
}

///|
test "parse all primitive names" {
  let names = [
    "boolean", "float32", "float64", "int8", "uint8", "int16", "uint16", "int32",
    "uint32", "string", "timestamp",
  ]
  for name in names {
    let document = parsed("{\"type\":\"" + name + "\"}")
    guard document.root().type_kind() is Some(kind) else { abort("type") }
    assert_eq(kind.name(), name)
  }
}

///|
test "parse enum form" {
  let document = parsed("{\"enum\":[\"red\",\"green\",\"blue\"]}")
  assert_eq(document.root().enum_values(), Some(["red", "green", "blue"]))
}

///|
test "parse elements and values forms" {
  let elements = parsed("{\"elements\":{\"type\":\"uint8\"}}").root()
  assert_eq(elements.form_name(), "elements")
  guard elements.element_schema() is Some(element) else { abort("element") }
  assert_eq(element.type_kind(), Some(@moonjtd.Uint8Type))
  let values = parsed("{\"values\":{\"type\":\"boolean\"}}").root()
  assert_eq(values.form_name(), "values")
}

///|
test "parse properties form" {
  let document = parsed(
    "{\"properties\":{\"id\":{\"type\":\"uint32\"}},\"optionalProperties\":{\"name\":{\"type\":\"string\"}},\"additionalProperties\":true}",
  )
  let root = document.root()
  assert_eq(root.form_name(), "properties")
  assert_true(root.allows_additional_properties())
  guard root.required_properties() is Some(required) else { abort("required") }
  assert_true(required.contains("id"))
}

///|
test "parse discriminator form" {
  let document = parsed(
    "{\"discriminator\":\"kind\",\"mapping\":{\"circle\":{\"properties\":{\"radius\":{\"type\":\"float64\"}}},\"point\":{\"properties\":{\"x\":{\"type\":\"float64\"},\"y\":{\"type\":\"float64\"}}}}}",
  )
  assert_eq(document.root().discriminator_tag(), Some("kind"))
  guard document.root().discriminator_mapping() is Some(mapping) else {
    abort("mapping")
  }
  assert_eq(mapping.length(), 2)
}

///|
test "parse nullable metadata" {
  let root = parsed(
    "{\"type\":\"string\",\"nullable\":true,\"metadata\":{\"title\":\"Name\"}}",
  ).root()
  assert_true(root.is_nullable())
  assert_true(root.metadata().contains("title"))
}

///|
test "reject unknown keyword" {
  assert_eq(
    parse_error_code("{\"type\":\"string\",\"vendorExtension\":42}"),
    @moonjtd.UnknownKeyword,
  )
}

///|
test "reject additionalProperties without properties form" {
  assert_eq(
    parse_error_code("{\"additionalProperties\":true}"),
    @moonjtd.InvalidMemberType,
  )
}

///|
test "reject additionalProperties mixed with another form" {
  assert_eq(
    parse_error_code("{\"elements\":{},\"additionalProperties\":true}"),
    @moonjtd.MixedSchemaForms,
  )
}

///|
test "reject mixed forms" {
  assert_eq(
    parse_error_code("{\"type\":\"string\",\"enum\":[\"x\"]}"),
    @moonjtd.MixedSchemaForms,
  )
}

///|
test "reject nested definitions" {
  assert_eq(
    parse_error_code(
      "{\"elements\":{\"definitions\":{\"x\":{}},\"ref\":\"x\"}}",
    ),
    @moonjtd.NestedDefinitions,
  )
}

///|
test "reject invalid primitive type" {
  assert_eq(parse_error_code("{\"type\":\"int64\"}"), @moonjtd.InvalidTypeName)
}

///|
test "reject discriminator branch without properties form" {
  assert_eq(
    parse_error_code(
      "{\"discriminator\":\"kind\",\"mapping\":{\"bad\":{\"type\":\"string\"}}}",
    ),
    @moonjtd.InvalidDiscriminatorMapping,
  )
}
