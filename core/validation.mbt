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
