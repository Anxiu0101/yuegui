///|
/// Diagnostic types and message codes.

///|
/// Severity level of a diagnostic.
pub(all) enum DiagnosticLevel {
  Error
  Warning
  Info
}

///|
/// A build-time diagnostic with source location.
pub(all) struct Diagnostic {
  level : DiagnosticLevel
  code : String // e.g. "E001", "W001"
  file_path : String
  line : Int?
  column : Int?
  message : String
}

///|
/// Error codes.
pub const E001_BROKEN_LINK : String = "E001"

///|
pub const E002_ROUTE_COLLISION : String = "E002"

///|
pub const E003_MISSING_FRONTMATTER : String = "E003"

///|
pub const E004_UNKNOWN_FORMAT : String = "E004"

///|
pub const E005_MISSING_TEMPLATE : String = "E005"

///|
pub const E006_TYPST_COMPILE_FAILED : String = "E006"

///|
/// Warning codes.
pub const W001_TYPST_LAYOUT_WARNING : String = "W001"

///|
pub const W002_SVG_EMBED_ACCESSIBILITY : String = "W002"

///|
pub const W003_ORPHAN_PAGE : String = "W003"

///|
/// Create an error diagnostic.
pub fn error(
  code : String,
  file_path : String,
  line : Int?,
  column : Int?,
  message : String,
) -> Diagnostic {
  { level: DiagnosticLevel::Error, code, file_path, line, column, message }
}

///|
/// Create a warning diagnostic.
pub fn warning(
  code : String,
  file_path : String,
  line : Int?,
  column : Int?,
  message : String,
) -> Diagnostic {
  { level: DiagnosticLevel::Warning, code, file_path, line, column, message }
}

///|
/// Create an info diagnostic.
pub fn info(
  code : String,
  file_path : String,
  line : Int?,
  column : Int?,
  message : String,
) -> Diagnostic {
  { level: DiagnosticLevel::Info, code, file_path, line, column, message }
}
