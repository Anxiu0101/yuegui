///|
/// Markdown ParserAdapter: frontmatter, headings, wikilinks.

///|
/// Parse a Markdown source document into a ParsedDocument.
pub fn parse(source : @core.SourceDocument) -> @core.ParsedDocument {
  let (frontmatter_extra, body) = split_frontmatter(source.body)
  let merged = merge_frontmatter(source.frontmatter, frontmatter_extra)
  let meta = extract_metadata(merged)
  let headings = extract_headings(body)
  let links = extract_wikilinks(body)

  let has_title = meta.title != ""
  let title = if has_title {
    Some(meta.title)
  } else if headings.length() > 0 {
    Some(headings[0].text)
  } else {
    None
  }

  let caps : @core.RenderCapabilities = {
    format: @core.SourceFormat::Markdown,
    mode: @core.RenderMode::SemanticHtml,
    fidelity: @core.FidelityLevel::Full,
    warnings: [],
  }

  {
    source,
    title,
    headings,
    links,
    assets: [],
    diagnostics: [],
    render_capabilities: caps,
  }
}

///|
/// Split frontmatter from body.
fn split_frontmatter(input : String) -> (Map[String, String], String) {
  let result : Map[String, String] = {}
  if !input.has_prefix("+++\n") {
    return (result, input)
  }
  // find closing +++
  let rest = input
  let close_pos = rest.after("\n+++\n")
  match close_pos {
    Some(after_close) => {
      let fm_len = rest.length() - 3 - after_close.length() - 4
      let fm_text = rest[4:4 + fm_len].to_owned()
      let body = rest[4 + fm_len + 4:].to_owned()
      (parse_toml_lines(fm_text), body)
    }
    None => (result, input)
  }
}

///|
/// Parse TOML-style key = "value" lines.
fn parse_toml_lines(text : String) -> Map[String, String] {
  let result : Map[String, String] = {}
  let len = text.length()
  let mut i = 0
  while i < len {
    let line_start = if i == 0 { 0 } else { i + 1 }
    // find end of line
    let mut line_end = len
    let mut j = line_start
    while j < len {
      if text[j:j + 1] == "\n" {
        line_end = j
        break
      }
      j = j + 1
    }
    let line = text[line_start:line_end].to_owned()
    let eq_pos = line.find("= ")
    match eq_pos {
      Some(p) => {
        let key = line[0:p].trim().to_owned()
        let val = line[p + 2:].trim().to_owned()
        let val = if val.has_prefix("\"") && val.has_suffix("\"") {
          val[1:val.length() - 1].to_owned()
        } else {
          val
        }
        result.set(key, val)
      }
      None => ()
    }
    i = j
  }
  result
}

///|
fn merge_frontmatter(
  base : Map[String, String],
  extra : Map[String, String],
) -> Map[String, String] {
  for key, value in extra {
    base.set(key, value)
  }
  base
}

///|
fn extract_metadata(fm : Map[String, String]) -> @core.PageMetadata {
  let title = fm.get_or_default("title", "")
  let description = fm.get("description")
  let date = fm.get("date")
  let author = fm.get("author")
  let draft = fm.get_or_default("draft", "false") == "true"
  let layout = fm.get_or_default("layout", "default")
  let weight_str = fm.get_or_default("weight", "0")
  let weight = parse_int(weight_str)
  { title, description, date, author, tags: [], draft, layout, weight }
}

///|
fn parse_int(s : String) -> Int {
  let digits = "0123456789"
  let mut result = 0
  let len = s.length()
  for i = 0; i < len; i = i + 1 {
    let ch = s[i:i + 1]
    if ch >= "0" && ch <= "9" {
      let pos = digits.find(ch)
      match pos {
        Some(p) => result = result * 10 + p
        None => ()
      }
    }
  }
  result
}

///|
/// Extract headings from Markdown body.
fn extract_headings(body : String) -> Array[@core.Heading] {
  let result : Array[@core.Heading] = []
  let len = body.length()
  let mut i = 0
  while i < len {
    let line_start = if i == 0 { 0 } else { i + 1 }
    let mut level = 0
    let mut j = line_start
    while j < len && body[j:j + 1] == "#" {
      level = level + 1
      j = j + 1
    }
    if level >= 1 && level <= 6 && j < len && body[j:j + 1] == " " {
      let text_start = j + 1
      let mut text_end = text_start
      while text_end < len && body[text_end:text_end + 1] != "\n" {
        text_end = text_end + 1
      }
      let text = body[text_start:text_end].to_owned()
      let slug = slugify(text)
      result.push({ level, text, id: slug })
      i = text_end
    } else {
      i = j
    }
  }
  result
}

///|
fn slugify(text : String) -> String {
  let lower = "abcdefghijklmnopqrstuvwxyz"
  let upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  let buf = @builtin.StringBuilder::new()
  let len = text.length()
  for i = 0; i < len; i = i + 1 {
    let ch = text[i:i + 1]
    let upper_pos = upper.find(ch)
    match upper_pos {
      Some(p) => buf.write_string(lower[p:p + 1].to_owned())
      None =>
        if ch == " " {
          buf.write_char('-')
        } else if (ch >= "a" && ch <= "z") ||
          (ch >= "0" && ch <= "9") ||
          ch == "-" {
          buf.write_string(ch.to_owned())
        }
    }
  }
  buf.to_string()
}

///|
/// Extract wikilinks [[target]] from body.
fn extract_wikilinks(body : String) -> Array[@core.Link] {
  let result : Array[@core.Link] = []
  let len = body.length()
  let mut pos = 0
  while pos < len {
    let open_pos = find_substr(body, "[[", pos)
    match open_pos {
      None => break
      Some(op) => {
        let close_pos = find_substr(body, "]]", op + 2)
        match close_pos {
          None => break
          Some(cp) => {
            let target = body[op + 2:cp].to_owned()
            let alias_pos = target.find("|")
            let bare_target = match alias_pos {
              Some(ap) => target[0:ap].to_owned()
              None => target
            }
            result.push({
              target: bare_target,
              kind: @core.LinkKind::Internal(bare_target),
            })
            pos = cp + 2
          }
        }
      }
    }
  }
  result
}

///|
fn find_substr(s : String, sub : String, start : Int) -> Int? {
  let len = s.length()
  let sub_len = sub.length()
  for i = start; i <= len - sub_len; i = i + 1 {
    if s[i:i + sub_len] == sub {
      return Some(i)
    }
  }
  None
}
