///|
/// Site configuration: all user-facing settings for a Yuegui site.
pub(all) struct YueguiConfig {
  title : String
  description : String
  language : String
  base_url : String
  source_dir : String
  theme_dir : String
  output_dir : String
  auto_navigation : Bool
  navigation : NavigationConfig
  /// e.g. { "toc": { "permalink": "#", "baselevel": 1 }, "code-copy": true }
  /// Each extension defines its own value structure.
  markdown_extensions : Map[String, ConfigJson]
  /// Plugin configuration. Placeholder for future ecosystem.
  /// Empty array means no plugins enabled.
  plugins : Array[PluginConfig]
  /// Extra data for themes / plugins.
  /// Analogous to Hugo's [params].
  extra : Map[String, ConfigJson]
  typst_mode : String
  typst_fallback : String
  dev_port : Int
  dev_host : String
}

///|
/// Flexible JSON-like value for extensible configuration (markdown_extensions, extra, plugin options).
pub(all) enum ConfigJson {
  CJNull
  CJBool(Bool)
  CJInt(Int)
  CJDouble(Double)
  CJString(String)
  CJArray(Array[ConfigJson])
  CJObject(Map[String, ConfigJson])
}

///|
/// Default site configuration values.
pub fn default_yuegui_config() -> YueguiConfig {
  {
    title: "My Site",
    description: "",
    language: "en",
    base_url: "",
    source_dir: "content",
    theme_dir: "theme",
    output_dir: "public",
    auto_navigation: false,
    navigation: { nav: [], sidebar: {} },
    markdown_extensions: {},
    plugins: [],
    extra: {},
    typst_mode: "semantic-html",
    typst_fallback: "svg-embed",
    dev_port: 3000,
    dev_host: "127.0.0.1",
  }
}
