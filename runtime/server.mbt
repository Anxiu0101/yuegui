///|
/// HTTP dev server.
///
/// NOTE: MoonBit wasm-gc target does not support HTTP serving.
/// A real implementation requires the native backend and
/// moonbitlang/x networking support.
/// For development, use:
///   python -m http.server 3000 -d public/
///   npx serve public/

///|
pub fn start_dev_server(
  _host : String,
  _port : Int,
  _public_dir : String,
) -> Unit {
  println("dev: serving from public/ (requires native backend for auto-reload)")
  println("dev: # python -m http.server 3000 -d public/")
  println("dev: # npx serve public/")
}
