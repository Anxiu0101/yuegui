///|
/// Filesystem abstraction. Stubs — all disk I/O goes here.
pub fn read_file(_path : String) -> String {
  // TODO: read file via host FFI or MoonBit stdlib
  return ""
}

///|
pub fn write_file(_path : String, _content : String) -> Unit {
  // TODO: write file
}

///|
pub fn walk_dir(_dir : String) -> Array[String] {
  // TODO: recursively walk directory
  return []
}
