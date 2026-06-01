///|
/// Theme template engine — variable substitution, conditionals, iteration.
///
/// Syntax:
///   {{ key }}                 — variable (dots = flat key)
///   {{#if key}} ... {{/if}}   — conditional (truthy = non-empty string / true / non-empty array)
///   {{#each key}} ... {{/each}} — iteration, items fields become top-level in sub-context

///|
/// A value in the template context.
pub(all) enum ContextValue {
  Str(String)
  Bool(Bool)
  Arr(Array[Map[String, ContextValue]])
}

///|
pub fn str(v : String) -> ContextValue {
  ContextValue::Str(v)
}

///|
pub fn bool(v : Bool) -> ContextValue {
  ContextValue::Bool(v)
}

///|
pub fn arr(v : Array[Map[String, ContextValue]]) -> ContextValue {
  ContextValue::Arr(v)
}

///|
pub struct TemplateContext {
  vars : Map[String, ContextValue]
}

///|
pub fn context() -> TemplateContext {
  { vars: {} }
}

///|
pub fn set(ctx : TemplateContext, key : String, value : ContextValue) -> Unit {
  ctx.vars.set(key, value)
}

///|
/// Render a template string with the given context.
pub fn render(template : String, ctx : TemplateContext) -> String {
  let buf = @builtin.StringBuilder::new()
  let len = template.length()
  let mut i = 0
  while i < len {
    let open = find_substr(template, "{{", i)
    match open {
      None => {
        buf.write_string(template[i:].to_owned())
        i = len
      }
      Some(op) => {
        buf.write_string(template[i:op].to_owned())
        if op + 3 < len && template[op + 2:op + 3] == "#" {
          i = handle_block_tag(template, op, buf, ctx)
        } else {
          let close = find_substr(template, "}}", op + 2)
          match close {
            Some(cp) => {
              let key = template[op + 2:cp].trim().to_owned()
              if key != "" {
                resolve_var(key, ctx, buf)
              }
              i = cp + 2
            }
            None => {
              buf.write_string("{{")
              i = op + 2
            }
          }
        }
      }
    }
  }
  buf.to_string()
}

///|
/// Handle {{#if ...}} / {{#each ...}} blocks.
fn handle_block_tag(
  template : String,
  op : Int,
  buf : @builtin.StringBuilder,
  ctx : TemplateContext,
) -> Int {
  let close = find_substr(template, "}}", op + 3)
  match close {
    None => {
      buf.write_string("{{")
      return op + 2
    }
    Some(cp) => {
      let tag = template[op + 3:cp].trim().to_owned()
      let tag_is_if = tag.length() > 3 && tag[0:3] == "if "
      let tag_is_each = tag.length() > 5 && tag[0:5] == "each "
      let keyword_len = if tag_is_if { 3 } else if tag_is_each { 5 } else { 0 }
      if keyword_len == 0 {
        buf.write_string(template[op:cp + 2].to_owned())
        return cp + 2
      }
      let key = tag[keyword_len:].trim().to_owned()
      let end_tag = "{{/" + tag[0:keyword_len].trim().to_owned() + "}}"
      let close_block = find_substr(template, end_tag, cp + 2)
      match close_block {
        None => {
          buf.write_string(template[op:cp + 2].to_owned())
          return cp + 2
        }
        Some(cb) => {
          let inner = template[cp + 2:cb].to_owned()
          if tag_is_if {
            let val = ctx.vars.get(key)
            let truthy = match val {
              Some(Str(s)) => s != "" && s != "false"
              Some(Bool(b)) => b
              Some(Arr(a)) => a.length() > 0
              None => false
            }
            if truthy {
              buf.write_string(render(inner, ctx))
            }
          } else if tag_is_each {
            let list_val = ctx.vars.get(key)
            match list_val {
              Some(Arr(items)) =>
                for item in items {
                  let sub = context()
                  // set all vars from current context
                  for k, v in ctx.vars {
                    sub.vars.set(k, v)
                  }
                  // override with each-item fields
                  for k, v in item {
                    sub.vars.set(k, v)
                  }
                  buf.write_string(render(inner, sub))
                }
              _ => ()
            }
          }
          return cb + end_tag.length()
        }
      }
    }
  }
}

///|
fn resolve_var(
  key : String,
  ctx : TemplateContext,
  buf : @builtin.StringBuilder,
) -> Unit {
  match ctx.vars.get(key) {
    Some(Str(s)) => buf.write_string(s)
    Some(Bool(b)) => buf.write_string(if b { "true" } else { "false" })
    Some(Arr(_)) => () // arrays can't be printed directly
    None => ()
  }
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
