///|
/// A JSON value proven valid against the codec's JTD document at decode time.
pub(all) struct ValidatedJson {
  value : Json
} derive(Eq, Debug)

///|
pub fn ValidatedJson::value(self : ValidatedJson) -> Json {
  self.value
}

///|
pub fn ValidatedJson::stringify(
  self : ValidatedJson,
  escape_slash? : Bool = false,
) -> String {
  self.value.stringify(escape_slash~)
}

///|
pub(all) suberror CodecError {
  CodecInvalidSchema(Array[Diagnostic])
  CodecInvalidJson(String)
  CodecValidationFailed(Array[Diagnostic])
} derive(Eq, Debug)

///|
/// Schema-bound JSON codec with the same resource limits as direct validation.
pub(all) struct JtdCodec {
  document : SchemaDocument
  options : ValidationOptions
} derive(Debug)

///|
pub fn JtdCodec::new(
  document : SchemaDocument,
  options? : ValidationOptions = ValidationOptions::default(),
) -> Result[JtdCodec, CodecError] {
  let schema_errors = check_schema(document)
  if !schema_errors.is_empty() {
    Err(CodecInvalidSchema(schema_errors))
  } else {
    Ok({ document, options, })
  }
}

///|
pub fn JtdCodec::document(self : JtdCodec) -> SchemaDocument {
  self.document
}

///|
pub fn JtdCodec::options(self : JtdCodec) -> ValidationOptions {
  self.options
}

///|
/// Validate an already parsed JSON value and wrap it on success.
pub fn JtdCodec::decode_json(
  self : JtdCodec,
  value : Json,
) -> Result[ValidatedJson, CodecError] {
  let report = validate_with(self.document, value, self.options)
  if report.is_valid() {
    Ok({ value, })
  } else {
    Err(CodecValidationFailed(report.errors()))
  }
}

///|
/// Parse JSON text, validate it, and return only a schema-conforming value.
pub fn JtdCodec::decode(
  self : JtdCodec,
  text : StringView,
) -> Result[ValidatedJson, CodecError] {
  let value = @json.parse(text) catch {
    error => return Err(CodecInvalidJson(error.to_string()))
  }
  self.decode_json(value)
}

///|
/// Validate a JSON value before serializing it.
pub fn JtdCodec::encode_json(
  self : JtdCodec,
  value : Json,
  escape_slash? : Bool = false,
) -> Result[String, CodecError] {
  match self.decode_json(value) {
    Ok(validated) => Ok(validated.stringify(escape_slash~))
    Err(error) => Err(error)
  }
}

///|
/// A previously validated value can be serialized without another traversal.
pub fn JtdCodec::encode_validated(
  self : JtdCodec,
  value : ValidatedJson,
  escape_slash? : Bool = false,
) -> String {
  ignore(self)
  value.stringify(escape_slash~)
}

///|
/// Decode multiple independent JSON values, preserving input order.
pub fn JtdCodec::decode_batch(
  self : JtdCodec,
  values : Array[Json],
) -> Array[Result[ValidatedJson, CodecError]] {
  values.map(value => self.decode_json(value))
}

///|
/// Decode a JSON array and validate each element as a separate root instance.
pub fn JtdCodec::decode_json_array(
  self : JtdCodec,
  text : StringView,
) -> Result[Array[ValidatedJson], CodecError] {
  let value = @json.parse(text) catch {
    error => return Err(CodecInvalidJson(error.to_string()))
  }
  guard value is Array(values) else {
    return Err(
      CodecInvalidJson("batch input must be a JSON array of root instances"),
    )
  }
  let output : Array[ValidatedJson] = []
  let diagnostics : Array[Diagnostic] = []
  for index, item in values {
    match self.decode_json(item) {
      Ok(validated) => output.push(validated)
      Err(CodecValidationFailed(errors)) =>
        for diagnostic in errors {
          let prefixed = JsonPointer::root()
            .index(index)
            .append(diagnostic.instance_path())
          diagnostics.push(
            Diagnostic::new(
              diagnostic.code(),
              diagnostic.message(),
              instance_path=prefixed,
              schema_path=diagnostic.schema_path(),
            ),
          )
        }
      Err(error) => return Err(error)
    }
  }
  if diagnostics.is_empty() {
    Ok(output)
  } else {
    Err(CodecValidationFailed(diagnostics))
  }
}

///|
pub fn codec_from_schema(
  schema_text : StringView,
  options? : ValidationOptions = ValidationOptions::default(),
) -> Result[JtdCodec, CodecError] {
  let document = match parse_checked_schema(schema_text) {
    Ok(value) => value
    Err(errors) => return Err(CodecInvalidSchema(errors))
  }
  JtdCodec::new(document, options~)
}

///|
pub fn codec_error_diagnostics(error : CodecError) -> Array[Diagnostic] {
  match error {
    CodecInvalidSchema(errors) | CodecValidationFailed(errors) => errors
    CodecInvalidJson(message) => [Diagnostic::new(InvalidJson, message)]
  }
}

///|
pub fn codec_error_message(error : CodecError) -> String {
  match error {
    CodecInvalidJson(message) => "invalid JSON: " + message
    CodecInvalidSchema(errors) =>
      "invalid JTD schema with " + errors.length().to_string() + " finding(s)"
    CodecValidationFailed(errors) =>
      "JSON instance failed JTD validation with " +
      errors.length().to_string() +
      " finding(s)"
  }
}
