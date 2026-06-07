///|
/// Core content model types: SourceDocument, ParsedDocument, SitePage, Site.

///|
/// Source format of a document, determined by file extension.
pub(all) enum SourceFormat {
  Markdown
  Typst
  Html
}

///|
/// A raw document read from disk, before format-specific body parsing.
pub(all) struct SourceDocument {
  path : String // relative to content root, e.g. "guide/getting-started.md"
  format : SourceFormat
  frontmatter : Map[String, String] // parsed key-value metadata
  body : String // raw body content
}

///|
/// A heading extracted from a parsed document.
pub(all) struct Heading {
  level : Int // 1–6
  text : String
  id : String // slugified anchor ID
}

///|
/// The kind of a link target.
pub(all) enum LinkKind {
  Internal(String) // wikilink or relative link, resolved to route
  External(String) // absolute URL
  Asset(String) // reference to a static asset
}

///|
/// A link found in a document, with source location.
pub(all) struct Link {
  target : String
  kind : LinkKind
}

///|
/// A static asset reference: image, stylesheet, or downloadable file.
pub(all) enum AssetKind {
  Image
  File
  Stylesheet
  Script
}

///|
/// A reference to a static asset, with source and target paths.
pub(all) struct AssetRef {
  source_path : String
  target_path : String // path in public/
  kind : AssetKind
}

///|
/// Reported rendering fidelity for a document.
pub(all) enum FidelityLevel {
  Full
  Partial
  Unknown
}

///|
/// Available Typst rendering modes.
pub(all) enum RenderMode {
  SemanticHtml
  SvgEmbed
  Artifact
}

///|
/// Describes what a format adapter can deliver at render time.
pub(all) struct RenderCapabilities {
  format : SourceFormat
  mode : RenderMode
  fidelity : FidelityLevel
  warnings : Array[String]
}

///|
/// The output of a ParserAdapter, ready for indexing.
pub(all) struct ParsedDocument {
  source : SourceDocument
  title : String?
  headings : Array[Heading]
  links : Array[Link]
  assets : Array[AssetRef]
  diagnostics : Array[Diagnostic]
  render_capabilities : RenderCapabilities
}

///|
/// Per-page metadata from frontmatter and document extraction.
pub(all) struct PageMetadata {
  title : String
  description : String?
  date : String? // ISO 8601
  author : String?
  tags : Array[String]
  draft : Bool // default false
  layout : String // theme layout name, e.g. "post"
  weight : Int // navigation sort order
}

///|
/// One page in the site graph — the unit that gets themed and emitted.
pub(all) struct SitePage {
  route : String // e.g. "/guide/getting-started/"
  title : String
  content_html : String // rendered body HTML
  source_format : SourceFormat
  metadata : PageMetadata
  outgoing_links : Array[String] // resolved routes of outgoing internal links
  headings : Array[Heading]
}

///|
/// Aggregate site state built during the index pass.
pub(all) struct Site {
  pages : Map[String, SitePage] // route → SitePage
  routes : Array[String] // all known routes
  diagnostics : Array[Diagnostic]
}

///|
/// A navigation item in a nav bar or sidebar.
pub(all) enum NavItem {
  /// Simple link: display text, URL
  Link(String, String)
  /// Group with children: group label, child items
  Group(String, Array[NavItem])
  /// Visual separator between groups
  Separator
}

///|
/// Navigation configuration for a site.
pub(all) struct NavigationConfig {
  /// Top navigation bar items
  nav : Array[NavItem]
  /// Sidebar, keyed by path prefix (same convention as VitePress)
  sidebar : Map[String, Array[NavItem]]
}

///|
/// Plugin configuration entry.
/// `name` is the MoonBit package name or registry identifier.
/// `options` is an arbitrary JSON-like map passed to the plugin on load.
pub(all) struct PluginConfig {
  name : String
  options : Map[String, ConfigJson]
}
