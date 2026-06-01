///|
/// Filesystem abstraction — all disk I/O goes through here.
/// Uses `moonbitlang/x/fs` for native file operations.

///|
/// Read a text file from disk.
pub fn read_file(path : String) -> String raise @fs.IOError {
  @fs.read_file_to_string(path)
}

///|
/// Write a text string to a file.
pub fn write_file(path : String, content : String) -> Unit raise @fs.IOError {
  @fs.write_string_to_file(path, content)
}

///|
/// Recursively walk a directory, returning relative file paths.
pub fn walk_dir(dir : String) -> Array[String] raise @fs.IOError {
  let result : Array[String] = []
  let entries = @fs.read_dir(dir)
  let len = entries.length()
  for i = 0; i < len; i = i + 1 {
    let entry = entries[i]
    let full = "\{dir}/\{entry}"
    if @fs.is_dir(full) {
      let sub = walk_dir(full)
      let sub_len = sub.length()
      for j = 0; j < sub_len; j = j + 1 {
        result.push(sub[j])
      }
    } else {
      result.push(full)
    }
  }
  result
}
