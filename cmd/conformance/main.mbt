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
extern "js" fn set_exit_code(code : Int) -> Unit =
  #| function(code) {
  #|   if (typeof process !== 'undefined') process.exitCode = code;
  #| }

///|
fn path_from_json(value : Json) -> String? {
  guard value is Array(segments) else { return None }
  let mut pointer = @jtd.JsonPointer::root()
  for segment in segments {
    guard segment is String(name) else { return None }
    pointer = pointer.property(name)
  }
  Some(pointer.to_string())
}

///|
fn pair_key(instance_path : String, schema_path : String) -> String {
  instance_path.length().to_string() + ":" + instance_path + schema_path
}

///|
fn increment(counts : Map[String, Int], key : String) -> Unit {
  match counts.get(key) {
    Some(value) => counts.set(key, value + 1)
    None => counts.set(key, 1)
  }
}

///|
fn same_counts(left : Map[String, Int], right : Map[String, Int]) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for key, value in left {
    if right.get(key) != Some(value) {
      return false
    }
  }
  true
}

///|
fn expected_error_counts(value : Json) -> Map[String, Int]? {
  guard value is Array(errors) else { return None }
  let counts : Map[String, Int] = Map([])
  for error in errors {
    guard error is Object(object) else { return None }
    guard object.get("instancePath") is Some(instance_value) else {
      return None
    }
    guard object.get("schemaPath") is Some(schema_value) else { return None }
    guard path_from_json(instance_value) is Some(instance_path) else {
      return None
    }
    guard path_from_json(schema_value) is Some(schema_path) else { return None }
    increment(counts, pair_key(instance_path, schema_path))
  }
  Some(counts)
}

///|
fn actual_error_counts(errors : Array[@jtd.Diagnostic]) -> Map[String, Int] {
  let counts : Map[String, Int] = Map([])
  for error in errors {
    increment(
      counts,
      pair_key(
        error.instance_path().to_string(),
        error.schema_path().to_string(),
      ),
    )
  }
  counts
}

///|
fn run_validation_suite(value : Json) -> (Int, Int) {
  guard value is Object(cases) else {
    println("validation corpus root is not an object")
    return (0, 1)
  }
  let mut passed = 0
  let mut failed = 0
  for name, case_value in cases {
    guard case_value is Object(case) else {
      println("FAIL validation: " + name + " (case is not an object)")
      failed += 1
      continue
    }
    guard case.get("schema") is Some(schema) else {
      println("FAIL validation: " + name + " (missing schema)")
      failed += 1
      continue
    }
    guard case.get("instance") is Some(instance) else {
      println("FAIL validation: " + name + " (missing instance)")
      failed += 1
      continue
    }
    guard case.get("errors") is Some(expected_value) else {
      println("FAIL validation: " + name + " (missing errors)")
      failed += 1
      continue
    }
    guard expected_error_counts(expected_value) is Some(expected) else {
      println("FAIL validation: " + name + " (malformed expected errors)")
      failed += 1
      continue
    }
    match @jtd.parse_checked_schema(schema.stringify(escape_slash=false)) {
      Err(_) => {
        println("FAIL validation: " + name + " (schema rejected)")
        failed += 1
      }
      Ok(document) => {
        let actual = actual_error_counts(@jtd.validate(document, instance))
        if same_counts(expected, actual) {
          passed += 1
        } else {
          println(
            "FAIL validation: " +
            name +
            " (expected " +
            expected_value.stringify(escape_slash=false) +
            ")",
          )
          failed += 1
        }
      }
    }
  }
  (passed, failed)
}

///|
fn run_invalid_schema_suite(value : Json) -> (Int, Int) {
  guard value is Object(cases) else {
    println("invalid-schema corpus root is not an object")
    return (0, 1)
  }
  let mut passed = 0
  let mut failed = 0
  for name, schema in cases {
    match @jtd.parse_checked_schema(schema.stringify(escape_slash=false)) {
      Err(_) => passed += 1
      Ok(_) => {
        println("FAIL invalid schema: " + name + " (schema accepted)")
        failed += 1
      }
    }
  }
  (passed, failed)
}

///|
fn load_json(path : String) -> Json? {
  guard read_text_file(path) is Some(text) else {
    println("cannot read " + path)
    return None
  }
  Some(@json.parse(text)) catch {
    error => {
      println("cannot parse " + path + ": " + error.to_string())
      None
    }
  }
}

///|
fn dispatch(args : Array[String]) -> Int {
  if args.length() < 3 {
    println("usage: conformance <validation.json> <invalid_schemas.json>")
    return 2
  }
  guard load_json(args[args.length() - 2]) is Some(validation) else { return 2 }
  guard load_json(args[args.length() - 1]) is Some(invalid_schemas) else {
    return 2
  }
  let (validation_passed, validation_failed) = run_validation_suite(validation)
  let (invalid_passed, invalid_failed) = run_invalid_schema_suite(
    invalid_schemas,
  )
  println(
    "validation: " +
    validation_passed.to_string() +
    " passed, " +
    validation_failed.to_string() +
    " failed",
  )
  println(
    "invalid schemas: " +
    invalid_passed.to_string() +
    " passed, " +
    invalid_failed.to_string() +
    " failed",
  )
  if validation_failed + invalid_failed == 0 {
    0
  } else {
    1
  }
}

///|
fn main {
  set_exit_code(dispatch(@env.args()))
}
