///|
test "schema JSON round trips all forms" {
  let source = "{\"definitions\":{\"id\":{\"type\":\"uint32\"}},\"properties\":{\"id\":{\"ref\":\"id\"},\"items\":{\"elements\":{\"enum\":[\"a\",\"b\"]}}},\"optionalProperties\":{\"meta\":{\"values\":{\"type\":\"string\"}}},\"additionalProperties\":true,\"nullable\":true,\"metadata\":{\"title\":\"Root\"}}"
  let document = match @moonjtd.parse_checked_schema(source) {
    Ok(value) => value
    Err(_) => abort("source")
  }
  let rendered = @moonjtd.schema_to_string(document)
  let reparsed = match @moonjtd.parse_checked_schema(rendered) {
    Ok(value) => value
    Err(_) => abort("rendered")
  }
  assert_eq(reparsed.definition_count(), 1)
  assert_eq(reparsed.root().form_name(), "properties")
  assert_true(reparsed.root().is_nullable())
}

///|
test "pretty schema renderer is readable and parseable" {
  let document = match
    @moonjtd.parse_checked_schema(
      "{\"discriminator\":\"kind\",\"mapping\":{\"ready\":{\"properties\":{}}}}",
    ) {
    Ok(value) => value
    Err(_) => abort("source")
  }
  let pretty = @moonjtd.schema_to_pretty_string(document, indent=4)
  assert_true(pretty.contains("\n"))
  assert_true(pretty.contains("    \"discriminator\""))
  assert_true(@moonjtd.parse_checked_schema(pretty) is Ok(_))
}

///|
test "shape summaries describe nesting" {
  let document = match
    @moonjtd.parse_checked_schema(
      "{\"elements\":{\"values\":{\"type\":\"boolean\"}}}",
    ) {
    Ok(value) => value
    Err(_) => abort("source")
  }
  assert_eq(@moonjtd.schema_shape(document.root()), "array<map<boolean>>")
}
