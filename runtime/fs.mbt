///|
/// Filesystem abstraction — all disk I/O goes here.
///
/// NOTE: Requires `moonbitlang/x` or host file functions.
/// Network unavailable during scaffold; stubs return empty defaults.
/// Real implementation when `moon add moonbitlang/x` works.

///|
/// Read file contents as a String.
pub fn read_file(_path : String) -> String {
  // TODO: @fs.read(path) from moonbitlang/x
  ""
}

///|
/// Write a String to a file.
pub fn write_file(_path : String, _content : String) -> Unit {
  // TODO: @fs.write(path, content) from moonbitlang/x
}

///|
/// Recursively walk a directory, returning relative file paths.
pub fn walk_dir(_dir : String) -> Array[String] {
  // TODO: @fs.walk or recursive read_dir from moonbitlang/x
  []
}
