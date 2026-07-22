mod app;
mod cache;
mod cli;
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
mod process;
mod runtime;
mod scheduler;
mod session;
mod status_length;
mod status_widget;
mod tmux;
mod util;
mod widget;

use std::process::ExitCode;
use std::time::Duration;

use crate::app::StatusApp;
use crate::cli::CliCommand;
use crate::error::AppResult;
use crate::layout::LayoutEngine;
use crate::process::ProcessWatchdog;

const PROCESS_DEADLINE: Duration = Duration::from_secs(30);

fn main() -> ExitCode {
    let _watchdog = ProcessWatchdog::start(PROCESS_DEADLINE);
    if let Err(error) = run() {
        eprintln!("ghc-tmux-status: {error}");
        return ExitCode::FAILURE;
    }
    ExitCode::SUCCESS
}

fn run() -> AppResult<()> {
    let command = cli::parse(std::env::args().skip(1).collect())?;
    let app = StatusApp::live();
    match command {
        CliCommand::Apply(event) => app.apply(event),
        CliCommand::SchedulerTick => app.scheduler_tick(),
        CliCommand::DumpState => app.dump_state(),
        CliCommand::RenderStatus02 => app.render_status02_stdout(),
        CliCommand::FocusSession(target) => app.focus_session(target),
        CliCommand::SwapSession(direction) => app.swap_session(direction),
        CliCommand::Layout {
            mode,
            status,
            width,
            session_count,
            rows,
        } => run_layout(&mode, &status, width, session_count, rows),
        CliCommand::Help => {
            print_help();
            Ok(())
        }
    }
}

fn run_layout(
    mode: &str,
    status: &str,
    width: usize,
    session_count: usize,
    rows: crate::model::RowsOverride,
) -> AppResult<()> {
    match LayoutEngine::resolve(mode, status, width, session_count, rows) {
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
  ghc-tmux-status scheduler-tick
  ghc-tmux-status render status02
  ghc-tmux-status session focus <prev|next|index>
  ghc-tmux-status session swap <prev|next>
  ghc-tmux-status layout <mode> <status> <width> <session-count> [rows: auto|1|2]
  ghc-tmux-status dump-state"
    );
}
