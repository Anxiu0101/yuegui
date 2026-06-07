///|
/// CLI command dispatch using @argparse.
/// Provides full --help and --version support.

///|
/// Parse CLI args and dispatch to the matching subcommand with site config.
pub fn dispatch(config : @core.YueguiConfig) -> Unit {
  let cmd = build_parser()
  let matches = try? cmd.parse()
  match matches {
    Ok(m) => handle_matches(config, m)
    Err(_) => ()
  }
}

///|
/// Build the @argparse Command tree.
fn build_parser() -> @argparse.Command {
  let init = @argparse.Command::new(
    "init",
    about="Create a new site scaffold",
    positionals=[@argparse.PositionArg::new("site", about="Site name")],
  )
  let build = @argparse.Command::new(
    "build",
    about="Build static site to output directory",
  )
  let dev = @argparse.Command::new(
    "dev",
    about="Start development server with live reload",
  )
  let check = @argparse.Command::new(
    "check",
    about="Validate content without emitting output",
  )
  let post_scan = @argparse.Command::new(
    "post-scan",
    about="Scan content/ and generate nav.mbt",
  )
  let page = @argparse.Command::new("page", about="Scaffold a new page", positionals=[
    @argparse.PositionArg::new("slug", about="Page slug"),
  ])
  let post = @argparse.Command::new("post", about="Scaffold a new blog post", positionals=[
    @argparse.PositionArg::new("slug", about="Post slug"),
  ])
  let cmd_new = @argparse.Command::new(
    "new",
    about="Scaffold new content",
    subcommands=[page, post],
    arg_required_else_help=true,
    subcommand_required=true,
  )

  @argparse.Command::new(
    "yuegui",
    about="Yuegui — MoonBit-native static site generator",
    version="0.1.0",
    subcommands=[init, build, dev, check, post_scan, cmd_new],
    arg_required_else_help=true,
  )
}

///|
fn handle_matches(
  config : @core.YueguiConfig,
  matches : @argparse.Matches,
) -> Unit {
  match matches.subcommand {
    Some(("init", m)) => {
      let site = m.values.get_or_default("site", ["site"])[0]
      cmd_init(site)
    }
    Some(("build", _)) => run_build(config)
    Some(("dev", _)) => run_dev(config)
    Some(("check", _)) => run_check(config)
    Some(("post-scan", _)) => cmd_post_scan(config.source_dir, "mbt")
    Some(("new", new_m)) => handle_new(new_m)
    Some((name, _)) => println("unknown command: \{name}")
    None => println("yuegui --help for usage")
  }
}

///|
fn cmd_init(site_name : String) -> Unit {
  let site_dir = site_name
  println("Creating site: \{site_name}")

  let _ = try? @runtime.create_dir(site_dir)
  let _ = try? @runtime.create_dir("\{site_dir}/content")
  let _ = try? @runtime.create_dir("\{site_dir}/theme")
  let _ = try? @runtime.create_dir("\{site_dir}/theme/layouts")
  let _ = try? @runtime.create_dir("\{site_dir}/theme/assets")

  let _ = try? @runtime.write_file(
    "\{site_dir}/moon.mod",
    init_moon_mod(site_name),
  )
  let _ = try? @runtime.write_file("\{site_dir}/moon.pkg", init_moon_pkg())
  let _ = try? @runtime.write_file(
    "\{site_dir}/main.mbt",
    init_main_mbt(site_name),
  )
  let _ = try? @runtime.write_file("\{site_dir}/.gitignore", init_gitignore())
  let _ = try? @runtime.write_file("\{site_dir}/yuegui.bat", init_yuegui_bat())
  let _ = try? @runtime.write_file("\{site_dir}/yuegui.sh", init_yuegui_sh())

  let _ = try? @runtime.write_file(
    "\{site_dir}/content/index.md",
    index_markdown(site_name),
  )
  let _ = try? @runtime.write_file(
    "\{site_dir}/theme/layouts/default.html",
    default_layout(),
  )
  let _ = try? @runtime.write_file(
    "\{site_dir}/theme/layouts/post.html",
    post_layout(),
  )
  let _ = try? @runtime.write_file(
    "\{site_dir}/theme/assets/style.css",
    default_stylesheet(),
  )

  println("")
  println("Done! Run:")
  println("  cd \{site_dir}")
  println("  moon update")
  println("  yuegui build")
  println("  yuegui dev")
  println("  yuegui check")
}

///|
fn cmd_post_scan(source_dir : String, format : String) -> Unit {
  println("post-scan: scanning \{source_dir}/...")
  scan_and_write_nav(source_dir, format)
  println("post-scan: done")
}

///|
fn handle_new(matches : @argparse.Matches) -> Unit {
  match matches.subcommand {
    Some(("page", m)) => {
      let slug = m.values.get_or_default("slug", ["page"])[0]
      let path = "content/\{slug}/index.md"
      println("  \{path}")
      let _ = try? @runtime.write_file(path, page_template(slug))
    }
    Some(("post", m)) => {
      let slug = m.values.get_or_default("slug", ["post"])[0]
      let path = "content/blog/\{slug}/index.md"
      println("  \{path}")
      let _ = try? @runtime.write_file(path, post_template(slug))
    }
    Some((name, _)) => println("unknown: yuegui new \{name}")
    None => println("yuegui new --help for usage")
  }
}
