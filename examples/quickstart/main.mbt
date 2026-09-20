///|
fn main {
  let schema = match
    @jtd.jtd_object()
    .required("id", @jtd.jtd_uint32())
    .required("name", @jtd.jtd_string())
    .optional("email", @jtd.jtd_string())
    .build() {
    Ok(value) => value
    Err(error) => {
      println(error.to_string())
      return
    }
  }
  let document = match @jtd.jtd_document(schema).build() {
    Ok(value) => value
    Err(errors) => {
      for error in errors {
        println(error.to_string())
      }
      return
    }
  }
  let valid = Json::object(
    Map([("id", Json::number(7.0)), ("name", Json::string("Ada"))]),
  )
  let invalid = Json::object(
    Map([
      ("id", Json::number(-1.0)),
      ("name", Json::boolean(false)),
      ("extra", Json::null()),
    ]),
  )
  let valid_report = @jtd.validate_with(
    document,
    valid,
    @jtd.ValidationOptions::default(),
  )
  println("valid example: " + valid_report.is_valid().to_string())
  let invalid_report = @jtd.validate_with(
    document,
    invalid,
    @jtd.ValidationOptions::default(),
  )
  println("invalid example: " + invalid_report.is_valid().to_string())
  for diagnostic in invalid_report.errors() {
    println(diagnostic.to_string())
  }
}
