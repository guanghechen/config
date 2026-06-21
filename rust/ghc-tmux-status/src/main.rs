mod app;
mod cache;
mod commit;
mod composer;
mod config;
mod error;
mod introspect;
mod layout;
mod metric;
mod model;
mod observability;
mod platform;
mod runtime;
mod session;
mod status_length;
mod status_widget;
mod tmux;
mod util;
mod widget;

use crate::app::StatusApp;
use crate::error::{AppError, AppResult};
use crate::layout::LayoutEngine;
use crate::model::{RenderEvent, RenderEventKind};
use crate::session::{FocusTarget, MoveDirection};

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
        "heartbeat" => {
            let generation = args
                .next()
                .ok_or_else(|| AppError::Usage("expected: heartbeat <generation>".to_string()))?;
            app.heartbeat(&generation)
        }
        "metrics-sample" => {
            let generation = args.next().ok_or_else(|| {
                AppError::Usage("expected: metrics-sample <generation>".to_string())
            })?;
            app.metrics_sample(&generation)
        }
        "cpu-sample" => {
            let generation = args
                .next()
                .ok_or_else(|| AppError::Usage("expected: cpu-sample <generation>".to_string()))?;
            app.cpu_sample(&generation)
        }
        "dump-state" => app.dump_state(),
        "render" => match args.next().as_deref() {
            Some("status02") => app.render_status02_stdout(),
            _ => Err(AppError::Usage("expected: render status02".to_string())),
        },
        "session" => run_session(&app, args.collect()),
        "layout" => run_layout(args.collect()),
        "help" | "--help" | "-h" => {
            print_help();
            Ok(())
        }
        _ => Err(AppError::Usage(format!("unknown command: {command}"))),
    }
}

fn run_session(app: &StatusApp, args: Vec<String>) -> AppResult<()> {
    if args.len() != 2 {
        return Err(AppError::Usage(
            "expected: session <focus|swap> <prev|next|index>".to_string(),
        ));
    }

    match args[0].as_str() {
        "focus" => {
            let target = FocusTarget::parse(&args[1]).ok_or_else(|| {
                AppError::Usage(format!("invalid session focus target: {}", args[1]))
            })?;
            app.focus_session(target)
        }
        "swap" => {
            let direction = MoveDirection::parse(&args[1]).ok_or_else(|| {
                AppError::Usage(format!("invalid session swap direction: {}", args[1]))
            })?;
            app.swap_session(direction)
        }
        _ => Err(AppError::Usage(
            "expected: session <focus|swap> <prev|next|index>".to_string(),
        )),
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
        "ghc-tmux-status

USAGE:
  ghc-tmux-status apply
  ghc-tmux-status heartbeat <generation>
  ghc-tmux-status metrics-sample <generation>
  ghc-tmux-status render status02
  ghc-tmux-status session focus <prev|next|index>
  ghc-tmux-status session swap <prev|next>
  ghc-tmux-status layout <mode> <status> <width> <session-count>
  ghc-tmux-status dump-state"
    );
}
