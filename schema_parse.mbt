///|
fn schema_error(
  code : DiagnosticCode,
  message : String,
  path : JsonPointer,
) -> SchemaError {
  SchemaDiagnostic(Diagnostic::new(code, message, schema_path=path))
}

///|
fn expect_object(
  value : Json,
  path : JsonPointer,
) -> Result[Map[String, Json], SchemaError] {
  match value {
    Object(object) => Ok(object)
    _ =>
      Err(
        schema_error(ExpectedObject, "JTD schema must be a JSON object", path),
      )
  }
}

///|
fn optional_boolean_member(
  object : Map[String, Json],
  name : String,
  default_value : Bool,
  path : JsonPointer,
) -> Result[Bool, SchemaError] {
  match object.get(name) {
    None => Ok(default_value)
    Some(True) => Ok(true)
    Some(False) => Ok(false)
    Some(_) =>
      Err(
        schema_error(
          InvalidMemberType,
          "member '" + name + "' must be a boolean",
          path.property(name),
        ),
      )
  }
}

///|
fn optional_metadata(
  object : Map[String, Json],
  path : JsonPointer,
) -> Result[Map[String, Json], SchemaError] {
  match object.get("metadata") {
    None => Ok(Map([]))
    Some(Object(metadata)) => Ok(metadata)
    Some(_) =>
      Err(
        schema_error(
          InvalidMemberType,
          "member 'metadata' must be an object",
          path.property("metadata"),
        ),
      )
  }
}

///|
fn required_string_member(
  object : Map[String, Json],
  name : String,
  path : JsonPointer,
) -> Result[String, SchemaError] {
  match object.get(name) {
    Some(String(value)) => Ok(value)
    Some(_) =>
      Err(
        schema_error(
          InvalidMemberType,
          "member '" + name + "' must be a string",
          path.property(name),
        ),
      )
    None =>
      Err(
        schema_error(
          InvalidMemberType,
          "missing required member '" + name + "'",
          path.property(name),
        ),
      )
  }
}

///|
fn form_keyword_count(object : Map[String, Json]) -> Int {
  let mut count = 0
  if object.contains("ref") {
    count += 1
  }
  if object.contains("type") {
    count += 1
  }
  if object.contains("enum") {
    count += 1
  }
  if object.contains("elements") {
    count += 1
  }
  if object.contains("properties") || object.contains("optionalProperties") {
    count += 1
  }
  if object.contains("values") {
    count += 1
  }
  if object.contains("discriminator") || object.contains("mapping") {
    count += 1
  }
  count
}

///|
fn parse_string_array(
  value : Json,
  path : JsonPointer,
) -> Result[Array[String], SchemaError] {
  guard value is Array(values) else {
    return Err(
      schema_error(InvalidMemberType, "expected an array of strings", path),
    )
  }
  let output : Array[String] = []
  for index, item in values {
    match item {
      String(text) => output.push(text)
      _ =>
        return Err(
          schema_error(
            InvalidMemberType,
            "enum value must be a string",
            path.index(index),
          ),
        )
    }
  }
  Ok(output)
}

///|
fn parse_schema_map(
  value : Json,
  path : JsonPointer,
  root : Bool,
) -> Result[Map[String, Schema], SchemaError] {
  guard value is Object(object) else {
    return Err(
      schema_error(InvalidMemberType, "expected an object of schemas", path),
    )
  }
  let output : Map[String, Schema] = Map([])
  for name, node in object {
    match parse_schema_node(node, path.property(name), root) {
      Ok(schema) => output.set(name, schema)
      Err(error) => return Err(error)
    }
  }
  Ok(output)
}

///|
fn parse_properties_form(
  object : Map[String, Json],
  path : JsonPointer,
) -> Result[SchemaForm, SchemaError] {
  let required = match object.get("properties") {
    None => Map([])
    Some(value) =>
      match parse_schema_map(value, path.property("properties"), false) {
        Ok(schemas) => schemas
        Err(error) => return Err(error)
      }
  }
  let optional = match object.get("optionalProperties") {
    None => Map([])
    Some(value) =>
      match
        parse_schema_map(value, path.property("optionalProperties"), false) {
        Ok(schemas) => schemas
        Err(error) => return Err(error)
      }
  }
  if !object.contains("properties") && !object.contains("optionalProperties") {
    return Err(
      schema_error(
        InvalidMemberType,
        "properties form requires properties or optionalProperties",
        path,
      ),
    )
  }
  let additional = match
    optional_boolean_member(object, "additionalProperties", false, path) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok(PropertiesForm(required, optional, additional))
}

///|
fn parse_discriminator_form(
  object : Map[String, Json],
  path : JsonPointer,
) -> Result[SchemaForm, SchemaError] {
  let tag = match required_string_member(object, "discriminator", path) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  guard object.get("mapping") is Some(Object(mapping_nodes)) else {
    return Err(
      schema_error(
        InvalidMemberType,
        "discriminator member 'mapping' must be an object",
        path.property("mapping"),
      ),
    )
  }
  let mapping : Map[String, Schema] = Map([])
  for name, node in mapping_nodes {
    let branch_path = path.property("mapping").property(name)
    let branch = match parse_schema_node(node, branch_path, false) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if branch.form_name() != "properties" {
      return Err(
        schema_error(
          InvalidDiscriminatorMapping,
          "each discriminator mapping value must use the properties form",
          branch_path,
        ),
      )
    }
    mapping.set(name, branch)
  }
  Ok(DiscriminatorForm(tag, mapping))
}

///|
fn parse_form(
  object : Map[String, Json],
  path : JsonPointer,
) -> Result[SchemaForm, SchemaError] {
  let forms = form_keyword_count(object)
  if forms > 1 {
    return Err(
      schema_error(
        MixedSchemaForms,
        "a JTD schema must use exactly one of the eight forms",
        path,
      ),
    )
  }
  if forms == 0 {
    return Ok(EmptyForm)
  }
  if object.contains("ref") {
    return match required_string_member(object, "ref", path) {
      Ok(name) => Ok(RefForm(name))
      Err(error) => Err(error)
    }
  }
  if object.contains("type") {
    let name = match required_string_member(object, "type", path) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    return match jtd_type_from_name(name) {
      Some(kind) => Ok(TypeForm(kind))
      None =>
        Err(
          schema_error(
            InvalidTypeName,
            "unknown JTD type '" + name + "'",
            path.property("type"),
          ),
        )
    }
  }
  if object.contains("enum") {
    guard object.get("enum") is Some(value) else { abort("unreachable") }
    return match parse_string_array(value, path.property("enum")) {
      Ok(values) => Ok(EnumForm(values))
      Err(error) => Err(error)
    }
  }
  if object.contains("elements") {
    guard object.get("elements") is Some(value) else { abort("unreachable") }
    return match parse_schema_node(value, path.property("elements"), false) {
      Ok(schema) => Ok(ElementsForm(schema))
      Err(error) => Err(error)
    }
  }
  if object.contains("properties") || object.contains("optionalProperties") {
    return parse_properties_form(object, path)
  }
  if object.contains("values") {
    guard object.get("values") is Some(value) else { abort("unreachable") }
    return match parse_schema_node(value, path.property("values"), false) {
      Ok(schema) => Ok(ValuesForm(schema))
      Err(error) => Err(error)
    }
  }
  parse_discriminator_form(object, path)
}

///|
fn parse_schema_node(
  value : Json,
  path : JsonPointer,
  root : Bool,
) -> Result[Schema, SchemaError] {
  let object = match expect_object(value, path) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if !root && object.contains("definitions") {
    return Err(
      schema_error(
        NestedDefinitions,
        "definitions may appear only on the root schema",
        path.property("definitions"),
      ),
    )
  }
  let nullable = match
    optional_boolean_member(object, "nullable", false, path) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let metadata = match optional_metadata(object, path) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match parse_form(object, path) {
    Ok(form) =>
      Ok(Schema::new(form).with_nullable(nullable).with_metadata(metadata))
    Err(error) => Err(error)
  }
}

///|
fn parse_root(value : Json) -> Result[SchemaDocument, SchemaError] {
  let root_path = JsonPointer::root()
  let object = match expect_object(value, root_path) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let root = match parse_schema_node(value, root_path, true) {
    Ok(schema) => schema
    Err(error) => return Err(error)
  }
  let definitions = match object.get("definitions") {
    None => Map([])
    Some(value) =>
      match parse_schema_map(value, root_path.property("definitions"), false) {
        Ok(schemas) => schemas
        Err(error) => return Err(error)
      }
  }
  Ok(SchemaDocument::new(root, definitions~))
}

///|
/// Parse a JSON value as a complete RFC 8927 schema document.
pub fn parse_schema_json(value : Json) -> Result[SchemaDocument, SchemaError] {
  parse_root(value)
}

///|
/// Parse UTF-8 JSON text as a complete RFC 8927 schema document.
pub fn parse_schema(text : StringView) -> Result[SchemaDocument, SchemaError] {
  let json = @json.parse(text) catch {
    error =>
      return Err(
        schema_error(
          InvalidJson,
          "invalid JSON: " + error.to_string(),
          JsonPointer::root(),
        ),
      )
  }
  parse_root(json)
}
