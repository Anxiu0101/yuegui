///|
/// CLI command dispatch using @argparse.
/// Provides full --help and --version support.

///|
/// Parse CLI args and dispatch to the matching subcommand.
pub fn dispatch() -> Unit {
  let cmd = build_parser()
  let matches = try? cmd.parse()
  match matches {
    Ok(m) => handle_matches(m)
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
    subcommands=[init, build, dev, check, cmd_new],
    arg_required_else_help=true,
  )
}

///|
fn handle_matches(matches : @argparse.Matches) -> Unit {
  match matches.subcommand {
    Some(("init", m)) => {
      let site = m.values.get_or_default("site", ["site"])[0]
      cmd_init(site)
    }
    Some(("build", _)) => println("yuegui build")
    Some(("dev", _)) => println("yuegui dev")
    Some(("check", _)) => run_check()
    Some(("new", new_m)) => handle_new(new_m)
    Some((name, _)) => println("unknown command: \{name}")
    None => println("yuegui --help for usage")
  }
}

///|
fn cmd_init(site_name : String) -> Unit {
  let site_dir = site_name
  println("Creating site: \{site_name}")
  let _ = try? @runtime.write_file(
    "\{site_dir}/yuegui.toml",
    toml_config(site_name),
  )
  let _ = try? @runtime.write_file(
    "\{site_dir}/content/index.md",
    index_markdown(site_name),
  )
  let _ = try? @runtime.write_file(
    "\{site_dir}/theme/layouts/default.html",
    default_layout(),
  )
  let _ = try? @runtime.write_file(
    "\{site_dir}/theme/assets/style.css",
    default_stylesheet(),
  )
  println("")
  println("Done! Run:")
  println("  cd \{site_dir}")
  println("  yuegui dev")
  println("  yuegui build")
  println("  yuegui check")
}

///|
fn handle_new(matches : @argparse.Matches) -> Unit {
  match matches.subcommand {
    Some(("page", m)) => {
      let slug = m.values.get_or_default("slug", ["page"])[0]
      println("yuegui new page \{slug}")
    }
    Some(("post", m)) => {
      let slug = m.values.get_or_default("slug", ["post"])[0]
      println("yuegui new post \{slug}")
    }
    Some((name, _)) => println("unknown: yuegui new \{name}")
    None => println("yuegui new --help for usage")
  }
}
