///|
/// File watcher — monitors directory for changes.
///
/// NOTE: requires native backend and moonbitlang/x or OS-level FFI.
/// Stub for wasm-gc target.

///|
pub fn watch_dir(_dir : String, _on_change : () -> Unit) -> Unit {
  // TODO: implement with native filesystem events
}
