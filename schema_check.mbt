///|
/// Limits applied while checking an untrusted schema document.
pub(all) struct SchemaCheckOptions {
  max_depth : Int
  max_nodes : Int
  max_errors : Int
} derive(Eq, Debug)

///|
pub fn SchemaCheckOptions::default() -> SchemaCheckOptions {
  { max_depth: 128, max_nodes: 100000, max_errors: 100, }
}

///|
pub fn SchemaCheckOptions::new(
  max_depth? : Int = 128,
  max_nodes? : Int = 100000,
  max_errors? : Int = 100,
) -> SchemaCheckOptions {
  { max_depth, max_nodes, max_errors, }
}

///|
pub fn SchemaCheckOptions::max_depth(self : SchemaCheckOptions) -> Int {
  self.max_depth
}

///|
pub fn SchemaCheckOptions::max_nodes(self : SchemaCheckOptions) -> Int {
  self.max_nodes
}

///|
pub fn SchemaCheckOptions::max_errors(self : SchemaCheckOptions) -> Int {
  self.max_errors
}

///|
fn check_diagnostic(
  code : DiagnosticCode,
  message : String,
  path : JsonPointer,
) -> Diagnostic {
  Diagnostic::new(code, message, schema_path=path)
}

///|
fn add_check_error(
  errors : Array[Diagnostic],
  options : SchemaCheckOptions,
  diagnostic : Diagnostic,
) -> Unit {
  if errors.length() < options.max_errors {
    errors.push(diagnostic)
  }
}

///|
fn check_enum(
  values : Array[String],
  path : JsonPointer,
  errors : Array[Diagnostic],
  options : SchemaCheckOptions,
) -> Unit {
  if values.is_empty() {
    add_check_error(
      errors,
      options,
      check_diagnostic(
        EmptyEnum,
        "enum form must contain at least one value",
        path.property("enum"),
      ),
    )
    return
  }
  let seen : Map[String, Bool] = Map([])
  for index, value in values {
    if seen.contains(value) {
      add_check_error(
        errors,
        options,
        check_diagnostic(
          DuplicateEnumValue,
          "duplicate enum value '" + value + "'",
          path.property("enum").index(index),
        ),
      )
    } else {
      seen.set(value, true)
    }
  }
}

///|
fn check_property_overlap(
  required : Map[String, Schema],
  optional : Map[String, Schema],
  path : JsonPointer,
  errors : Array[Diagnostic],
  options : SchemaCheckOptions,
) -> Unit {
  for name, _ in required {
    if optional.contains(name) {
      add_check_error(
        errors,
        options,
        check_diagnostic(
          PropertyOverlap,
          "property '" + name + "' is both required and optional",
          path.property("optionalProperties").property(name),
        ),
      )
    }
  }
}

///|
fn check_discriminator_branch(
  tag : String,
  name : String,
  branch : Schema,
  path : JsonPointer,
  errors : Array[Diagnostic],
  options : SchemaCheckOptions,
) -> Unit {
  match branch.form() {
    PropertiesForm(required, optional, _) => {
      if branch.is_nullable() {
        add_check_error(
          errors,
          options,
          check_diagnostic(
            InvalidDiscriminatorMapping,
            "discriminator mapping branches cannot be nullable",
            path.property("nullable"),
          ),
        )
      }
      if required.contains(tag) || optional.contains(tag) {
        add_check_error(
          errors,
          options,
          check_diagnostic(
            DuplicateDiscriminatorProperty,
            "mapping branch '" +
            name +
            "' redeclares discriminator property '" +
            tag +
            "'",
            path,
          ),
        )
      }
    }
    _ =>
      add_check_error(
        errors,
        options,
        check_diagnostic(
          InvalidDiscriminatorMapping,
          "discriminator mapping branch must use properties form",
          path,
        ),
      )
  }
}

///|
fn check_schema_node(
  schema : Schema,
  definitions : Map[String, Schema],
  path : JsonPointer,
  depth : Int,
  visited : Ref[Int],
  errors : Array[Diagnostic],
  options : SchemaCheckOptions,
) -> Unit {
  if errors.length() >= options.max_errors {
    return
  }
  if depth > options.max_depth {
    add_check_error(
      errors,
      options,
      check_diagnostic(
        ResourceLimitExceeded,
        "schema depth exceeds configured limit " + options.max_depth.to_string(),
        path,
      ),
    )
    return
  }
  visited.val += 1
  if visited.val > options.max_nodes {
    add_check_error(
      errors,
      options,
      check_diagnostic(
        ResourceLimitExceeded,
        "schema node count exceeds configured limit " +
        options.max_nodes.to_string(),
        path,
      ),
    )
    return
  }
  match schema.form() {
    EmptyForm | TypeForm(_) => ()
    RefForm(name) =>
      if !definitions.contains(name) {
        add_check_error(
          errors,
          options,
          check_diagnostic(
            UnknownReference,
            "reference '" + name + "' is not present in root definitions",
            path.property("ref"),
          ),
        )
      }
    EnumForm(values) => check_enum(values, path, errors, options)
    ElementsForm(element) =>
      check_schema_node(
        element,
        definitions,
        path.property("elements"),
        depth + 1,
        visited,
        errors,
        options,
      )
    ValuesForm(value) =>
      check_schema_node(
        value,
        definitions,
        path.property("values"),
        depth + 1,
        visited,
        errors,
        options,
      )
    PropertiesForm(required, optional, _) => {
      check_property_overlap(required, optional, path, errors, options)
      for name, property in required {
        check_schema_node(
          property,
          definitions,
          path.property("properties").property(name),
          depth + 1,
          visited,
          errors,
          options,
        )
      }
      for name, property in optional {
        check_schema_node(
          property,
          definitions,
          path.property("optionalProperties").property(name),
          depth + 1,
          visited,
          errors,
          options,
        )
      }
    }
    DiscriminatorForm(tag, mapping) =>
      for name, branch in mapping {
        let branch_path = path.property("mapping").property(name)
        check_discriminator_branch(
          tag, name, branch, branch_path, errors, options,
        )
        check_schema_node(
          branch,
          definitions,
          branch_path,
          depth + 1,
          visited,
          errors,
          options,
        )
      }
  }
}

///|
/// Check cross-node constraints that cannot be decided while parsing one node.
pub fn check_schema_with(
  document : SchemaDocument,
  options : SchemaCheckOptions,
) -> Array[Diagnostic] {
  let errors : Array[Diagnostic] = []
  if options.max_depth < 0 || options.max_nodes < 1 || options.max_errors < 1 {
    errors.push(
      check_diagnostic(
        ResourceLimitExceeded,
        "schema check limits must be positive",
        JsonPointer::root(),
      ),
    )
    return errors
  }
  let visited = Ref(0)
  let definitions = document.definitions()
  for name, schema in definitions {
    check_schema_node(
      schema,
      definitions,
      JsonPointer::root().property("definitions").property(name),
      1,
      visited,
      errors,
      options,
    )
  }
  check_schema_node(
    document.root(),
    definitions,
    JsonPointer::root(),
    0,
    visited,
    errors,
    options,
  )
  errors
}

///|
pub fn check_schema(document : SchemaDocument) -> Array[Diagnostic] {
  check_schema_with(document, SchemaCheckOptions::default())
}

///|
/// Parse a schema and reject semantic violations in one operation.
pub fn parse_checked_schema(
  text : StringView,
) -> Result[SchemaDocument, Array[Diagnostic]] {
  let document = match parse_schema(text) {
    Ok(value) => value
    Err(SchemaDiagnostic(diagnostic)) => return Err([diagnostic])
  }
  let errors = check_schema(document)
  if errors.is_empty() {
    Ok(document)
  } else {
    Err(errors)
  }
}
