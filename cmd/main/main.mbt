///|
extern "js" fn read_text_file(path : String) -> String? =
  #| function(path) {
  #|   try {
  #|     const fs = process.getBuiltinModule('node:fs');
  #|     return fs.readFileSync(path, 'utf8');
  #|   } catch (_) {
  #|     return undefined;
  #|   }
  #| }

///|
extern "js" fn write_text_file(path : String, text : String) -> Bool =
  #| function(path, text) {
  #|   try {
  #|     const fs = process.getBuiltinModule('node:fs');
  #|     fs.writeFileSync(path, text, 'utf8');
  #|     return true;
  #|   } catch (_) {
  #|     return false;
  #|   }
  #| }

///|
extern "js" fn set_exit_code(code : Int) -> Unit =
  #| function(code) {
  #|   if (typeof process !== 'undefined') process.exitCode = code;
  #| }

///|
fn usage() -> Unit {
  println(@jtd.version_banner())
  println("MoonBit-native JSON Type Definition toolkit")
  println("Usage:")
  println("  moonjtd check <schema.jtd.json>")
  println("  moonjtd validate <schema.jtd.json> <instance.json>")
  println("  moonjtd generate <schema.jtd.json> <RootType> [output.mbt]")
  println("  moonjtd inspect <schema.jtd.json>")
  println("  moonjtd format <schema.jtd.json> [output.json]")
  println("  moonjtd --version")
}

///|
fn find_command(args : Array[String]) -> (String, Int)? {
  for index, value in args {
    match value {
      "check" | "validate" | "generate" | "inspect" | "format" =>
        return Some((value, index))
      _ => ()
    }
  }
  None
}

///|
fn print_diagnostic(diagnostic : @jtd.Diagnostic) -> Unit {
  println(diagnostic.to_string())
}

///|
fn print_diagnostics(diagnostics : Array[@jtd.Diagnostic]) -> Unit {
  for diagnostic in diagnostics {
    print_diagnostic(diagnostic)
  }
}

///|
fn load_schema(path : String) -> @jtd.SchemaDocument? {
  let text = match read_text_file(path) {
    Some(value) => value
    None => {
      println("error: cannot read schema file " + path)
      return None
    }
  }
  match @jtd.parse_checked_schema(text) {
    Ok(document) => Some(document)
    Err(diagnostics) => {
      println("error: invalid JTD schema " + path)
      print_diagnostics(diagnostics)
      None
    }
  }
}

///|
fn load_json(path : String) -> Json? {
  let text = match read_text_file(path) {
    Some(value) => value
    None => {
      println("error: cannot read JSON file " + path)
      return None
    }
  }
  Some(@json.parse(text)) catch {
    error => {
      println("error: invalid JSON in " + path + ": " + error.to_string())
      None
    }
  }
}

///|
fn run_check(args : Array[String], index : Int) -> Int {
  guard index + 1 < args.length() else {
    usage()
    return 2
  }
  match load_schema(args[index + 1]) {
    None => 1
    Some(document) => {
      let lint = @jtd.lint_schema(document)
      println("VALID")
      println(@jtd.analyze_schema(document).to_string())
      if !lint.is_empty() {
        println("lint warnings:")
        print_diagnostics(lint)
      }
      0
    }
  }
}

///|
fn run_validate(args : Array[String], index : Int) -> Int {
  guard index + 2 < args.length() else {
    usage()
    return 2
  }
  let document = match load_schema(args[index + 1]) {
    Some(value) => value
    None => return 1
  }
  let value = match load_json(args[index + 2]) {
    Some(value) => value
    None => return 2
  }
  let report = @jtd.validate_with(
    document,
    value,
    @jtd.ValidationOptions::default(),
  )
  if report.is_valid() {
    println("VALID")
    println("visited nodes: " + report.visited_nodes().to_string())
    0
  } else {
    println("INVALID")
    print_diagnostics(report.errors())
    if report.is_truncated() {
      println("validation stopped at a configured resource limit")
    }
    1
  }
}

///|
fn run_generate(args : Array[String], index : Int) -> Int {
  guard index + 2 < args.length() else {
    usage()
    return 2
  }
  let document = match load_schema(args[index + 1]) {
    Some(value) => value
    None => return 1
  }
  let source = match
    @jtd.generate_moonbit_types(document, root_name=args[index + 2]) {
    Ok(value) => value
    Err(@jtd.CodegenDiagnostic(diagnostic)) => {
      print_diagnostic(diagnostic)
      return 1
    }
  }
  if index + 3 < args.length() {
    let path = args[index + 3]
    if !write_text_file(path, source) {
      println("error: cannot write generated source " + path)
      return 2
    }
    println("generated " + path)
  } else {
    println(source)
  }
  0
}

///|
fn run_inspect(args : Array[String], index : Int) -> Int {
  guard index + 1 < args.length() else {
    usage()
    return 2
  }
  let document = match load_schema(args[index + 1]) {
    Some(value) => value
    None => return 1
  }
  let stats = @jtd.analyze_schema(document)
  println("root form: " + document.root().form_name())
  println("root shape: " + @jtd.schema_shape(document.root()))
  println("definitions: " + document.definition_count().to_string())
  println("nodes: " + stats.node_count().to_string())
  println("maximum depth: " + stats.max_depth().to_string())
  println("references: " + stats.reference_count().to_string())
  let unused = @jtd.unused_definitions(document)
  if unused.is_empty() {
    println("unused definitions: none")
  } else {
    println("unused definitions:")
    for name in unused {
      println("  " + name)
    }
  }
  0
}

///|
fn run_format(args : Array[String], index : Int) -> Int {
  guard index + 1 < args.length() else {
    usage()
    return 2
  }
  let document = match load_schema(args[index + 1]) {
    Some(value) => value
    None => return 1
  }
  let output = @jtd.schema_to_pretty_string(document)
  if index + 2 < args.length() {
    let path = args[index + 2]
    if !write_text_file(path, output + "\n") {
      println("error: cannot write formatted schema " + path)
      return 2
    }
    println("formatted " + path)
  } else {
    println(output)
  }
  0
}

///|
fn dispatch(args : Array[String]) -> Int {
  for value in args {
    if value == "--version" || value == "-V" {
      println(@jtd.version_banner())
      return 0
    }
  }
  match find_command(args) {
    None => {
      usage()
      2
    }
    Some(("check", index)) => run_check(args, index)
    Some(("validate", index)) => run_validate(args, index)
    Some(("generate", index)) => run_generate(args, index)
    Some(("inspect", index)) => run_inspect(args, index)
    Some(("format", index)) => run_format(args, index)
    Some(_) => 2
  }
}

///|
fn main {
  set_exit_code(dispatch(@env.args()))
}
