///|
/// Yuegui — MoonBit-native static site generator.

///|
/// Dispatch a CLI command with the given site configuration.
/// This is the main entry point for user sites.
pub fn dispatch(config : @core.SiteConfig) -> Unit {
  @cli.dispatch(config)
}
