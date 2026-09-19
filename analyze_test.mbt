///|
test "schema analysis counts forms and properties" {
  let document = match
    @moonjtd.parse_checked_schema(
      "{\"definitions\":{\"id\":{\"type\":\"uint32\"}},\"properties\":{\"id\":{\"ref\":\"id\"},\"tags\":{\"elements\":{\"type\":\"string\"}}},\"optionalProperties\":{\"meta\":{\"values\":{}}}}",
    ) {
    Ok(value) => value
    Err(_) => abort("schema")
  }
  let stats = @moonjtd.analyze_schema(document)
  assert_eq(stats.definition_count(), 1)
  assert_eq(stats.reference_count(), 1)
  assert_eq(stats.properties_count(), 1)
  assert_eq(stats.elements_count(), 1)
  assert_eq(stats.values_count(), 1)
  assert_eq(stats.required_property_count(), 2)
  assert_eq(stats.optional_property_count(), 1)
  assert_true(stats.node_count() >= 7)
}

///|
test "reference inventory includes definition-to-definition edges" {
  let document = match
    @moonjtd.parse_checked_schema(
      "{\"definitions\":{\"a\":{\"ref\":\"b\"},\"b\":{\"type\":\"string\"}},\"ref\":\"a\"}",
    ) {
    Ok(value) => value
    Err(_) => abort("schema")
  }
  let refs = @moonjtd.referenced_definitions(document)
  assert_true(refs.contains("a"))
  assert_true(refs.contains("b"))
  assert_eq(@moonjtd.unused_definitions(document).length(), 0)
}

///|
test "unused definitions are found transitively" {
  let document = match
    @moonjtd.parse_checked_schema(
      "{\"definitions\":{\"used\":{\"type\":\"string\"},\"unused\":{\"type\":\"boolean\"}},\"ref\":\"used\"}",
    ) {
    Ok(value) => value
    Err(_) => abort("schema")
  }
  assert_eq(@moonjtd.unused_definitions(document), ["unused"])
  let lint = @moonjtd.lint_schema(document)
  assert_eq(lint.length(), 1)
  assert_true(lint[0].message().contains("never reached"))
}

///|
test "stats render compact report" {
  let document = match @moonjtd.parse_checked_schema("{\"type\":\"string\"}") {
    Ok(value) => value
    Err(_) => abort("schema")
  }
  let report = @moonjtd.analyze_schema(document).to_string()
  assert_true(report.contains("nodes=1"))
  assert_true(report.contains("type:1"))
}
