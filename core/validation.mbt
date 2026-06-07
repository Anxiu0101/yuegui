///|
/// Content validation: broken links, route collisions, missing frontmatter.

///|
/// Detect route collisions in the site.
pub fn check_route_collisions(site : Site) -> Site {
  let route_count : Map[String, Int] = {}
  for route in site.routes {
    let prev = route_count.get_or_default(route, 0)
    route_count.set(route, prev + 1)
  }
  let diagnostics = site.diagnostics
  for route, count in route_count {
    if count > 1 {
      diagnostics.push(
        error(
          E002_ROUTE_COLLISION,
          route,
          None,
          None,
          "Route '\{route}' is produced by \{count} source files.",
        ),
      )
    }
  }
  return { ..site, diagnostics, }
}

///|
/// Check for broken wikilinks across all pages.
pub fn check_broken_links(site : Site) -> Site {
  let diagnostics = site.diagnostics
  let routes_set : @set.Set[String] = @set.Set([], capacity=0)
  for route in site.routes {
    routes_set.add(route)
  }
  for _, page in site.pages {
    for target in page.outgoing_links {
      if !routes_set.contains(target) {
        diagnostics.push(
          error(
            E001_BROKEN_LINK,
            page.metadata.title,
            None,
            None,
            "Broken wikilink in '\{page.route}' → '\{target}' not found.",
          ),
        )
      }
    }
  }
  return { ..site, diagnostics, }
}

///|
/// Check all pages have a non-empty title derived.
pub fn check_missing_titles(site : Site) -> Site {
  let diagnostics = site.diagnostics
  for route, page in site.pages {
    if page.title == "" {
      diagnostics.push(
        warning(
          E003_MISSING_FRONTMATTER,
          route,
          None,
          None,
          "Page at '\{route}' has no title in frontmatter or headings.",
        ),
      )
    }
  }
  return { ..site, diagnostics, }
}

///|
/// Known template variable names available in the theme context.
/// Top-level keys that must exist for proper rendering.
let known_template_vars : Array[String] = [
  "site_title", "site_language", "site_pages", "site_nav", "page_title", "page_content",
  "page_route", "page_description", "page_date", "page_author", "this", "type", "text",
  "url", "children",
]

///|
/// Check that all template variables in the given layouts are known.
/// Returns diagnostics for any unknown variable references.
pub fn check_template_slots(layouts : Map[String, String]) -> Array[Diagnostic] {
  let result : Array[Diagnostic] = []
  for layout_name, template in layouts {
    let unknowns = find_unknown_vars(template)
    for var_name in unknowns {
      result.push(
        warning(
          E005_MISSING_TEMPLATE,
          "theme/layouts/\{layout_name}.html",
          None,
          None,
          "Unknown template variable '\{var_name}' in layout '\{layout_name}'.",
        ),
      )
    }
  }
  result
}

///|
/// Find all {{ variable }} references that are not in the known set.
fn find_unknown_vars(template : String) -> Array[String] {
  let result : Array[String] = []
  let len = template.length()
  let mut pos = 0
  while pos < len {
    let open = find_from(template, "{{", pos)
    match open {
      None => break
      Some(op) => {
        let close = find_from(template, "}}", op + 2)
        match close {
          None => break
          Some(cp) => {
            let inner = template[op + 2:cp].trim().to_owned()
            // skip block tags: #if, #each, /if, /each
            if inner.has_prefix("#") || inner.has_prefix("/") {
              pos = cp + 2
              continue
            }
            // skip this and this.field references
            if inner == "this" || inner.has_prefix("this.") {
              pos = cp + 2
              continue
            }
            // check if it's a known variable
            if !is_known_var(inner) {
              result.push(inner)
            }
            pos = cp + 2
          }
        }
      }
    }
  }
  result
}

///|
/// Check if a variable name is in the known set.
fn is_known_var(name : String) -> Bool {
  for k in known_template_vars {
    if name == k {
      return true
    }
  }
  false
}

///|
fn find_from(s : String, sub : String, start : Int) -> Int? {
  let len = s.length()
  let sub_len = sub.length()
  for i = start; i <= len - sub_len; i = i + 1 {
    if s[i:i + sub_len] == sub {
      return Some(i)
    }
  }
  None
}
