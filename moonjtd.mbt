///|
/// Semantic version of the public MoonJTD API.
pub const VERSION : String = "0.1.0"

///|
/// The RFC implemented by this package.
pub const SPECIFICATION : String = "RFC 8927"

///|
/// Return a compact identity suitable for CLI version output.
pub fn version_banner() -> String {
  "MoonJTD " + VERSION + " (" + SPECIFICATION + ")"
}
