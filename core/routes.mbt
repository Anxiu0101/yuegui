///|
/// Route computation from file paths.
///
/// Rules:
/// - `content/index.md` → `/`
/// - `content/guide/index.md` → `/guide/`
/// - `content/guide/getting-started.md` → `/guide/getting-started/`
///
/// The `source_dir` prefix (e.g. "content") is stripped from the
/// filepath before route computation.
pub fn filepath_to_route(filepath : String, source_dir : String) -> String {
  let rel = if filepath.has_prefix(source_dir + "/") {
    let n = source_dir.length() + 1
    filepath[n:].to_owned()
  } else {
    filepath
  }
  let without_ext = strip_extension(rel)
  if without_ext == "index" || without_ext.has_suffix("/index") {
    let n = without_ext.length()
    let dir_end = if without_ext == "index" { 0 } else { n - 6 }
    let dir = if dir_end == 0 { "" } else { without_ext[0:dir_end].to_owned() }
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
