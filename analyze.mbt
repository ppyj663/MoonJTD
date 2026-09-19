///|
/// Structural metrics for a complete JTD schema document.
pub(all) struct SchemaStats {
  node_count : Int
  max_depth : Int
  definition_count : Int
  reference_count : Int
  nullable_count : Int
  empty_count : Int
  type_count : Int
  enum_count : Int
  elements_count : Int
  properties_count : Int
  values_count : Int
  discriminator_count : Int
  required_property_count : Int
  optional_property_count : Int
  discriminator_branch_count : Int
} derive(Eq, Debug)

///|
fn stat_value(counts : Map[String, Int], name : String) -> Int {
  match counts.get(name) {
    Some(value) => value
    None => 0
  }
}

///|
fn increment_stat(counts : Map[String, Int], name : String) -> Unit {
  counts.set(name, stat_value(counts, name) + 1)
}

///|
fn add_stat(counts : Map[String, Int], name : String, amount : Int) -> Unit {
  counts.set(name, stat_value(counts, name) + amount)
}

///|
fn analyze_node(
  schema : Schema,
  depth : Int,
  counts : Map[String, Int],
  max_depth : Ref[Int],
) -> Unit {
  increment_stat(counts, "nodes")
  if depth > max_depth.val {
    max_depth.val = depth
  }
  if schema.is_nullable() {
    increment_stat(counts, "nullable")
  }
  match schema.form() {
    EmptyForm => increment_stat(counts, "empty")
    RefForm(_) => increment_stat(counts, "ref")
    TypeForm(_) => increment_stat(counts, "type")
    EnumForm(_) => increment_stat(counts, "enum")
    ElementsForm(element) => {
      increment_stat(counts, "elements")
      analyze_node(element, depth + 1, counts, max_depth)
    }
    ValuesForm(value) => {
      increment_stat(counts, "values")
      analyze_node(value, depth + 1, counts, max_depth)
    }
    PropertiesForm(required, optional, _) => {
      increment_stat(counts, "properties")
      add_stat(counts, "required-properties", required.length())
      add_stat(counts, "optional-properties", optional.length())
      for _, child in required {
        analyze_node(child, depth + 1, counts, max_depth)
      }
      for _, child in optional {
        analyze_node(child, depth + 1, counts, max_depth)
      }
    }
    DiscriminatorForm(_, mapping) => {
      increment_stat(counts, "discriminator")
      add_stat(counts, "branches", mapping.length())
      for _, child in mapping {
        analyze_node(child, depth + 1, counts, max_depth)
      }
    }
  }
}

///|
/// Count schema structure without following references, so recursive definitions
/// are safe and each syntactic node is counted exactly once.
pub fn analyze_schema(document : SchemaDocument) -> SchemaStats {
  let counts : Map[String, Int] = Map([])
  let max_depth = Ref(0)
  analyze_node(document.root(), 0, counts, max_depth)
  for _, schema in document.definitions() {
    analyze_node(schema, 1, counts, max_depth)
  }
  {
    node_count: stat_value(counts, "nodes"),
    max_depth: max_depth.val,
    definition_count: document.definition_count(),
    reference_count: stat_value(counts, "ref"),
    nullable_count: stat_value(counts, "nullable"),
    empty_count: stat_value(counts, "empty"),
    type_count: stat_value(counts, "type"),
    enum_count: stat_value(counts, "enum"),
    elements_count: stat_value(counts, "elements"),
    properties_count: stat_value(counts, "properties"),
    values_count: stat_value(counts, "values"),
    discriminator_count: stat_value(counts, "discriminator"),
    required_property_count: stat_value(counts, "required-properties"),
    optional_property_count: stat_value(counts, "optional-properties"),
    discriminator_branch_count: stat_value(counts, "branches"),
  }
}

///|
pub fn SchemaStats::node_count(self : SchemaStats) -> Int {
  self.node_count
}

///|
pub fn SchemaStats::max_depth(self : SchemaStats) -> Int {
  self.max_depth
}

///|
pub fn SchemaStats::definition_count(self : SchemaStats) -> Int {
  self.definition_count
}

///|
pub fn SchemaStats::reference_count(self : SchemaStats) -> Int {
  self.reference_count
}

///|
pub fn SchemaStats::nullable_count(self : SchemaStats) -> Int {
  self.nullable_count
}

///|
pub fn SchemaStats::empty_count(self : SchemaStats) -> Int {
  self.empty_count
}

///|
pub fn SchemaStats::type_count(self : SchemaStats) -> Int {
  self.type_count
}

///|
pub fn SchemaStats::enum_count(self : SchemaStats) -> Int {
  self.enum_count
}

///|
pub fn SchemaStats::elements_count(self : SchemaStats) -> Int {
  self.elements_count
}

///|
pub fn SchemaStats::properties_count(self : SchemaStats) -> Int {
  self.properties_count
}

///|
pub fn SchemaStats::values_count(self : SchemaStats) -> Int {
  self.values_count
}

///|
pub fn SchemaStats::discriminator_count(self : SchemaStats) -> Int {
  self.discriminator_count
}

///|
pub fn SchemaStats::required_property_count(self : SchemaStats) -> Int {
  self.required_property_count
}

///|
pub fn SchemaStats::optional_property_count(self : SchemaStats) -> Int {
  self.optional_property_count
}

///|
pub fn SchemaStats::discriminator_branch_count(self : SchemaStats) -> Int {
  self.discriminator_branch_count
}

///|
pub fn SchemaStats::to_string(self : SchemaStats) -> String {
  "nodes=" +
  self.node_count.to_string() +
  ", maxDepth=" +
  self.max_depth.to_string() +
  ", definitions=" +
  self.definition_count.to_string() +
  ", refs=" +
  self.reference_count.to_string() +
  ", nullable=" +
  self.nullable_count.to_string() +
  ", forms={empty:" +
  self.empty_count.to_string() +
  ",type:" +
  self.type_count.to_string() +
  ",enum:" +
  self.enum_count.to_string() +
  ",elements:" +
  self.elements_count.to_string() +
  ",properties:" +
  self.properties_count.to_string() +
  ",values:" +
  self.values_count.to_string() +
  ",discriminator:" +
  self.discriminator_count.to_string() +
  "}"
}

///|
fn collect_refs_node(schema : Schema, refs : Map[String, Bool]) -> Unit {
  match schema.form() {
    RefForm(name) => refs.set(name, true)
    ElementsForm(element) | ValuesForm(element) =>
      collect_refs_node(element, refs)
    PropertiesForm(required, optional, _) => {
      for _, child in required {
        collect_refs_node(child, refs)
      }
      for _, child in optional {
        collect_refs_node(child, refs)
      }
    }
    DiscriminatorForm(_, mapping) =>
      for _, child in mapping {
        collect_refs_node(child, refs)
      }
    EmptyForm | TypeForm(_) | EnumForm(_) => ()
  }
}

///|
/// Collect every syntactically referenced definition name.
pub fn referenced_definitions(document : SchemaDocument) -> Array[String] {
  let refs : Map[String, Bool] = Map([])
  collect_refs_node(document.root(), refs)
  for _, schema in document.definitions() {
    collect_refs_node(schema, refs)
  }
  let names : Array[String] = []
  for name, _ in refs {
    names.push(name)
  }
  names
}

///|
/// Definitions that are not transitively reachable from the root schema.
pub fn unused_definitions(document : SchemaDocument) -> Array[String] {
  let reachable : Map[String, Bool] = Map([])
  collect_refs_node(document.root(), reachable)
  let mut changed = true
  while changed {
    changed = false
    let snapshot : Array[String] = []
    for name, _ in reachable {
      snapshot.push(name)
    }
    for name in snapshot {
      match document.definition(name) {
        None => ()
        Some(schema) => {
          let before = reachable.length()
          collect_refs_node(schema, reachable)
          if reachable.length() != before {
            changed = true
          }
        }
      }
    }
  }
  let unused : Array[String] = []
  for name, _ in document.definitions() {
    if !reachable.contains(name) {
      unused.push(name)
    }
  }
  unused
}

///|
/// Produce human-readable lint diagnostics that are not RFC correctness errors.
pub fn lint_schema(document : SchemaDocument) -> Array[Diagnostic] {
  let diagnostics : Array[Diagnostic] = []
  for name in unused_definitions(document) {
    diagnostics.push(
      Diagnostic::new(
        UnknownReference,
        "definition '" + name + "' is never reached from the root schema",
        schema_path=JsonPointer::root().property("definitions").property(name),
      ),
    )
  }
  let stats = analyze_schema(document)
  if stats.node_count() > 10000 {
    diagnostics.push(
      Diagnostic::new(
        ResourceLimitExceeded,
        "large schema contains " + stats.node_count().to_string() + " nodes",
      ),
    )
  }
  diagnostics
}
