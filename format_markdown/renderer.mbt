///|
/// Markdown RenderAdapter — converts parsed Markdown body to HTML.
/// Supports: headings, paragraphs, bold, italic, code, links, lists, code blocks.

///|
/// Render a ParsedDocument body to HTML.
pub fn render(parsed : @core.ParsedDocument) -> String {
  let md = parsed.source.body
  let lines = split_lines(md)
  let len = lines.length()
  let buf = @builtin.StringBuilder::new()
  let mut i = 0
  while i < len {
    let line = lines[i]
    // code block
    if line.has_prefix("```") {
      let code_lines : Array[String] = []
      i = i + 1
      while i < len && !lines[i].has_prefix("```") {
        code_lines.push(lines[i])
        i = i + 1
      }
      buf.write_string("<pre><code>")
      for j = 0; j < code_lines.length(); j = j + 1 {
        buf.write_string(escape_html(code_lines[j]))
        buf.write_char('\n')
      }
      buf.write_string("</code></pre>\n")
      i = i + 1
      continue
    }
    // heading
    let heading_level = heading_match(line)
    if heading_level > 0 {
      let text = line[heading_level + 1:].to_owned()
      buf.write_string("<h\{heading_level}>")
      buf.write_string(render_inline(text))
      buf.write_string("</h\{heading_level}>\n")
      i = i + 1
      continue
    }
    // horizontal rule
    if line == "---" || line == "***" || line == "___" {
      buf.write_string("<hr>\n")
      i = i + 1
      continue
    }
    // unordered list
    if line.has_prefix("- ") || line.has_prefix("* ") {
      buf.write_string("<ul>\n")
      while i < len {
        let li = lines[i]
        if li.has_prefix("- ") || li.has_prefix("* ") {
          let text = li[2:].to_owned()
          buf.write_string("<li>")
          buf.write_string(render_inline(text))
          buf.write_string("</li>\n")
          i = i + 1
        } else {
          break
        }
      }
      buf.write_string("</ul>\n")
      continue
    }
    // ordered list
    if line.length() >= 3 &&
      "0123456789".contains(line[0:1]) &&
      line[1:2] == ". " {
      buf.write_string("<ol>\n")
      while i < len {
        let li = lines[i]
        let dot_pos = li.find(". ")
        match dot_pos {
          Some(p) => {
            let text = li[p + 2:].to_owned()
            buf.write_string("<li>")
            buf.write_string(render_inline(text))
            buf.write_string("</li>\n")
            i = i + 1
          }
          None => break
        }
      }
      buf.write_string("</ol>\n")
      continue
    }
    // blockquote
    if line.has_prefix("> ") {
      buf.write_string("<blockquote>\n")
      while i < len && lines[i].has_prefix("> ") {
        let text = lines[i][2:].to_owned()
        buf.write_string("<p>")
        buf.write_string(render_inline(text))
        buf.write_string("</p>\n")
        i = i + 1
      }
      buf.write_string("</blockquote>\n")
      continue
    }
    // paragraph (skip blank lines)
    if line == "" {
      i = i + 1
      continue
    }
    buf.write_string("<p>")
    buf.write_string(render_inline(line))
    buf.write_string("</p>\n")
    i = i + 1
  }
  buf.to_string()
}

///|
/// Split body into lines.
fn split_lines(body : String) -> Array[String] {
  let result : Array[String] = []
  let len = body.length()
  let mut start = 0
  for i = 0; i < len; i = i + 1 {
    if body[i:i + 1] == "\n" {
      result.push(body[start:i].to_owned())
      start = i + 1
    }
  }
  // last line
  if start < len {
    result.push(body[start:].to_owned())
  } else if start == len {
    result.push("")
  }
  result
}

///|
/// Check if a line is a heading, return level (1-6) or 0.
fn heading_match(line : String) -> Int {
  let len = line.length()
  let mut level = 0
  for i = 0; i < len && i < 6 && line[i:i + 1] == "#"; i = i + 1 {
    level = level + 1
  }
  if level > 0 && level <= 6 && len > level && line[level:level + 1] == " " {
    return level
  }
  0
}

///|
/// Render inline Markdown (bold, italic, code, links).
fn render_inline(text : String) -> String {
  let buf = @builtin.StringBuilder::new()
  let len = text.length()
  let mut i = 0
  while i < len {
    let ch = text[i:i + 1]
    // code span
    if ch == "`" {
      let close = find_substr(text, "`", i + 1)
      match close {
        Some(cp) => {
          buf.write_string("<code>")
          buf.write_string(text[i + 1:cp].to_owned())
          buf.write_string("</code>")
          i = cp + 1
        }
        None => {
          buf.write_char('`')
          i = i + 1
        }
      }
      continue
    }
    // image ![alt](url)
    if ch == "!" && i + 1 < len && text[i + 1:i + 2] == "[" {
      let close_bracket = find_substr(text, "](", i + 2)
      let close_paren = match close_bracket {
        Some(cb) => find_substr(text, ")", cb + 2)
        None => None
      }
      match (close_bracket, close_paren) {
        (Some(cb), Some(cp)) => {
          let alt = text[i + 2:cb].to_owned()
          let url = text[cb + 2:cp].to_owned()
          buf.write_string("<img src=\"\{url}\" alt=\"\{alt}\">")
          i = cp + 1
        }
        _ => {
          buf.write_string("![")
          i = i + 2
        }
      }
      continue
    }
    // link [text](url)
    if ch == "[" {
      let close_bracket = find_substr(text, "](", i + 1)
      let close_paren = match close_bracket {
        Some(cb) => find_substr(text, ")", cb + 2)
        None => None
      }
      match (close_bracket, close_paren) {
        (Some(cb), Some(cp)) => {
          let link_text = text[i + 1:cb].to_owned()
          let url = text[cb + 2:cp].to_owned()
          buf.write_string("<a href=\"\{url}\">")
          buf.write_string(link_text)
          buf.write_string("</a>")
          i = cp + 1
        }
        _ => {
          buf.write_char('[')
          i = i + 1
        }
      }
      continue
    }
    // bold **text**
    if ch == "*" && i + 1 < len && text[i + 1:i + 2] == "*" {
      let close = find_substr(text, "**", i + 2)
      match close {
        Some(cp) => {
          buf.write_string("<strong>")
          buf.write_string(text[i + 2:cp].to_owned())
          buf.write_string("</strong>")
          i = cp + 2
        }
        None => {
          buf.write_string("**")
          i = i + 2
        }
      }
      continue
    }
    // italic *text*
    if ch == "*" {
      let close = find_substr(text, "*", i + 1)
      match close {
        Some(cp) => {
          buf.write_string("<em>")
          buf.write_string(text[i + 1:cp].to_owned())
          buf.write_string("</em>")
          i = cp + 1
        }
        None => {
          buf.write_char('*')
          i = i + 1
        }
      }
      continue
    }
    // escape HTML special chars
    buf.write_string(escape_html(ch.to_owned()))
    i = i + 1
  }
  buf.to_string()
}

///|
/// Escape HTML special characters.
fn escape_html(s : String) -> String {
  let buf = @builtin.StringBuilder::new()
  let len = s.length()
  for i = 0; i < len; i = i + 1 {
    let ch = s[i:i + 1]
    if ch == "&" {
      buf.write_string("&amp;")
    } else if ch == "<" {
      buf.write_string("&lt;")
    } else if ch == ">" {
      buf.write_string("&gt;")
    } else if ch == "\"" {
      buf.write_string("&quot;")
    } else {
      buf.write_string(ch.to_owned())
    }
  }
  buf.to_string()
}
