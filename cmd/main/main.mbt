///|
/// Entry point for Yuegui CLI (dev mode).
/// Uses default config; users create their own main.mbt for their site.
fn main {
  @cli.dispatch(@core.default_yuegui_config())
}
