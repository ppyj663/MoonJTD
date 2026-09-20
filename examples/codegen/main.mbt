///|
fn main {
  let source = "{\"definitions\":{\"status\":{\"enum\":[\"pending\",\"ready\",\"failed\"]}},\"properties\":{\"id\":{\"type\":\"uint32\"},\"status\":{\"ref\":\"status\"}},\"optionalProperties\":{\"message\":{\"type\":\"string\"}}}"
  let document = match @jtd.parse_checked_schema(source) {
    Ok(value) => value
    Err(errors) => {
      for error in errors {
        println(error.to_string())
      }
      return
    }
  }
  println(@jtd.schema_report_markdown(document))
  match @jtd.generate_moonbit_types(document, root_name="Job") {
    Ok(generated) => {
      println("\nGenerated MoonBit:\n")
      println(generated)
    }
    Err(@jtd.CodegenDiagnostic(error)) => println(error.to_string())
  }
}
