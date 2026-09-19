///|
/// Fluent builder for a JTD properties-form schema.
pub(all) struct ObjectSchemaBuilder {
  required : Map[String, Schema]
  optional : Map[String, Schema]
  additional : Bool
  nullable : Bool
  metadata : Map[String, Json]
} derive(Debug)

///|
pub fn ObjectSchemaBuilder::new() -> ObjectSchemaBuilder {
  {
    required: Map([]),
    optional: Map([]),
    additional: false,
    nullable: false,
    metadata: Map([]),
  }
}

///|
pub fn ObjectSchemaBuilder::required(
  self : ObjectSchemaBuilder,
  name : String,
  schema : Schema,
) -> ObjectSchemaBuilder {
  let required = self.required.copy()
  required.set(name, schema)
  { ..self, required, }
}

///|
pub fn ObjectSchemaBuilder::optional(
  self : ObjectSchemaBuilder,
  name : String,
  schema : Schema,
) -> ObjectSchemaBuilder {
  let optional = self.optional.copy()
  optional.set(name, schema)
  { ..self, optional, }
}

///|
pub fn ObjectSchemaBuilder::allow_additional(
  self : ObjectSchemaBuilder,
  allowed : Bool,
) -> ObjectSchemaBuilder {
  { ..self, additional: allowed, }
}

///|
pub fn ObjectSchemaBuilder::nullable(
  self : ObjectSchemaBuilder,
  nullable : Bool,
) -> ObjectSchemaBuilder {
  { ..self, nullable, }
}

///|
pub fn ObjectSchemaBuilder::metadata_entry(
  self : ObjectSchemaBuilder,
  name : String,
  value : Json,
) -> ObjectSchemaBuilder {
  let metadata = self.metadata.copy()
  metadata.set(name, value)
  { ..self, metadata, }
}

///|
pub fn ObjectSchemaBuilder::required_count(self : ObjectSchemaBuilder) -> Int {
  self.required.length()
}

///|
pub fn ObjectSchemaBuilder::optional_count(self : ObjectSchemaBuilder) -> Int {
  self.optional.length()
}

///|
pub fn ObjectSchemaBuilder::build(
  self : ObjectSchemaBuilder,
) -> Result[Schema, Diagnostic] {
  for name, _ in self.required {
    if self.optional.contains(name) {
      return Err(
        Diagnostic::new(
          PropertyOverlap,
          "property '" + name + "' cannot be both required and optional",
          schema_path=JsonPointer::root()
            .property("optionalProperties")
            .property(name),
        ),
      )
    }
  }
  Ok(
    Schema::properties(self.required, self.optional, self.additional)
    .with_nullable(self.nullable)
    .with_metadata(self.metadata),
  )
}

///|
/// Fluent builder for a JTD discriminator-form schema.
pub(all) struct DiscriminatorSchemaBuilder {
  tag : String
  mapping : Map[String, Schema]
  nullable : Bool
  metadata : Map[String, Json]
} derive(Debug)

///|
pub fn DiscriminatorSchemaBuilder::new(
  tag : String,
) -> DiscriminatorSchemaBuilder {
  { tag, mapping: Map([]), nullable: false, metadata: Map([]), }
}

///|
pub fn DiscriminatorSchemaBuilder::branch(
  self : DiscriminatorSchemaBuilder,
  tag_value : String,
  schema : Schema,
) -> DiscriminatorSchemaBuilder {
  let mapping = self.mapping.copy()
  mapping.set(tag_value, schema)
  { ..self, mapping, }
}

///|
pub fn DiscriminatorSchemaBuilder::nullable(
  self : DiscriminatorSchemaBuilder,
  nullable : Bool,
) -> DiscriminatorSchemaBuilder {
  { ..self, nullable, }
}

///|
pub fn DiscriminatorSchemaBuilder::metadata_entry(
  self : DiscriminatorSchemaBuilder,
  name : String,
  value : Json,
) -> DiscriminatorSchemaBuilder {
  let metadata = self.metadata.copy()
  metadata.set(name, value)
  { ..self, metadata, }
}

///|
pub fn DiscriminatorSchemaBuilder::branch_count(
  self : DiscriminatorSchemaBuilder,
) -> Int {
  self.mapping.length()
}

///|
pub fn DiscriminatorSchemaBuilder::build(
  self : DiscriminatorSchemaBuilder,
) -> Result[Schema, Diagnostic] {
  if self.tag.is_empty() {
    return Err(
      Diagnostic::new(
        InvalidDiscriminatorTag,
        "discriminator property name must not be empty",
        schema_path=JsonPointer::root().property("discriminator"),
      ),
    )
  }
  for tag_value, branch in self.mapping {
    match branch.form() {
      PropertiesForm(required, optional, _) =>
        if required.contains(self.tag) || optional.contains(self.tag) {
          return Err(
            Diagnostic::new(
              DuplicateDiscriminatorProperty,
              "branch '" +
              tag_value +
              "' redeclares discriminator property '" +
              self.tag +
              "'",
              schema_path=JsonPointer::root()
                .property("mapping")
                .property(tag_value),
            ),
          )
        }
      _ =>
        return Err(
          Diagnostic::new(
            InvalidDiscriminatorMapping,
            "branch '" + tag_value + "' must be a properties schema",
            schema_path=JsonPointer::root()
              .property("mapping")
              .property(tag_value),
          ),
        )
    }
  }
  Ok(
    Schema::discriminator(self.tag, self.mapping)
    .with_nullable(self.nullable)
    .with_metadata(self.metadata),
  )
}

///|
/// Fluent builder for a complete schema document and its root definitions.
pub(all) struct DocumentBuilder {
  root : Schema
  definitions : Map[String, Schema]
} derive(Debug)

///|
pub fn DocumentBuilder::new(root : Schema) -> DocumentBuilder {
  { root, definitions: Map([]), }
}

///|
pub fn DocumentBuilder::definition(
  self : DocumentBuilder,
  name : String,
  schema : Schema,
) -> DocumentBuilder {
  let definitions = self.definitions.copy()
  definitions.set(name, schema)
  { ..self, definitions, }
}

///|
pub fn DocumentBuilder::definition_count(self : DocumentBuilder) -> Int {
  self.definitions.length()
}

///|
pub fn DocumentBuilder::build(
  self : DocumentBuilder,
) -> Result[SchemaDocument, Array[Diagnostic]] {
  let document = SchemaDocument::new(self.root, definitions=self.definitions)
  let errors = check_schema(document)
  if errors.is_empty() {
    Ok(document)
  } else {
    Err(errors)
  }
}

///|
/// Short constructor functions for schema-builder DSLs.
pub fn jtd_any() -> Schema {
  Schema::empty()
}

///|
pub fn jtd_boolean() -> Schema {
  Schema::type_(BooleanType)
}

///|
pub fn jtd_float32() -> Schema {
  Schema::type_(Float32Type)
}

///|
pub fn jtd_float64() -> Schema {
  Schema::type_(Float64Type)
}

///|
pub fn jtd_int8() -> Schema {
  Schema::type_(Int8Type)
}

///|
pub fn jtd_uint8() -> Schema {
  Schema::type_(Uint8Type)
}

///|
pub fn jtd_int16() -> Schema {
  Schema::type_(Int16Type)
}

///|
pub fn jtd_uint16() -> Schema {
  Schema::type_(Uint16Type)
}

///|
pub fn jtd_int32() -> Schema {
  Schema::type_(Int32Type)
}

///|
pub fn jtd_uint32() -> Schema {
  Schema::type_(Uint32Type)
}

///|
pub fn jtd_string() -> Schema {
  Schema::type_(StringType)
}

///|
pub fn jtd_timestamp() -> Schema {
  Schema::type_(TimestampType)
}

///|
pub fn jtd_reference(name : String) -> Schema {
  Schema::reference(name)
}

///|
pub fn jtd_enum(values : Array[String]) -> Schema {
  Schema::enum_(values)
}

///|
pub fn jtd_array(element : Schema) -> Schema {
  Schema::elements(element)
}

///|
pub fn jtd_map(value : Schema) -> Schema {
  Schema::values(value)
}

///|
pub fn jtd_object() -> ObjectSchemaBuilder {
  ObjectSchemaBuilder::new()
}

///|
pub fn jtd_union(tag : String) -> DiscriminatorSchemaBuilder {
  DiscriminatorSchemaBuilder::new(tag)
}

///|
pub fn jtd_document(root : Schema) -> DocumentBuilder {
  DocumentBuilder::new(root)
}
