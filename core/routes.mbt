///|
/// Route computation from file paths.

///|
/// Compute the URL route from a source file path.
///
/// Rules:
/// - `index.md` → `/`
/// - `guide/index.md` → `/guide/`
/// - `guide/getting-started.md` → `/guide/getting-started/`
pub fn filepath_to_route(filepath : String) -> String {
  let without_ext = strip_extension(filepath)
  if without_ext.has_suffix("/index") {
    let n = without_ext.length()
    let dir_end = n - 6 // length of "/index"
    let dir = without_ext[0:dir_end].to_owned()
    return "/\{dir}"
  }
  return "/\{without_ext}/"
}

///|
/// Remove the file extension from a path.
fn strip_extension(path : String) -> String {
  let len = path.length()
  for i = len - 1; i >= 0; i = i - 1 {
    let ch = path[i:i + 1]
    if ch == "." {
      return path[0:i].to_owned()
    }
  }
  return path
}

///|
/// Detect SourceFormat from a file extension.
pub fn detect_format(path : String) -> SourceFormat? {
  if path.has_suffix(".md") {
    Some(SourceFormat::Markdown)
  } else if path.has_suffix(".typ") {
    Some(SourceFormat::Typst)
  } else if path.has_suffix(".html") {
    Some(SourceFormat::Html)
  } else {
    None
  }
}
