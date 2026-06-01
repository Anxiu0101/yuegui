///|
/// Theme layout loader — discovers and loads layout files from theme/layouts/.

///|
/// Load layout files from the theme layouts directory.
/// Returns a map of layout_name -> template_content.
/// Layout names are basenames without the .html extension (e.g. "default", "post").
/// Returns empty map if the layouts directory doesn't exist or can't be read.
pub fn load_layouts(theme_path : String) -> Map[String, String] {
  let layouts_dir = "\{theme_path}/layouts"
  let files = try? @runtime.walk_dir(layouts_dir)
  let files = match files {
    Ok(f) => f
    Err(_) => return {}
  }
  let result : Map[String, String] = {}
  for file in files {
    if !file.has_suffix(".html") {
      continue
    }
    let name = layout_name(file)
    let content = try? @runtime.read_file(file)
    match content {
      Ok(c) => result.set(name, c)
      Err(_) => ()
    }
  }
  result
}

///|
/// Extract layout name from a theme file path.
/// "theme/layouts/default.html" -> "default"
fn layout_name(filepath : String) -> String {
  let base = basename(filepath)
  if base.has_suffix(".html") {
    base[0:base.length() - 5].to_owned()
  } else {
    base
  }
}

///|
/// Get the basename from a file path.
fn basename(path : String) -> String {
  let slash = find_last(path, "/")
  match slash {
    Some(i) => path[i + 1:].to_owned()
    None => path
  }
}

///|
/// Find the last occurrence of a substring.
fn find_last(s : String, sub : String) -> Int? {
  let len = s.length()
  let sub_len = sub.length()
  for i = len - sub_len; i >= 0; i = i - 1 {
    if s[i:i + sub_len] == sub {
      return Some(i)
    }
  }
  None
}

///|
/// Copy theme assets from theme/assets/ to public/assets/theme/.
pub fn copy_assets(theme_path : String, public_dir : String) -> Unit {
  let assets_source = "\{theme_path}/assets"
  let assets_target = "\{public_dir}/assets/theme"
  let files = try? @runtime.walk_dir(assets_source)
  let files = match files {
    Ok(f) => f
    Err(_) => return
  }
  let prefix_len = assets_source.length() + 1
  for file in files {
    let rel_path = if file.length() > prefix_len {
      file[prefix_len:].to_owned()
    } else {
      file
    }
    let dest = "\{assets_target}/\{rel_path}"
    let content = try? @runtime.read_file(file)
    match content {
      Ok(c) => ignore(try? @runtime.write_file(dest, c))
      Err(_) => ()
    }
  }
}
