mod app;
mod cache;
mod commit;
mod component;
mod composer;
mod error;
mod layout;
mod metric;
mod model;
mod platform;
mod runtime;
mod session_group;
mod status_component;
mod tmux;
mod width;

use crate::app::StatusApp;
use crate::error::{AppError, AppResult};
use crate::layout::LayoutEngine;
use crate::model::{RenderEvent, RenderEventKind};

fn main() {
    if let Err(error) = run() {
        eprintln!("ghc-tmux-status: {error}");
        std::process::exit(1);
    }
}

fn run() -> AppResult<()> {
    let mut args = std::env::args().skip(1);
    let Some(command) = args.next() else {
        print_help();
        return Ok(());
    };

    let app = StatusApp::live();
    match command.as_str() {
        "apply" => {
            let event = match args.next() {
                Some(value) => RenderEvent {
                    kind: RenderEventKind::parse(&value)
                        .ok_or_else(|| AppError::Usage(format!("unknown render event: {value}")))?,
                },
                None => RenderEvent::manual_apply(),
            };
            app.apply(event)
        }
        "dump-state" => app.dump_state(),
        "render" => match args.next().as_deref() {
            Some("status02") => app.render_status02_stdout(),
            _ => Err(AppError::Usage("expected: render status02".to_string())),
        },
        "layout" => run_layout(args.collect()),
        "help" | "--help" | "-h" => {
            print_help();
            Ok(())
        }
        _ => Err(AppError::Usage(format!("unknown command: {command}"))),
    }
}

fn run_layout(args: Vec<String>) -> AppResult<()> {
    if args.len() != 4 {
        return Err(AppError::Usage(
            "expected: layout <mode> <status> <width> <session-count>".to_string(),
        ));
    }

    let width = args[2]
        .parse::<usize>()
        .map_err(|_| AppError::Usage(format!("invalid width: {}", args[2])))?;
    let session_count = args[3]
        .parse::<usize>()
        .map_err(|_| AppError::Usage(format!("invalid session-count: {}", args[3])))?;

    match LayoutEngine::resolve(&args[0], &args[1], width, session_count) {
        Some(plan) => {
            println!(
                "mode={} position={} kind={} rows={} status={}",
                plan.mode.as_str(),
                plan.position.as_str(),
                plan.kind.as_str(),
                plan.rows,
                plan.target_status
            );
            Ok(())
        }
        None => {
            println!("noop");
            Ok(())
        }
    }
}

fn print_help() {
    println!(
        "ghc-tmux-status\n\nUSAGE:\n  ghc-tmux-status apply\n  ghc-tmux-status render status02\n  ghc-tmux-status layout <mode> <status> <width> <session-count>\n  ghc-tmux-status dump-state"
    );
}
