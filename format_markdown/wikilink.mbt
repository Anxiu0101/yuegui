///|
/// Wikilink resolution: rewrites [[target]] and [[target|display]] to standard markdown links
/// before the body is passed to mizchi/markdown.

///|
/// Resolve all [[wikilinks]] in the body using the link index.
/// The link_index maps page slugs (file path basenames) to resolved routes.
pub fn resolve_wikilinks(
  body : String,
  link_index : Map[String, String],
) -> String {
  let buf = @builtin.StringBuilder::new()
  let len = body.length()
  let mut i = 0
  while i < len {
    let open = find_substr(body, "[[", i)
    match open {
      None => {
        buf.write_string(body[i:].to_owned())
        i = len
      }
      Some(op) => {
        buf.write_string(body[i:op].to_owned())
        let close = find_substr(body, "]]", op + 2)
        match close {
          None => {
            buf.write_string(body[op:].to_owned())
            i = len
          }
          Some(cp) => {
            let raw = body[op + 2:cp].to_owned()
            let pipe = raw.find("|")
            let (target, display) = match pipe {
              Some(p) => (raw[:p].to_owned(), raw[p + 1:].to_owned())
              None => (raw, raw)
            }
            let resolved = link_index.get_or_default(target, "")
            if resolved != "" {
              buf.write_string("[")
              buf.write_string(display)
              buf.write_string("](")
              buf.write_string(resolved)
              buf.write_string(")")
            } else {
              buf.write_string("[")
              buf.write_string(display)
              buf.write_string("](#unresolved:")
              buf.write_string(target)
              buf.write_string(")")
            }
            i = cp + 2
          }
        }
      }
    }
  }
  buf.to_string()
}
