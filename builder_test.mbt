///|
test "object builder creates checked properties schema" {
  let root = match
    @moonjtd.jtd_object()
    .required("id", @moonjtd.jtd_uint32())
    .optional("name", @moonjtd.jtd_string())
    .allow_additional(false)
    .metadata_entry("title", Json::string("User"))
    .build() {
    Ok(value) => value
    Err(_) => abort("builder")
  }
  assert_eq(root.form_name(), "properties")
  assert_eq(root.metadata().get("title"), Some(Json::string("User")))
}

///|
test "object builder rejects overlapping properties" {
  let result = @moonjtd.jtd_object()
    .required("name", @moonjtd.jtd_string())
    .optional("name", @moonjtd.jtd_string())
    .build()
  assert_true(result is Err(_))
}

///|
test "discriminator builder validates branch forms" {
  let circle = match
    @moonjtd.jtd_object().required("radius", @moonjtd.jtd_float64()).build() {
    Ok(value) => value
    Err(_) => abort("branch")
  }
  let union = @moonjtd.jtd_union("kind").branch("circle", circle).build()
  assert_true(union is Ok(_))
  assert_true(
    @moonjtd.jtd_union("kind").branch("bad", @moonjtd.jtd_string()).build()
    is Err(_),
  )
}

///|
test "document builder resolves definitions" {
  let result = @moonjtd.jtd_document(@moonjtd.jtd_reference("id"))
    .definition("id", @moonjtd.jtd_uint32())
    .build()
  guard result is Ok(document) else { abort("document") }
  assert_true(document.has_definition("id"))
  assert_eq(@moonjtd.validate(document, Json::number(7.0)).length(), 0)
}

///|
test "document builder rejects missing refs" {
  let result = @moonjtd.jtd_document(@moonjtd.jtd_reference("missing")).build()
  guard result is Err(errors) else { abort("expected error") }
  assert_eq(errors[0].code(), @moonjtd.UnknownReference)
}
