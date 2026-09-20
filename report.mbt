///|
/// One syntactic node in a schema inventory.
pub(all) struct SchemaNodeInfo {
  path : JsonPointer
  form : String
  shape : String
  nullable : Bool
  child_count : Int
} derive(Eq, Debug)

///|
pub fn SchemaNodeInfo::path(self : SchemaNodeInfo) -> JsonPointer {
  self.path
}

///|
pub fn SchemaNodeInfo::form(self : SchemaNodeInfo) -> String {
  self.form
}

///|
pub fn SchemaNodeInfo::shape(self : SchemaNodeInfo) -> String {
  self.shape
}

///|
pub fn SchemaNodeInfo::is_nullable(self : SchemaNodeInfo) -> Bool {
  self.nullable
}

///|
pub fn SchemaNodeInfo::child_count(self : SchemaNodeInfo) -> Int {
  self.child_count
}

///|
fn direct_child_count(schema : Schema) -> Int {
  match schema.form() {
    ElementsForm(_) | ValuesForm(_) => 1
    PropertiesForm(required, optional, _) =>
      required.length() + optional.length()
    DiscriminatorForm(_, mapping) => mapping.length()
    EmptyForm | RefForm(_) | TypeForm(_) | EnumForm(_) => 0
  }
}

///|
fn inventory_node(
  schema : Schema,
  path : JsonPointer,
  output : Array[SchemaNodeInfo],
) -> Unit {
  output.push({
    path,
    form: schema.form_name(),
    shape: schema_shape(schema),
    nullable: schema.is_nullable(),
    child_count: direct_child_count(schema),
  })
  match schema.form() {
    ElementsForm(element) =>
      inventory_node(element, path.property("elements"), output)
    ValuesForm(value) => inventory_node(value, path.property("values"), output)
    PropertiesForm(required, optional, _) => {
      for name, child in required {
        inventory_node(
          child,
          path.property("properties").property(name),
          output,
        )
      }
      for name, child in optional {
        inventory_node(
          child,
          path.property("optionalProperties").property(name),
          output,
        )
      }
    }
    DiscriminatorForm(_, mapping) =>
      for name, child in mapping {
        inventory_node(child, path.property("mapping").property(name), output)
      }
    EmptyForm | RefForm(_) | TypeForm(_) | EnumForm(_) => ()
  }
}

///|
/// Enumerate each syntactic schema node without following refs.
pub fn schema_inventory(document : SchemaDocument) -> Array[SchemaNodeInfo] {
  let output : Array[SchemaNodeInfo] = []
  inventory_node(document.root(), JsonPointer::root(), output)
  for name, schema in document.definitions() {
    inventory_node(
      schema,
      JsonPointer::root().property("definitions").property(name),
      output,
    )
  }
  output
}

///|
pub fn diagnostic_to_json(diagnostic : Diagnostic) -> Json {
  Json::object(
    Map([
      ("code", Json::string(diagnostic.code().name())),
      ("message", Json::string(diagnostic.message())),
      ("instancePath", Json::string(diagnostic.instance_path().to_string())),
      ("schemaPath", Json::string(diagnostic.schema_path().to_string())),
    ]),
  )
}

///|
pub fn diagnostics_to_json(diagnostics : Array[Diagnostic]) -> Json {
  Json::array(diagnostics.map(diagnostic_to_json))
}

///|
pub fn diagnostics_to_string(
  diagnostics : Array[Diagnostic],
  pretty? : Bool = false,
) -> String {
  let value = diagnostics_to_json(diagnostics)
  if pretty {
    let output = StringBuilder()
    write_report_pretty_json(output, value, 0, 2)
    output.to_string()
  } else {
    value.stringify(escape_slash=false)
  }
}

///|
fn report_indent(output : StringBuilder, depth : Int, width : Int) -> Unit {
  for index = 0; index < depth * width; index = index + 1 {
    output.write_char(' ')
  }
}

///|
fn write_report_array(
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
    report_indent(output, depth + 1, width)
    write_report_pretty_json(output, value, depth + 1, width)
    if index + 1 < values.length() {
      output.write_char(',')
    }
    output.write_char('\n')
  }
  report_indent(output, depth, width)
  output.write_char(']')
}

///|
fn write_report_object(
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
    report_indent(output, depth + 1, width)
    output.write_string(Json::string(name).stringify(escape_slash=false))
    output.write_string(": ")
    write_report_pretty_json(output, value, depth + 1, width)
    index += 1
    if index < object.length() {
      output.write_char(',')
    }
    output.write_char('\n')
  }
  report_indent(output, depth, width)
  output.write_char('}')
}

///|
fn write_report_pretty_json(
  output : StringBuilder,
  value : Json,
  depth : Int,
  width : Int,
) -> Unit {
  match value {
    Array(values) => write_report_array(output, values, depth, width)
    Object(object) => write_report_object(output, object, depth, width)
    other => output.write_string(other.stringify(escape_slash=false))
  }
}

///|
fn stat_number(value : Int) -> Json {
  Json::number(value.to_double(), repr=value.to_string())
}

///|
pub fn schema_stats_to_json(stats : SchemaStats) -> Json {
  Json::object(
    Map([
      ("nodeCount", stat_number(stats.node_count())),
      ("maxDepth", stat_number(stats.max_depth())),
      ("definitionCount", stat_number(stats.definition_count())),
      ("referenceCount", stat_number(stats.reference_count())),
      ("nullableCount", stat_number(stats.nullable_count())),
      ("emptyCount", stat_number(stats.empty_count())),
      ("typeCount", stat_number(stats.type_count())),
      ("enumCount", stat_number(stats.enum_count())),
      ("elementsCount", stat_number(stats.elements_count())),
      ("propertiesCount", stat_number(stats.properties_count())),
      ("valuesCount", stat_number(stats.values_count())),
      ("discriminatorCount", stat_number(stats.discriminator_count())),
      ("requiredPropertyCount", stat_number(stats.required_property_count())),
      ("optionalPropertyCount", stat_number(stats.optional_property_count())),
      (
        "discriminatorBranchCount",
        stat_number(stats.discriminator_branch_count()),
      ),
    ]),
  )
}

///|
pub fn schema_node_info_to_json(info : SchemaNodeInfo) -> Json {
  Json::object(
    Map([
      ("path", Json::string(info.path().to_string())),
      ("form", Json::string(info.form())),
      ("shape", Json::string(info.shape())),
      ("nullable", Json::boolean(info.is_nullable())),
      ("childCount", stat_number(info.child_count())),
    ]),
  )
}

///|
pub fn validation_report_to_json(report : ValidationReport) -> Json {
  Json::object(
    Map([
      ("valid", Json::boolean(report.is_valid())),
      ("truncated", Json::boolean(report.is_truncated())),
      ("visitedNodes", stat_number(report.visited_nodes())),
      ("errors", diagnostics_to_json(report.errors())),
    ]),
  )
}

///|
pub fn schema_report_json(document : SchemaDocument) -> Json {
  let nodes = schema_inventory(document).map(schema_node_info_to_json)
  let unused = unused_definitions(document).map(name => Json::string(name))
  Json::object(
    Map([
      ("specification", Json::string(SPECIFICATION)),
      ("rootForm", Json::string(document.root().form_name())),
      ("rootShape", Json::string(schema_shape(document.root()))),
      ("statistics", schema_stats_to_json(analyze_schema(document))),
      ("nodes", Json::array(nodes)),
      ("unusedDefinitions", Json::array(unused)),
      ("lint", diagnostics_to_json(lint_schema(document))),
    ]),
  )
}

///|
pub fn schema_report_string(
  document : SchemaDocument,
  pretty? : Bool = true,
) -> String {
  let value = schema_report_json(document)
  if pretty {
    let output = StringBuilder()
    write_report_pretty_json(output, value, 0, 2)
    output.to_string()
  } else {
    value.stringify(escape_slash=false)
  }
}

///|
pub fn schema_report_markdown(document : SchemaDocument) -> String {
  let stats = analyze_schema(document)
  let output = StringBuilder()
  output.write_string("# MoonJTD schema report\n\n")
  output.write_string("- Specification: ")
  output.write_string(SPECIFICATION)
  output.write_string("\n- Root form: ")
  output.write_string(document.root().form_name())
  output.write_string("\n- Root shape: `")
  output.write_string(schema_shape(document.root()))
  output.write_string("`\n- Schema nodes: ")
  output.write_string(stats.node_count().to_string())
  output.write_string("\n- Maximum depth: ")
  output.write_string(stats.max_depth().to_string())
  output.write_string("\n- Definitions: ")
  output.write_string(stats.definition_count().to_string())
  output.write_string("\n- References: ")
  output.write_string(stats.reference_count().to_string())
  output.write_string("\n\n## Node inventory\n\n")
  output.write_string("| Path | Form | Shape | Nullable | Children |\n")
  output.write_string("|---|---|---|---:|---:|\n")
  for info in schema_inventory(document) {
    let path = if info.path().is_root() {
      "`<root>`"
    } else {
      "`" + info.path().to_string() + "`"
    }
    output.write_string("| ")
    output.write_string(path)
    output.write_string(" | ")
    output.write_string(info.form())
    output.write_string(" | `")
    output.write_string(info.shape())
    output.write_string("` | ")
    output.write_string(if info.is_nullable() { "yes" } else { "no" })
    output.write_string(" | ")
    output.write_string(info.child_count().to_string())
    output.write_string(" |\n")
  }
  let lint = lint_schema(document)
  output.write_string("\n## Lint\n\n")
  if lint.is_empty() {
    output.write_string("No lint findings.\n")
  } else {
    for diagnostic in lint {
      output.write_string("- `")
      output.write_string(diagnostic.code().name())
      output.write_string("`: ")
      output.write_string(diagnostic.message())
      output.write_string("\n")
    }
  }
  output.to_string()
}
