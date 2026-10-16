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

use std::io::Write;
use std::process::ExitCode;
use std::time::Duration;

use crate::cli::CliCommand;
use crate::error::{AppError, AppResult};
use crate::layout::LayoutEngine;
use crate::process::ProcessWatchdog;
use crate::runtime::StatusRuntime;
use crate::scheduler::{
    SCHEDULER_SNAPSHOT_ENV, SESSION_STATE_TTL_ENV, SESSION_STATES_ACK, SESSION_STATES_PREFIX_ENV,
    SchedulerSnapshot, SessionStatesPublish,
};

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
    let runtime = StatusRuntime::live();
    match command {
        CliCommand::Apply(event) => runtime.apply(event),
        CliCommand::BootstrapTheme(expected_generation) => {
            runtime.bootstrap_theme(expected_generation)
        }
        CliCommand::SchedulerTick => {
            let snapshot = std::env::var(SCHEDULER_SNAPSHOT_ENV)
                .ok()
                .and_then(|value| SchedulerSnapshot::from_transport(&value));
            /*
             * Only the driver's lock owner passes a publication; direct invocations
             * and malformed transport run the tasks without publishing.
             */
            let publish = std::env::var(SESSION_STATES_PREFIX_ENV)
                .ok()
                .zip(std::env::var(SESSION_STATE_TTL_ENV).ok())
                .and_then(|(prefix, ttl)| SessionStatesPublish::from_transport(&prefix, &ttl));
            if publish.is_some() {
                acknowledge_session_states_publish().map_err(AppError::Io)?;
            }
            runtime.scheduler_tick(snapshot, publish)
        }
        CliCommand::DumpState => runtime.dump_state(),
        CliCommand::RenderStatus02 => runtime.render_status02_stdout(),
        CliCommand::FocusSession(target) => runtime.focus_session(target),
        CliCommand::SwapSession(direction) => runtime.swap_session(direction),
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

/**
 * Taking over must be visible to the driver before any publication path can run,
 * so a failed acknowledgement forfeits the whole tick.
 */
fn acknowledge_session_states_publish() -> std::io::Result<()> {
    let mut stdout = std::io::stdout().lock();
    writeln!(stdout, "{SESSION_STATES_ACK}")?;
    stdout.flush()
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
  ghc-tmux-status apply theme-loaded <generation>
  ghc-tmux-status scheduler-tick
  ghc-tmux-status render status02
  ghc-tmux-status session focus <prev|next|index>
  ghc-tmux-status session swap <prev|next>
  ghc-tmux-status layout <mode> <status> <width> <session-count> [rows: auto|1|2]
  ghc-tmux-status dump-state"
    );
}
