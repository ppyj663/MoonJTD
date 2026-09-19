///|
/// Stable categories for machine-readable MoonJTD diagnostics.
pub(all) enum DiagnosticCode {
  InvalidJson
  ExpectedObject
  UnknownKeyword
  MixedSchemaForms
  InvalidMemberType
  InvalidTypeName
  EmptyEnum
  DuplicateEnumValue
  UnknownReference
  NestedDefinitions
  PropertyOverlap
  InvalidDiscriminatorMapping
  DuplicateDiscriminatorProperty
  ValidationMismatch
  MissingProperty
  AdditionalProperty
  InvalidDiscriminatorTag
  UnknownDiscriminatorValue
  ResourceLimitExceeded
  InvalidIdentifier
  GenerationFailure
} derive(Eq, Debug)

///|
pub fn DiagnosticCode::name(self : DiagnosticCode) -> String {
  match self {
    InvalidJson => "invalid-json"
    ExpectedObject => "expected-object"
    UnknownKeyword => "unknown-keyword"
    MixedSchemaForms => "mixed-schema-forms"
    InvalidMemberType => "invalid-member-type"
    InvalidTypeName => "invalid-type-name"
    EmptyEnum => "empty-enum"
    DuplicateEnumValue => "duplicate-enum-value"
    UnknownReference => "unknown-reference"
    NestedDefinitions => "nested-definitions"
    PropertyOverlap => "property-overlap"
    InvalidDiscriminatorMapping => "invalid-discriminator-mapping"
    DuplicateDiscriminatorProperty => "duplicate-discriminator-property"
    ValidationMismatch => "validation-mismatch"
    MissingProperty => "missing-property"
    AdditionalProperty => "additional-property"
    InvalidDiscriminatorTag => "invalid-discriminator-tag"
    UnknownDiscriminatorValue => "unknown-discriminator-value"
    ResourceLimitExceeded => "resource-limit-exceeded"
    InvalidIdentifier => "invalid-identifier"
    GenerationFailure => "generation-failure"
  }
}

///|
/// A structured error that can be rendered by a CLI or editor integration.
pub(all) struct Diagnostic {
  code : DiagnosticCode
  message : String
  instance_path : JsonPointer
  schema_path : JsonPointer
} derive(Eq, Debug)

///|
pub fn Diagnostic::new(
  code : DiagnosticCode,
  message : String,
  instance_path? : JsonPointer = JsonPointer::root(),
  schema_path? : JsonPointer = JsonPointer::root(),
) -> Diagnostic {
  { code, message, instance_path, schema_path, }
}

///|
pub fn Diagnostic::code(self : Diagnostic) -> DiagnosticCode {
  self.code
}

///|
pub fn Diagnostic::message(self : Diagnostic) -> String {
  self.message
}

///|
pub fn Diagnostic::instance_path(self : Diagnostic) -> JsonPointer {
  self.instance_path
}

///|
pub fn Diagnostic::schema_path(self : Diagnostic) -> JsonPointer {
  self.schema_path
}

///|
pub fn Diagnostic::to_string(self : Diagnostic) -> String {
  self.code.name() +
  ": " +
  self.message +
  " (instance=" +
  self.instance_path.display() +
  ", schema=" +
  self.schema_path.display() +
  ")"
}

///|
pub(all) suberror SchemaError {
  SchemaDiagnostic(Diagnostic)
} derive(Eq, Debug)

///|
pub(all) suberror CodegenError {
  CodegenDiagnostic(Diagnostic)
} derive(Eq, Debug)
