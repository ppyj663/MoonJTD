///|
fn report_document() -> @moonjtd.SchemaDocument {
  match
    @moonjtd.parse_checked_schema(
      "{\"definitions\":{\"id\":{\"type\":\"uint32\"},\"unused\":{}},\"properties\":{\"id\":{\"ref\":\"id\"}},\"optionalProperties\":{\"name\":{\"type\":\"string\"}}}",
    ) {
    Ok(value) => value
    Err(_) => abort("schema")
  }
}

///|
test "schema inventory reports exact paths" {
  let inventory = @moonjtd.schema_inventory(report_document())
  assert_true(inventory.length() >= 5)
  assert_eq(inventory[0].path().to_string(), "")
  assert_eq(inventory[0].form(), "properties")
  let mut found_id = false
  for info in inventory {
    if info.path().to_string() == "/properties/id" {
      found_id = true
      assert_eq(info.form(), "ref")
    }
  }
  assert_true(found_id)
}

///|
test "diagnostic JSON uses RFC field names" {
  let diagnostic = @moonjtd.Diagnostic::new(
    @moonjtd.ValidationMismatch,
    "bad",
    instance_path=@moonjtd.JsonPointer::root().property("value"),
    schema_path=@moonjtd.JsonPointer::root().property("type"),
  )
  let text = @moonjtd.diagnostics_to_string([diagnostic])
  assert_true(text.contains("instancePath"))
  assert_true(text.contains("/value"))
  assert_true(text.contains("/type"))
}

///|
test "schema JSON report includes statistics and lint" {
  let text = @moonjtd.schema_report_string(report_document())
  assert_true(text.contains("\"statistics\""))
  assert_true(text.contains("\"nodeCount\""))
  assert_true(text.contains("unusedDefinitions"))
  assert_true(text.contains("unused"))
}

///|
test "markdown report includes inventory table" {
  let text = @moonjtd.schema_report_markdown(report_document())
  assert_true(text.contains("# MoonJTD schema report"))
  assert_true(text.contains("| Path | Form |"))
  assert_true(text.contains("/properties/id"))
  assert_true(text.contains("never reached"))
}

///|
test "validation report JSON exposes bounded execution" {
  let report = @moonjtd.validate_with(
    report_document(),
    Json::object(Map([])),
    @moonjtd.ValidationOptions::default(),
  )
  let text = @moonjtd.validation_report_to_json(report).stringify()
  assert_true(text.contains("visitedNodes"))
  assert_true(text.contains("missing-property"))
}
