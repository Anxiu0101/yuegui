///|
/// Site configuration: all user-facing settings for a Yuegui site.
pub(all) struct SiteConfig {
  title : String
  language : String
  base_url : String
  source_dir : String
  theme_dir : String
  output_dir : String
  typst_mode : String
  typst_fallback : String
  dev_port : Int
  dev_host : String
}

///|
/// Default site configuration values.
pub fn default_site_config() -> SiteConfig {
  {
    title: "My Site",
    language: "en",
    base_url: "",
    source_dir: "content",
    theme_dir: "theme",
    output_dir: "public",
    typst_mode: "semantic-html",
    typst_fallback: "svg-embed",
    dev_port: 3000,
    dev_host: "127.0.0.1",
  }
}
