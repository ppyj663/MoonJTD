///|
fn user_codec() -> @moonjtd.JtdCodec {
  match
    @moonjtd.codec_from_schema(
      "{\"properties\":{\"id\":{\"type\":\"uint32\"},\"name\":{\"type\":\"string\"}}}",
    ) {
    Ok(codec) => codec
    Err(_) => abort("codec")
  }
}

///|
test "codec decodes valid JSON text" {
  let codec = user_codec()
  guard codec.decode("{\"id\":7,\"name\":\"Ada\"}") is Ok(value) else {
    abort("decode")
  }
  assert_true(value.stringify().contains("Ada"))
}

///|
test "codec separates JSON parse and validation failures" {
  let codec = user_codec()
  guard codec.decode("{") is Err(parse_error) else { abort("parse") }
  assert_true(parse_error is @moonjtd.CodecInvalidJson(_))
  guard codec.decode("{\"id\":-1,\"name\":false}") is Err(error) else {
    abort("validation")
  }
  let diagnostics = @moonjtd.codec_error_diagnostics(error)
  assert_eq(diagnostics.length(), 2)
  assert_true(@moonjtd.codec_error_message(error).contains("2 finding"))
}

///|
test "codec validates before encoding" {
  let codec = user_codec()
  let valid = Json::object(
    Map([("id", Json::number(1.0)), ("name", Json::string("Grace"))]),
  )
  assert_true(codec.encode_json(valid) is Ok(_))
  assert_true(codec.encode_json(Json::object(Map([]))) is Err(_))
}

///|
test "batch array prefixes instance paths with input index" {
  let codec = user_codec()
  let input = "[{\"id\":1,\"name\":\"ok\"},{\"id\":-1,\"name\":\"bad\"}]"
  guard codec.decode_json_array(input) is Err(error) else { abort("batch") }
  let diagnostics = @moonjtd.codec_error_diagnostics(error)
  assert_eq(diagnostics.length(), 1)
  assert_eq(diagnostics[0].instance_path().to_string(), "/1/id")
}

///|
test "codec construction rejects invalid semantic schema" {
  guard @moonjtd.codec_from_schema("{\"ref\":\"missing\"}") is Err(error) else {
    abort("invalid schema")
  }
  assert_true(error is @moonjtd.CodecInvalidSchema(_))
}
