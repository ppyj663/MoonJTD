///|
test "version banner identifies specification" {
  assert_eq(@moonjtd.version_banner(), "MoonJTD 0.1.0 (RFC 8927)")
}

///|
test "json pointer follows RFC 6901 escaping" {
  let pointer = @moonjtd.JsonPointer::root()
    .property("definitions")
    .property("a/b~c")
    .index(2)
  assert_eq(pointer.to_string(), "/definitions/a~1b~0c/2")
  assert_eq(pointer.depth(), 3)
  assert_eq(pointer.last_index(), Some(2))
}

///|
test "schema constructors preserve forms" {
  let schema = @moonjtd.Schema::type_(@moonjtd.Int16Type).with_nullable(true)
  assert_eq(schema.form_name(), "type")
  assert_eq(schema.type_kind(), Some(@moonjtd.Int16Type))
  assert_true(schema.is_nullable())
}

///|
test "document resolves named definitions" {
  let definitions = Map([("name", @moonjtd.Schema::type_(@moonjtd.StringType))])
  let document = @moonjtd.SchemaDocument::new(
    @moonjtd.Schema::reference("name"),
    definitions~,
  )
  assert_true(document.has_definition("name"))
  assert_eq(document.definition_count(), 1)
  guard document.definition("name") is Some(schema) else { fail("missing") }
  assert_eq(schema.form_name(), "type")
}
