///|
fn string_array_json(values : Array[String]) -> Json {
  Json::array(values.map(value => Json::string(value)))
}

///|
fn schema_map_json(schemas : Map[String, Schema]) -> Json {
  let object : Map[String, Json] = Map([])
  for name, schema in schemas {
    object.set(name, schema_to_json_node(schema))
  }
  Json::object(object)
}

///|
fn add_shared_members(schema : Schema, object : Map[String, Json]) -> Unit {
  if schema.is_nullable() {
    object.set("nullable", Json::boolean(true))
  }
  let metadata = schema.metadata()
  if !metadata.is_empty() {
    object.set("metadata", Json::object(metadata))
  }
}

///|
fn properties_form_json(
  required : Map[String, Schema],
  optional : Map[String, Schema],
  additional : Bool,
  object : Map[String, Json],
) -> Unit {
  if !required.is_empty() || optional.is_empty() {
    object.set("properties", schema_map_json(required))
  }
  if !optional.is_empty() {
    object.set("optionalProperties", schema_map_json(optional))
  }
  if additional {
    object.set("additionalProperties", Json::boolean(true))
  }
}

///|
fn discriminator_mapping_json(mapping : Map[String, Schema]) -> Json {
  let object : Map[String, Json] = Map([])
  for name, schema in mapping {
    object.set(name, schema_to_json_node(schema))
  }
  Json::object(object)
}

///|
fn schema_to_json_node(schema : Schema) -> Json {
  let object : Map[String, Json] = Map([])
  match schema.form() {
    EmptyForm => ()
    RefForm(name) => object.set("ref", Json::string(name))
    TypeForm(kind) => object.set("type", Json::string(kind.name()))
    EnumForm(values) => object.set("enum", string_array_json(values))
    ElementsForm(element) =>
      object.set("elements", schema_to_json_node(element))
    PropertiesForm(required, optional, additional) =>
      properties_form_json(required, optional, additional, object)
    ValuesForm(value) => object.set("values", schema_to_json_node(value))
    DiscriminatorForm(tag, mapping) => {
      object.set("discriminator", Json::string(tag))
      object.set("mapping", discriminator_mapping_json(mapping))
    }
  }
  add_shared_members(schema, object)
  Json::object(object)
}

///|
/// Convert a schema document into its JSON data model.
pub fn schema_to_json(document : SchemaDocument) -> Json {
  guard schema_to_json_node(document.root()) is Object(root) else {
    abort("schema serialization invariant")
  }
  let definitions = document.definitions()
  if !definitions.is_empty() {
    root.set("definitions", schema_map_json(definitions))
  }
  Json::object(root)
}

///|
/// Serialize a schema document as compact JSON.
pub fn schema_to_string(document : SchemaDocument) -> String {
  schema_to_json(document).stringify(escape_slash=false)
}

///|
fn write_indent(output : StringBuilder, depth : Int, width : Int) -> Unit {
  for index = 0; index < depth * width; index = index + 1 {
    output.write_char(' ')
  }
}

///|
fn write_json_string(output : StringBuilder, value : String) -> Unit {
  output.write_string(Json::string(value).stringify(escape_slash=false))
}

///|
fn write_pretty_array(
  output : StringBuilder,
  values : Array[Json],
  depth : Int,
  width : Int,
) -> Unit {
  if values.is_empty() {
    output.write_string("[]")
    return
  }
  output.write_string("[\n")
  for index, value in values {
    write_indent(output, depth + 1, width)
    write_pretty_json(output, value, depth + 1, width)
    if index + 1 < values.length() {
      output.write_char(',')
    }
    output.write_char('\n')
  }
  write_indent(output, depth, width)
  output.write_char(']')
}

///|
fn write_pretty_object(
  output : StringBuilder,
  object : Map[String, Json],
  depth : Int,
  width : Int,
) -> Unit {
  if object.is_empty() {
    output.write_string("{}")
    return
  }
  output.write_string("{\n")
  let mut index = 0
  for name, value in object {
    write_indent(output, depth + 1, width)
    write_json_string(output, name)
    output.write_string(": ")
    write_pretty_json(output, value, depth + 1, width)
    index += 1
    if index < object.length() {
      output.write_char(',')
    }
    output.write_char('\n')
  }
  write_indent(output, depth, width)
  output.write_char('}')
}

///|
fn write_pretty_json(
  output : StringBuilder,
  value : Json,
  depth : Int,
  width : Int,
) -> Unit {
  match value {
    Array(values) => write_pretty_array(output, values, depth, width)
    Object(object) => write_pretty_object(output, object, depth, width)
    other => output.write_string(other.stringify(escape_slash=false))
  }
}

///|
/// Render indented JSON without depending on host filesystem or console APIs.
pub fn schema_to_pretty_string(
  document : SchemaDocument,
  indent? : Int = 2,
) -> String {
  let width = if indent < 0 { 0 } else { indent }
  let output = StringBuilder()
  write_pretty_json(output, schema_to_json(document), 0, width)
  output.to_string()
}

///|
/// Return a deep structural form signature useful in reports and tests.
pub fn schema_shape(schema : Schema) -> String {
  match schema.form() {
    EmptyForm => "any"
    RefForm(name) => "ref(" + name + ")"
    TypeForm(kind) => kind.name()
    EnumForm(values) => "enum[" + values.length().to_string() + "]"
    ElementsForm(element) => "array<" + schema_shape(element) + ">"
    ValuesForm(value) => "map<" + schema_shape(value) + ">"
    PropertiesForm(required, optional, additional) => {
      let suffix = if additional { ",open" } else { ",closed" }
      "object[required=" +
      required.length().to_string() +
      ",optional=" +
      optional.length().to_string() +
      suffix +
      "]"
    }
    DiscriminatorForm(tag, mapping) =>
      "union[tag=" + tag + ",branches=" + mapping.length().to_string() + "]"
  }
}
