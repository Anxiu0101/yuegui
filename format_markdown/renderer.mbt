///|
/// Markdown RenderAdapter — delegates to mizchi/markdown for parsing and HTML generation.
/// Supports: all CommonMark features via mizchi/markdown, plus heading ID injection.

///|
/// Render a Markdown body string to HTML.
/// Uses mizchi/markdown for parsing and rendering, then injects heading IDs.
pub fn render(body : String) -> String {
  let result = @markdown.parse(body)
  let html = @markdown.render_html(result.document)
  inject_heading_ids(html)
}
