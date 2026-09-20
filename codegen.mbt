///|
/// Controls naming and visibility of generated MoonBit declarations.
pub(all) struct CodegenOptions {
  root_name : String
  public_types : Bool
  derive_eq : Bool
  derive_debug : Bool
  header : Bool
} derive(Eq, Debug)

///|
pub fn CodegenOptions::new(
  root_name? : String = "Root",
  public_types? : Bool = true,
  derive_eq? : Bool = true,
  derive_debug? : Bool = true,
  header? : Bool = true,
) -> CodegenOptions {
  { root_name, public_types, derive_eq, derive_debug, header, }
}

///|
pub fn CodegenOptions::default() -> CodegenOptions {
  CodegenOptions::new()
}

///|
pub fn CodegenOptions::root_name(self : CodegenOptions) -> String {
  self.root_name
}

///|
fn ascii_letter(code : Int) -> Bool {
  (code >= 65 && code <= 90) || (code >= 97 && code <= 122)
}

///|
fn ascii_digit(code : Int) -> Bool {
  code >= 48 && code <= 57
}

///|
fn ascii_identifier_char(code : Int) -> Bool {
  ascii_letter(code) || ascii_digit(code) || code == 95
}

///|
fn ascii_upper(character : Char) -> Char {
  let code = character.to_int()
  if code >= 97 && code <= 122 {
    (code - 32).unsafe_to_char()
  } else {
    character
  }
}

///|
fn ascii_lower(character : Char) -> Char {
  let code = character.to_int()
  if code >= 65 && code <= 90 {
    (code + 32).unsafe_to_char()
  } else {
    character
  }
}

///|
fn moon_keyword(name : String) -> Bool {
  match name {
    "as"
    | "async"
    | "break"
    | "const"
    | "continue"
    | "derive"
    | "else"
    | "enum"
    | "extern"
    | "fn"
    | "for"
    | "guard"
    | "if"
    | "impl"
    | "in"
    | "let"
    | "loop"
    | "match"
    | "mut"
    | "priv"
    | "pub"
    | "raise"
    | "return"
    | "struct"
    | "suberror"
    | "test"
    | "trait"
    | "type"
    | "typealias"
    | "using"
    | "while"
    | "with" => true
    _ => false
  }
}

///|
fn words_from_identifier(name : String) -> Array[String] {
  let words : Array[String] = []
  let mut current = StringBuilder()
  let mut current_length = 0
  for character in name {
    let code = character.to_int()
    if ascii_identifier_char(code) && code != 95 {
      current.write_char(character)
      current_length += 1
    } else if current_length > 0 {
      words.push(current.to_string())
      current = StringBuilder()
      current_length = 0
    }
  }
  if current_length > 0 {
    words.push(current.to_string())
  }
  words
}

///|
fn pascal_word(word : String) -> String {
  if word.is_empty() {
    return ""
  }
  let output = StringBuilder()
  for index, character in word {
    if index == 0 {
      output.write_char(ascii_upper(character))
    } else {
      output.write_char(character)
    }
  }
  output.to_string()
}

///|
/// Convert an arbitrary schema name to a valid exported MoonBit type name.
pub fn moon_type_name(name : String) -> String {
  let words = words_from_identifier(name)
  let output = StringBuilder()
  for word in words {
    output.write_string(pascal_word(word))
  }
  let value = output.to_string()
  if value.is_empty() {
    "GeneratedType"
  } else if ascii_digit(value[0].to_int()) {
    "T" + value
  } else if moon_keyword(value) {
    value + "Type"
  } else {
    value
  }
}

///|
/// Convert an arbitrary property name to a safe MoonBit field identifier.
pub fn moon_field_name(name : String) -> String {
  let words = words_from_identifier(name)
  if words.is_empty() {
    return "field"
  }
  let output = StringBuilder()
  for word_index, word in words {
    for character_index, character in word {
      if word_index == 0 {
        output.write_char(ascii_lower(character))
      } else if character_index == 0 {
        output.write_char(ascii_upper(character))
      } else {
        output.write_char(character)
      }
    }
  }
  let value = output.to_string()
  let prefixed = if ascii_digit(value[0].to_int()) {
    "field" + value
  } else {
    value
  }
  if moon_keyword(prefixed) {
    prefixed + "_"
  } else {
    prefixed
  }
}

///|
fn generated_visibility(options : CodegenOptions) -> String {
  if options.public_types {
    "pub(all) "
  } else {
    ""
  }
}

///|
fn generated_derives(options : CodegenOptions) -> String {
  let values : Array[String] = []
  if options.derive_eq {
    values.push("Eq")
  }
  if options.derive_debug {
    values.push("Debug")
  }
  if values.is_empty() {
    return ""
  }
  let output = StringBuilder()
  output.write_string(" derive(")
  for index, value in values {
    if index > 0 {
      output.write_string(", ")
    }
    output.write_string(value)
  }
  output.write_char(')')
  output.to_string()
}

///|
fn scalar_moon_type(kind : JtdType) -> String {
  match kind {
    BooleanType => "Bool"
    Float32Type => "Float"
    Float64Type => "Double"
    Int8Type | Int16Type | Int32Type => "Int"
    Uint8Type | Uint16Type | Uint32Type => "UInt"
    StringType | TimestampType => "String"
  }
}

///|
fn nullable_type(type_name : String, nullable : Bool) -> String {
  if nullable {
    type_name + "?"
  } else {
    type_name
  }
}

///|
fn inline_moon_type(schema : Schema, fallback_name : String) -> String {
  let value = match schema.form() {
    EmptyForm => "Json"
    RefForm(name) => moon_type_name(name)
    TypeForm(kind) => scalar_moon_type(kind)
    EnumForm(_) => fallback_name
    ElementsForm(element) =>
      "Array[" + inline_moon_type(element, fallback_name + "Item") + "]"
    ValuesForm(element) =>
      "Map[String, " + inline_moon_type(element, fallback_name + "Value") + "]"
    PropertiesForm(_, _, _) | DiscriminatorForm(_, _) => fallback_name
  }
  nullable_type(value, schema.is_nullable())
}

///|
fn write_header(output : StringBuilder) -> Unit {
  output.write_string("// Generated by MoonJTD. DO NOT EDIT.\n")
  output.write_string("// Source schema: RFC 8927 JSON Type Definition.\n\n")
}

///|
fn write_alias(
  output : StringBuilder,
  name : String,
  target : String,
  options : CodegenOptions,
) -> Unit {
  output.write_string(generated_visibility(options))
  output.write_string("typealias ")
  output.write_string(name)
  output.write_string(" = ")
  output.write_string(target)
  output.write_string("\n\n")
}

///|
fn write_enum(
  output : StringBuilder,
  name : String,
  values : Array[String],
  options : CodegenOptions,
) -> Unit {
  output.write_string(generated_visibility(options))
  output.write_string("enum ")
  output.write_string(name)
  output.write_string(" {\n")
  let seen : Map[String, Int] = Map([])
  for value in values {
    let base = moon_type_name(value)
    let count = match seen.get(base) {
      Some(n) => n + 1
      None => 1
    }
    seen.set(base, count)
    let variant = if count == 1 { base } else { base + count.to_string() }
    output.write_string("  ")
    output.write_string(variant)
    output.write_string("\n")
  }
  output.write_char('}')
  output.write_string(generated_derives(options))
  output.write_string("\n\n")
}

///|
fn write_struct_field(
  output : StringBuilder,
  source_name : String,
  schema : Schema,
  optional : Bool,
  owner_name : String,
) -> Unit {
  let field_name = moon_field_name(source_name)
  let nested_name = owner_name + moon_type_name(source_name)
  let base_type = inline_moon_type(schema, nested_name)
  let field_type = if optional && !schema.is_nullable() {
    base_type + "?"
  } else {
    base_type
  }
  output.write_string("  ")
  output.write_string(field_name)
  output.write_string(" : ")
  output.write_string(field_type)
  output.write_string("\n")
}

///|
fn write_struct(
  output : StringBuilder,
  name : String,
  required : Map[String, Schema],
  optional : Map[String, Schema],
  options : CodegenOptions,
) -> Unit {
  output.write_string(generated_visibility(options))
  output.write_string("struct ")
  output.write_string(name)
  output.write_string(" {\n")
  for field_name, field_schema in required {
    write_struct_field(output, field_name, field_schema, false, name)
  }
  for field_name, field_schema in optional {
    write_struct_field(output, field_name, field_schema, true, name)
  }
  output.write_char('}')
  output.write_string(generated_derives(options))
  output.write_string("\n\n")
}

///|
fn write_nested_declarations(
  output : StringBuilder,
  owner_name : String,
  required : Map[String, Schema],
  optional : Map[String, Schema],
  options : CodegenOptions,
) -> Unit {
  for field_name, schema in required {
    write_declaration(
      output,
      owner_name + moon_type_name(field_name),
      schema,
      options,
    )
  }
  for field_name, schema in optional {
    write_declaration(
      output,
      owner_name + moon_type_name(field_name),
      schema,
      options,
    )
  }
}

///|
fn write_discriminator(
  output : StringBuilder,
  name : String,
  mapping : Map[String, Schema],
  options : CodegenOptions,
) -> Unit {
  for tag_value, branch in mapping {
    write_declaration(output, name + moon_type_name(tag_value), branch, options)
  }
  output.write_string(generated_visibility(options))
  output.write_string("enum ")
  output.write_string(name)
  output.write_string(" {\n")
  for tag_value, _ in mapping {
    let variant = moon_type_name(tag_value)
    output.write_string("  ")
    output.write_string(variant)
    output.write_char('(')
    output.write_string(name + variant)
    output.write_string(")\n")
  }
  output.write_char('}')
  output.write_string(generated_derives(options))
  output.write_string("\n\n")
}

///|
fn write_declaration(
  output : StringBuilder,
  name : String,
  schema : Schema,
  options : CodegenOptions,
) -> Unit {
  match schema.form() {
    EnumForm(values) => write_enum(output, name, values, options)
    PropertiesForm(required, optional, _) => {
      write_nested_declarations(output, name, required, optional, options)
      write_struct(output, name, required, optional, options)
    }
    DiscriminatorForm(_, mapping) =>
      write_discriminator(output, name, mapping, options)
    _ => write_alias(output, name, inline_moon_type(schema, name), options)
  }
}

///|
fn validate_codegen_options(options : CodegenOptions) -> Diagnostic? {
  if options.root_name.is_empty() {
    Some(Diagnostic::new(InvalidIdentifier, "root type name must not be empty"))
  } else if moon_type_name(options.root_name) == "GeneratedType" {
    Some(
      Diagnostic::new(
        InvalidIdentifier,
        "root type name must contain an ASCII letter or digit",
      ),
    )
  } else {
    None
  }
}

///|
/// Generate deterministic MoonBit type declarations for a checked JTD document.
pub fn generate_moonbit_types_with(
  document : SchemaDocument,
  options : CodegenOptions,
) -> Result[String, CodegenError] {
  match validate_codegen_options(options) {
    Some(diagnostic) => return Err(CodegenDiagnostic(diagnostic))
    None => ()
  }
  let schema_errors = check_schema(document)
  if !schema_errors.is_empty() {
    return Err(
      CodegenDiagnostic(
        Diagnostic::new(
          GenerationFailure,
          "cannot generate types from an invalid JTD schema: " +
          schema_errors[0].message(),
          schema_path=schema_errors[0].schema_path(),
        ),
      ),
    )
  }
  let output = StringBuilder()
  if options.header {
    write_header(output)
  }
  for name, schema in document.definitions() {
    write_declaration(output, moon_type_name(name), schema, options)
  }
  write_declaration(
    output,
    moon_type_name(options.root_name),
    document.root(),
    options,
  )
  Ok(output.to_string())
}

///|
pub fn generate_moonbit_types(
  document : SchemaDocument,
  root_name? : String = "Root",
) -> Result[String, CodegenError] {
  generate_moonbit_types_with(document, CodegenOptions::new(root_name~))
}
