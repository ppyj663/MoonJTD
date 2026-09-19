///|
/// Primitive types defined by RFC 8927 section 2.2.3.
pub(all) enum JtdType {
  BooleanType
  Float32Type
  Float64Type
  Int8Type
  Uint8Type
  Int16Type
  Uint16Type
  Int32Type
  Uint32Type
  StringType
  TimestampType
} derive(Eq, Debug)

///|
pub fn JtdType::name(self : JtdType) -> String {
  match self {
    BooleanType => "boolean"
    Float32Type => "float32"
    Float64Type => "float64"
    Int8Type => "int8"
    Uint8Type => "uint8"
    Int16Type => "int16"
    Uint16Type => "uint16"
    Int32Type => "int32"
    Uint32Type => "uint32"
    StringType => "string"
    TimestampType => "timestamp"
  }
}

///|
pub fn JtdType::is_integer(self : JtdType) -> Bool {
  match self {
    Int8Type | Uint8Type | Int16Type | Uint16Type | Int32Type | Uint32Type =>
      true
    _ => false
  }
}

///|
pub fn JtdType::is_signed(self : JtdType) -> Bool {
  match self {
    Int8Type | Int16Type | Int32Type => true
    _ => false
  }
}

///|
pub fn JtdType::is_numeric(self : JtdType) -> Bool {
  self.is_integer() || self is Float32Type || self is Float64Type
}

///|
pub fn JtdType::minimum(self : JtdType) -> Double? {
  match self {
    Int8Type => Some(-128.0)
    Uint8Type => Some(0.0)
    Int16Type => Some(-32768.0)
    Uint16Type => Some(0.0)
    Int32Type => Some(-2147483648.0)
    Uint32Type => Some(0.0)
    _ => None
  }
}

///|
pub fn JtdType::maximum(self : JtdType) -> Double? {
  match self {
    Int8Type => Some(127.0)
    Uint8Type => Some(255.0)
    Int16Type => Some(32767.0)
    Uint16Type => Some(65535.0)
    Int32Type => Some(2147483647.0)
    Uint32Type => Some(4294967295.0)
    _ => None
  }
}

///|
pub fn jtd_type_from_name(name : String) -> JtdType? {
  match name {
    "boolean" => Some(BooleanType)
    "float32" => Some(Float32Type)
    "float64" => Some(Float64Type)
    "int8" => Some(Int8Type)
    "uint8" => Some(Uint8Type)
    "int16" => Some(Int16Type)
    "uint16" => Some(Uint16Type)
    "int32" => Some(Int32Type)
    "uint32" => Some(Uint32Type)
    "string" => Some(StringType)
    "timestamp" => Some(TimestampType)
    _ => None
  }
}

///|
/// The eight mutually exclusive schema forms from RFC 8927.
pub(all) enum SchemaForm {
  EmptyForm
  RefForm(String)
  TypeForm(JtdType)
  EnumForm(Array[String])
  ElementsForm(Schema)
  PropertiesForm(Map[String, Schema], Map[String, Schema], Bool)
  ValuesForm(Schema)
  DiscriminatorForm(String, Map[String, Schema])
} derive(Debug)

///|
/// A schema node. Metadata is retained without assigning it validation meaning.
pub(all) struct Schema {
  form : SchemaForm
  nullable : Bool
  metadata : Map[String, Json]
} derive(Debug)

///|
pub fn Schema::new(form : SchemaForm) -> Schema {
  { form, nullable: false, metadata: Map([]), }
}

///|
pub fn Schema::with_nullable(self : Schema, nullable : Bool) -> Schema {
  { ..self, nullable, }
}

///|
pub fn Schema::with_metadata(
  self : Schema,
  metadata : Map[String, Json],
) -> Schema {
  { ..self, metadata, }
}

///|
pub fn Schema::form(self : Schema) -> SchemaForm {
  self.form
}

///|
pub fn Schema::is_nullable(self : Schema) -> Bool {
  self.nullable
}

///|
pub fn Schema::metadata(self : Schema) -> Map[String, Json] {
  self.metadata.copy()
}

///|
pub fn Schema::form_name(self : Schema) -> String {
  match self.form {
    EmptyForm => "empty"
    RefForm(_) => "ref"
    TypeForm(_) => "type"
    EnumForm(_) => "enum"
    ElementsForm(_) => "elements"
    PropertiesForm(_, _, _) => "properties"
    ValuesForm(_) => "values"
    DiscriminatorForm(_, _) => "discriminator"
  }
}

///|
pub fn Schema::empty() -> Schema {
  Schema::new(EmptyForm)
}

///|
pub fn Schema::reference(name : String) -> Schema {
  Schema::new(RefForm(name))
}

///|
pub fn Schema::type_(kind : JtdType) -> Schema {
  Schema::new(TypeForm(kind))
}

///|
pub fn Schema::enum_(values : Array[String]) -> Schema {
  Schema::new(EnumForm(values))
}

///|
pub fn Schema::elements(element : Schema) -> Schema {
  Schema::new(ElementsForm(element))
}

///|
pub fn Schema::properties(
  required : Map[String, Schema],
  optional : Map[String, Schema],
  additional : Bool,
) -> Schema {
  Schema::new(PropertiesForm(required, optional, additional))
}

///|
pub fn Schema::values(value : Schema) -> Schema {
  Schema::new(ValuesForm(value))
}

///|
pub fn Schema::discriminator(
  tag : String,
  mapping : Map[String, Schema],
) -> Schema {
  Schema::new(DiscriminatorForm(tag, mapping))
}

///|
pub fn Schema::ref_name(self : Schema) -> String? {
  match self.form {
    RefForm(name) => Some(name)
    _ => None
  }
}

///|
pub fn Schema::type_kind(self : Schema) -> JtdType? {
  match self.form {
    TypeForm(kind) => Some(kind)
    _ => None
  }
}

///|
pub fn Schema::enum_values(self : Schema) -> Array[String]? {
  match self.form {
    EnumForm(values) => Some(values.copy())
    _ => None
  }
}

///|
pub fn Schema::element_schema(self : Schema) -> Schema? {
  match self.form {
    ElementsForm(element) => Some(element)
    _ => None
  }
}

///|
pub fn Schema::value_schema(self : Schema) -> Schema? {
  match self.form {
    ValuesForm(value) => Some(value)
    _ => None
  }
}

///|
pub fn Schema::required_properties(self : Schema) -> Map[String, Schema]? {
  match self.form {
    PropertiesForm(required, _, _) => Some(required.copy())
    _ => None
  }
}

///|
pub fn Schema::optional_properties(self : Schema) -> Map[String, Schema]? {
  match self.form {
    PropertiesForm(_, optional, _) => Some(optional.copy())
    _ => None
  }
}

///|
pub fn Schema::allows_additional_properties(self : Schema) -> Bool {
  match self.form {
    PropertiesForm(_, _, additional) => additional
    _ => false
  }
}

///|
pub fn Schema::discriminator_tag(self : Schema) -> String? {
  match self.form {
    DiscriminatorForm(tag, _) => Some(tag)
    _ => None
  }
}

///|
pub fn Schema::discriminator_mapping(self : Schema) -> Map[String, Schema]? {
  match self.form {
    DiscriminatorForm(_, mapping) => Some(mapping.copy())
    _ => None
  }
}

///|
/// A complete JTD document. Only this root level may contain definitions.
pub(all) struct SchemaDocument {
  root : Schema
  definitions : Map[String, Schema]
} derive(Debug)

///|
pub fn SchemaDocument::new(
  root : Schema,
  definitions? : Map[String, Schema] = Map([]),
) -> SchemaDocument {
  { root, definitions, }
}

///|
pub fn SchemaDocument::root(self : SchemaDocument) -> Schema {
  self.root
}

///|
pub fn SchemaDocument::definitions(
  self : SchemaDocument,
) -> Map[String, Schema] {
  self.definitions.copy()
}

///|
pub fn SchemaDocument::definition(
  self : SchemaDocument,
  name : String,
) -> Schema? {
  self.definitions.get(name)
}

///|
pub fn SchemaDocument::has_definition(
  self : SchemaDocument,
  name : String,
) -> Bool {
  self.definitions.contains(name)
}

///|
pub fn SchemaDocument::definition_count(self : SchemaDocument) -> Int {
  self.definitions.length()
}

///|
pub fn SchemaDocument::definition_names(self : SchemaDocument) -> Array[String] {
  let names : Array[String] = []
  for name, _ in self.definitions {
    names.push(name)
  }
  names
}
