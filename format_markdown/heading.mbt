///|
/// Heading ID injection: post-process HTML to add id attributes to <h1>-<h6> tags.

///|
/// Scan HTML for heading tags and inject id="slug" attributes where missing.
pub fn inject_heading_ids(html : String) -> String {
  let buf = @builtin.StringBuilder::new()
  let len = html.length()
  let mut i = 0
  while i < len {
    if i + 2 < len && html[i:i + 2] == "<h" {
      let level_char = html[i + 2:i + 3].to_owned()
      if level_char >= "1" && level_char <= "6" {
        let tag_start = i
        let mut tag_end = i + 3
        // skip past any attributes in opening tag
        while tag_end < len && html[tag_end:tag_end + 1] != ">" {
          tag_end = tag_end + 1
        }
        if tag_end < len && html[tag_end:tag_end + 1] == ">" {
          let open_tag = html[tag_start:tag_end].to_owned()
          let content_start = tag_end + 1
          let close_tag = "</h\{level_char}>"
          let close_pos = find_substr(html, close_tag, content_start)
          match close_pos {
            Some(cp) => {
              let content = html[content_start:cp].to_owned()
              // check if heading already has id attribute
              if !has_attr(open_tag, "id") {
                buf.write_string(open_tag)
                buf.write_string(" id=\"")
                buf.write_string(slugify(strip_inline_html(content)))
                buf.write_string("\">")
              } else {
                buf.write_string(open_tag)
              }
              buf.write_string(content)
              buf.write_string(close_tag)
              i = cp + close_tag.length()
            }
            None => {
              buf.write_string(html[i:].to_owned())
              i = len
            }
          }
        } else {
          buf.write_string(html[i:i + 1].to_owned())
          i = i + 1
        }
      } else {
        buf.write_string(html[i:i + 1].to_owned())
        i = i + 1
      }
    } else {
      buf.write_string(html[i:i + 1].to_owned())
      i = i + 1
    }
  }
  buf.to_string()
}

///|
/// Check if an HTML tag string already has a given attribute.
fn has_attr(tag : String, attr : String) -> Bool {
  let len = tag.length()
  let attr_len = attr.length()
  for i = 1; i < len; i = i + 1 {
    let trimmed = tag[i:].trim_start()
    if trimmed.has_prefix(attr) &&
      trimmed.length() > attr_len &&
      trimmed[attr_len:attr_len + 1] == "=" {
      return true
    }
  }
  false
}

///|
/// Strip inline HTML tags from text to extract plain text for slug generation.
fn strip_inline_html(text : String) -> String {
  let buf = @builtin.StringBuilder::new()
  let len = text.length()
  let mut i = 0
  while i < len {
    if text[i:i + 1] == "<" {
      let close = find_substr(text, ">", i + 1)
      match close {
        Some(cp) => i = cp + 1
        None => {
          buf.write_string(text[i:].to_owned())
          i = len
        }
      }
    } else {
      buf.write_string(text[i:i + 1].to_owned())
      i = i + 1
    }
  }
  buf.to_string()
}
