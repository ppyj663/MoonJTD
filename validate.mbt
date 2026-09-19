///|
/// Resource limits for validating untrusted JSON values and recursive schemas.
pub(all) struct ValidationOptions {
  max_errors : Int
  max_depth : Int
  max_ref_depth : Int
  max_nodes : Int
} derive(Eq, Debug)

///|
pub fn ValidationOptions::default() -> ValidationOptions {
  { max_errors: 100, max_depth: 256, max_ref_depth: 64, max_nodes: 1000000, }
}

///|
pub fn ValidationOptions::new(
  max_errors? : Int = 100,
  max_depth? : Int = 256,
  max_ref_depth? : Int = 64,
  max_nodes? : Int = 1000000,
) -> ValidationOptions {
  { max_errors, max_depth, max_ref_depth, max_nodes, }
}

///|
pub fn ValidationOptions::max_errors(self : ValidationOptions) -> Int {
  self.max_errors
}

///|
pub fn ValidationOptions::max_depth(self : ValidationOptions) -> Int {
  self.max_depth
}

///|
pub fn ValidationOptions::max_ref_depth(self : ValidationOptions) -> Int {
  self.max_ref_depth
}

///|
pub fn ValidationOptions::max_nodes(self : ValidationOptions) -> Int {
  self.max_nodes
}

///|
/// Complete outcome of one validation pass.
pub(all) struct ValidationReport {
  errors : Array[Diagnostic]
  visited_nodes : Int
  truncated : Bool
} derive(Debug)

///|
pub fn ValidationReport::errors(self : ValidationReport) -> Array[Diagnostic] {
  self.errors.copy()
}

///|
pub fn ValidationReport::is_valid(self : ValidationReport) -> Bool {
  self.errors.is_empty()
}

///|
pub fn ValidationReport::visited_nodes(self : ValidationReport) -> Int {
  self.visited_nodes
}

///|
pub fn ValidationReport::is_truncated(self : ValidationReport) -> Bool {
  self.truncated
}

///|
priv struct ValidationState {
  options : ValidationOptions
  errors : Array[Diagnostic]
  nodes : Ref[Int]
  truncated : Ref[Bool]
}

///|
fn ValidationState::new(options : ValidationOptions) -> ValidationState {
  { options, errors: [], nodes: Ref(0), truncated: Ref(false), }
}

///|
fn ValidationState::full(self : ValidationState) -> Bool {
  if self.errors.length() >= self.options.max_errors {
    self.truncated.val = true
    true
  } else {
    self.truncated.val
  }
}

///|
fn ValidationState::push(
  self : ValidationState,
  code : DiagnosticCode,
  message : String,
  instance_path : JsonPointer,
  schema_path : JsonPointer,
) -> Unit {
  if self.errors.length() < self.options.max_errors {
    self.errors.push(
      Diagnostic::new(code, message, instance_path~, schema_path~),
    )
  } else {
    self.truncated.val = true
  }
}

///|
fn ValidationState::enter(
  self : ValidationState,
  depth : Int,
  instance_path : JsonPointer,
  schema_path : JsonPointer,
) -> Bool {
  if self.full() {
    return false
  }
  if depth > self.options.max_depth {
    self.push(
      ResourceLimitExceeded,
      "instance depth exceeds configured limit " +
      self.options.max_depth.to_string(),
      instance_path,
      schema_path,
    )
    self.truncated.val = true
    return false
  }
  self.nodes.val += 1
  if self.nodes.val > self.options.max_nodes {
    self.push(
      ResourceLimitExceeded,
      "visited node count exceeds configured limit " +
      self.options.max_nodes.to_string(),
      instance_path,
      schema_path,
    )
    self.truncated.val = true
    return false
  }
  true
}

///|
fn contains_string(values : Array[String], target : String) -> Bool {
  for value in values {
    if value == target {
      return true
    }
  }
  false
}

///|
fn validate_type_form(
  kind : JtdType,
  value : Json,
  instance_path : JsonPointer,
  schema_path : JsonPointer,
  state : ValidationState,
) -> Unit {
  if !scalar_accepts(kind, value) {
    state.push(
      ValidationMismatch,
      "expected " + scalar_expectation(kind) + ", found " + json_kind(value),
      instance_path,
      schema_path.property("type"),
    )
  }
}

///|
fn validate_enum_form(
  values : Array[String],
  value : Json,
  instance_path : JsonPointer,
  schema_path : JsonPointer,
  state : ValidationState,
) -> Unit {
  match value {
    String(text) =>
      if !contains_string(values, text) {
        state.push(
          ValidationMismatch,
          "string '" + text + "' is not an allowed enum value",
          instance_path,
          schema_path.property("enum"),
        )
      }
    _ =>
      state.push(
        ValidationMismatch,
        "expected enum string, found " + json_kind(value),
        instance_path,
        schema_path.property("enum"),
      )
  }
}

///|
fn validate_elements_form(
  document : SchemaDocument,
  element : Schema,
  value : Json,
  instance_path : JsonPointer,
  schema_path : JsonPointer,
  depth : Int,
  ref_depth : Int,
  state : ValidationState,
) -> Unit {
  guard value is Array(items) else {
    state.push(
      ValidationMismatch,
      "expected array, found " + json_kind(value),
      instance_path,
      schema_path.property("elements"),
    )
    return
  }
  for index, item in items {
    if state.full() {
      return
    }
    validate_node(
      document,
      element,
      item,
      instance_path.index(index),
      schema_path.property("elements"),
      depth + 1,
      ref_depth,
      state,
    )
  }
}

///|
fn validate_values_form(
  document : SchemaDocument,
  value_schema : Schema,
  value : Json,
  instance_path : JsonPointer,
  schema_path : JsonPointer,
  depth : Int,
  ref_depth : Int,
  state : ValidationState,
) -> Unit {
  guard value is Object(object) else {
    state.push(
      ValidationMismatch,
      "expected object, found " + json_kind(value),
      instance_path,
      schema_path.property("values"),
    )
    return
  }
  for name, item in object {
    if state.full() {
      return
    }
    validate_node(
      document,
      value_schema,
      item,
      instance_path.property(name),
      schema_path.property("values"),
      depth + 1,
      ref_depth,
      state,
    )
  }
}

///|
fn validate_required_properties(
  document : SchemaDocument,
  required : Map[String, Schema],
  object : Map[String, Json],
  instance_path : JsonPointer,
  schema_path : JsonPointer,
  depth : Int,
  ref_depth : Int,
  state : ValidationState,
) -> Unit {
  for name, property_schema in required {
    if state.full() {
      return
    }
    match object.get(name) {
      None =>
        state.push(
          MissingProperty,
          "missing required property '" + name + "'",
          instance_path,
          schema_path.property("properties").property(name),
        )
      Some(property_value) =>
        validate_node(
          document,
          property_schema,
          property_value,
          instance_path.property(name),
          schema_path.property("properties").property(name),
          depth + 1,
          ref_depth,
          state,
        )
    }
  }
}

///|
fn validate_optional_properties(
  document : SchemaDocument,
  optional : Map[String, Schema],
  object : Map[String, Json],
  instance_path : JsonPointer,
  schema_path : JsonPointer,
  depth : Int,
  ref_depth : Int,
  state : ValidationState,
) -> Unit {
  for name, property_schema in optional {
    if state.full() {
      return
    }
    match object.get(name) {
      None => ()
      Some(property_value) =>
        validate_node(
          document,
          property_schema,
          property_value,
          instance_path.property(name),
          schema_path.property("optionalProperties").property(name),
          depth + 1,
          ref_depth,
          state,
        )
    }
  }
}

///|
fn validate_additional_properties(
  required : Map[String, Schema],
  optional : Map[String, Schema],
  object : Map[String, Json],
  ignored_property : String?,
  instance_path : JsonPointer,
  schema_path : JsonPointer,
  state : ValidationState,
) -> Unit {
  for name, _ in object {
    if state.full() {
      return
    }
    let ignored = match ignored_property {
      Some(value) => value == name
      None => false
    }
    if !ignored && !required.contains(name) && !optional.contains(name) {
      state.push(
        AdditionalProperty,
        "additional property '" + name + "' is not allowed",
        instance_path.property(name),
        schema_path,
      )
    }
  }
}

///|
fn validate_properties_object(
  document : SchemaDocument,
  required : Map[String, Schema],
  optional : Map[String, Schema],
  additional : Bool,
  object : Map[String, Json],
  ignored_property : String?,
  instance_path : JsonPointer,
  schema_path : JsonPointer,
  depth : Int,
  ref_depth : Int,
  state : ValidationState,
) -> Unit {
  validate_required_properties(
    document, required, object, instance_path, schema_path, depth, ref_depth, state,
  )
  validate_optional_properties(
    document, optional, object, instance_path, schema_path, depth, ref_depth, state,
  )
  if !additional {
    validate_additional_properties(
      required, optional, object, ignored_property, instance_path, schema_path, state,
    )
  }
}

///|
fn validate_properties_form(
  document : SchemaDocument,
  required : Map[String, Schema],
  optional : Map[String, Schema],
  additional : Bool,
  value : Json,
  instance_path : JsonPointer,
  schema_path : JsonPointer,
  depth : Int,
  ref_depth : Int,
  state : ValidationState,
) -> Unit {
  guard value is Object(object) else {
    state.push(
      ValidationMismatch,
      "expected object, found " + json_kind(value),
      instance_path,
      schema_path,
    )
    return
  }
  validate_properties_object(
    document,
    required,
    optional,
    additional,
    object,
    None,
    instance_path,
    schema_path,
    depth,
    ref_depth,
    state,
  )
}

///|
fn validate_discriminator_form(
  document : SchemaDocument,
  tag : String,
  mapping : Map[String, Schema],
  value : Json,
  instance_path : JsonPointer,
  schema_path : JsonPointer,
  depth : Int,
  ref_depth : Int,
  state : ValidationState,
) -> Unit {
  guard value is Object(object) else {
    state.push(
      ValidationMismatch,
      "expected object for discriminator form, found " + json_kind(value),
      instance_path,
      schema_path.property("discriminator"),
    )
    return
  }
  let tag_value = match object.get(tag) {
    None => {
      state.push(
        InvalidDiscriminatorTag,
        "missing discriminator property '" + tag + "'",
        instance_path,
        schema_path.property("discriminator"),
      )
      return
    }
    Some(String(text)) => text
    Some(other) => {
      state.push(
        InvalidDiscriminatorTag,
        "discriminator property '" +
        tag +
        "' must be a string, found " +
        json_kind(other),
        instance_path.property(tag),
        schema_path.property("discriminator"),
      )
      return
    }
  }
  let branch = match mapping.get(tag_value) {
    None => {
      state.push(
        UnknownDiscriminatorValue,
        "unknown discriminator value '" + tag_value + "'",
        instance_path.property(tag),
        schema_path.property("mapping"),
      )
      return
    }
    Some(value) => value
  }
  match branch.form() {
    PropertiesForm(required, optional, additional) =>
      validate_properties_object(
        document,
        required,
        optional,
        additional,
        object,
        Some(tag),
        instance_path,
        schema_path.property("mapping").property(tag_value),
        depth,
        ref_depth,
        state,
      )
    _ =>
      state.push(
        InvalidDiscriminatorMapping,
        "selected discriminator mapping is not a properties schema",
        instance_path,
        schema_path.property("mapping").property(tag_value),
      )
  }
}

///|
fn validate_reference(
  document : SchemaDocument,
  name : String,
  value : Json,
  instance_path : JsonPointer,
  depth : Int,
  ref_depth : Int,
  state : ValidationState,
) -> Unit {
  if ref_depth >= state.options.max_ref_depth {
    state.push(
      ResourceLimitExceeded,
      "reference depth exceeds configured limit " +
      state.options.max_ref_depth.to_string(),
      instance_path,
      JsonPointer::root().property("definitions").property(name),
    )
    state.truncated.val = true
    return
  }
  match document.definition(name) {
    None =>
      state.push(
        UnknownReference,
        "reference '" + name + "' is not defined",
        instance_path,
        JsonPointer::root().property("ref"),
      )
    Some(target) =>
      validate_node(
        document,
        target,
        value,
        instance_path,
        JsonPointer::root().property("definitions").property(name),
        depth,
        ref_depth + 1,
        state,
      )
  }
}

///|
fn validate_node(
  document : SchemaDocument,
  schema : Schema,
  value : Json,
  instance_path : JsonPointer,
  schema_path : JsonPointer,
  depth : Int,
  ref_depth : Int,
  state : ValidationState,
) -> Unit {
  if !state.enter(depth, instance_path, schema_path) {
    return
  }
  if value is Null && schema.is_nullable() {
    return
  }
  match schema.form() {
    EmptyForm => ()
    RefForm(name) =>
      validate_reference(
        document, name, value, instance_path, depth, ref_depth, state,
      )
    TypeForm(kind) =>
      validate_type_form(kind, value, instance_path, schema_path, state)
    EnumForm(values) =>
      validate_enum_form(values, value, instance_path, schema_path, state)
    ElementsForm(element) =>
      validate_elements_form(
        document, element, value, instance_path, schema_path, depth, ref_depth, state,
      )
    ValuesForm(value_schema) =>
      validate_values_form(
        document, value_schema, value, instance_path, schema_path, depth, ref_depth,
        state,
      )
    PropertiesForm(required, optional, additional) =>
      validate_properties_form(
        document, required, optional, additional, value, instance_path, schema_path,
        depth, ref_depth, state,
      )
    DiscriminatorForm(tag, mapping) =>
      validate_discriminator_form(
        document, tag, mapping, value, instance_path, schema_path, depth, ref_depth,
        state,
      )
  }
}

///|
pub fn validate_with(
  document : SchemaDocument,
  value : Json,
  options : ValidationOptions,
) -> ValidationReport {
  if options.max_errors < 1 ||
    options.max_depth < 0 ||
    options.max_ref_depth < 1 ||
    options.max_nodes < 1 {
    let error = Diagnostic::new(
      ResourceLimitExceeded,
      "validation limits are invalid",
    )
    return { errors: [error], visited_nodes: 0, truncated: true, }
  }
  let state = ValidationState::new(options)
  validate_node(
    document,
    document.root(),
    value,
    JsonPointer::root(),
    JsonPointer::root(),
    0,
    0,
    state,
  )
  {
    errors: state.errors,
    visited_nodes: state.nodes.val,
    truncated: state.truncated.val,
  }
}

///|
pub fn validate(document : SchemaDocument, value : Json) -> Array[Diagnostic] {
  validate_with(document, value, ValidationOptions::default()).errors()
}

///|
pub fn validate_json_text(
  document : SchemaDocument,
  text : StringView,
) -> Result[Array[Diagnostic], Diagnostic] {
  let value = @json.parse(text) catch {
    error =>
      return Err(
        Diagnostic::new(
          InvalidJson,
          "invalid JSON instance: " + error.to_string(),
        ),
      )
  }
  Ok(validate(document, value))
}
