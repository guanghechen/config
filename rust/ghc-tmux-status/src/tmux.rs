use std::collections::BTreeMap;
use std::process::Command;

use crate::error::{AppError, AppResult};
use crate::model::{RenderContext, RenderedStatus, SessionInfo, TmuxSnapshot};

pub struct TmuxAdapter;

impl TmuxAdapter {
    pub fn new() -> Self {
        Self
    }

    pub fn read_snapshot(&self) -> AppResult<TmuxSnapshot> {
        let output = self.tmux_output(snapshot_command_args())?;
        parse_snapshot_output(&output)
    }

    pub fn commit_status02(
        &self,
        status: &RenderedStatus,
        context: &RenderContext,
        component_cache_options: Vec<(String, String)>,
    ) -> AppResult<()> {
        let mut args = vec![
            "set".to_string(),
            "-g".to_string(),
            "@GHC_SL_STATUS02_SESSION_FORMAT".to_string(),
            status.session_format.rich_text.clone(),
            ";".to_string(),
            "set".to_string(),
            "-g".to_string(),
            "@GHC_SL_STATUS02_CURRENT_FORMAT".to_string(),
            status.current_format.rich_text.clone(),
            ";".to_string(),
            "set".to_string(),
            "-g".to_string(),
            "status-left".to_string(),
            status.status_left.rich_text.clone(),
            ";".to_string(),
            "set".to_string(),
            "-g".to_string(),
            "status-right".to_string(),
            status.status_right.rich_text.clone(),
        ];

        for (name, value) in component_cache_options {
            args.extend([
                ";".to_string(),
                "set".to_string(),
                "-g".to_string(),
                name,
                value,
            ]);
        }

        let plan = &context.layout;

        args.extend([
            ";".to_string(),
            "set".to_string(),
            "-g".to_string(),
            "@GHC_SL_LAYOUT".to_string(),
            plan.key.clone(),
            ";".to_string(),
            "set".to_string(),
            "-g".to_string(),
            "status-position".to_string(),
            plan.position.as_str().to_string(),
            ";".to_string(),
            "set".to_string(),
            "-g".to_string(),
            "status-justify".to_string(),
            "centre".to_string(),
            ";".to_string(),
            "set".to_string(),
            "-g".to_string(),
            "status".to_string(),
            plan.target_status.clone(),
            ";".to_string(),
            "set".to_string(),
            "status".to_string(),
            plan.target_status.clone(),
        ]);

        if plan.rows == 1 {
            args.extend([
                ";".to_string(),
                "set".to_string(),
                "-gu".to_string(),
                "status-format".to_string(),
            ]);
        } else {
            args.extend([
                ";".to_string(),
                "set".to_string(),
                "-g".to_string(),
                "status-format[0]".to_string(),
                "#{E:@GHC_SL_STATUS02_SESSION_FORMAT}".to_string(),
                ";".to_string(),
                "set".to_string(),
                "-g".to_string(),
                "status-format[1]".to_string(),
                "#{E:@GHC_SL_STATUS02_CURRENT_FORMAT}".to_string(),
            ]);
        }

        self.tmux_status(args)?;
        let _ = self.tmux_status(["refresh-client".to_string(), "-S".to_string()]);
        Ok(())
    }

    fn tmux_output<I, S>(&self, args: I) -> AppResult<String>
    where
        I: IntoIterator<Item = S>,
        S: AsRef<str>,
    {
        let args = args
            .into_iter()
            .map(|arg| arg.as_ref().to_string())
            .collect::<Vec<_>>();
        let output = Command::new("tmux").args(&args).output()?;
        if !output.status.success() {
            return Err(AppError::TmuxCommand {
                command: format!("tmux {}", args.join(" ")),
                stderr: String::from_utf8_lossy(&output.stderr).trim().to_string(),
            });
        }
        Ok(String::from_utf8_lossy(&output.stdout)
            .trim_end()
            .to_string())
    }

    fn tmux_status<I, S>(&self, args: I) -> AppResult<()>
    where
        I: IntoIterator<Item = S>,
        S: AsRef<str>,
    {
        let args = args
            .into_iter()
            .map(|arg| arg.as_ref().to_string())
            .collect::<Vec<_>>();
        let output = Command::new("tmux").args(&args).output()?;
        if !output.status.success() {
            return Err(AppError::TmuxCommand {
                command: format!("tmux {}", args.join(" ")),
                stderr: String::from_utf8_lossy(&output.stderr).trim().to_string(),
            });
        }
        Ok(())
    }
}

fn snapshot_command_args() -> Vec<String> {
    vec![
        "display-message".to_string(),
        "-p".to_string(),
        format!(
            "{CONTEXT_MARK}{FIELD_SEP}#{{client_width}}{FIELD_SEP}#{{session_name}}{FIELD_SEP}#{{host}}{FIELD_SEP}#{{session_created}}"
        ),
        ";".to_string(),
        "display-message".to_string(),
        "-p".to_string(),
        STATUS_MARK.to_string(),
        ";".to_string(),
        "show".to_string(),
        "-qv".to_string(),
        "status".to_string(),
        ";".to_string(),
        "display-message".to_string(),
        "-p".to_string(),
        options_format(),
        ";".to_string(),
        "display-message".to_string(),
        "-p".to_string(),
        SESSIONS_MARK.to_string(),
        ";".to_string(),
        "list-sessions".to_string(),
        "-F".to_string(),
        "#{session_id}\t#{session_name}".to_string(),
    ]
}

fn options_format() -> String {
    let mut format = OPTIONS_MARK.to_string();
    for name in SNAPSHOT_OPTION_NAMES {
        format.push(FIELD_SEP);
        format.push_str("#{");
        format.push_str(name);
        format.push('}');
    }
    format
}

fn parse_snapshot_output(output: &str) -> AppResult<TmuxSnapshot> {
    let mut lines = output.lines();
    let context_line = lines
        .next()
        .ok_or_else(|| AppError::TmuxParse("missing context section".to_string()))?;
    let (width, current_session_name, host, session_created) = parse_context_line(context_line)?;

    expect_marker(lines.next(), STATUS_MARK)?;
    let mut status_lines = Vec::new();
    let options_line = loop {
        let line = lines
            .next()
            .ok_or_else(|| AppError::TmuxParse("missing options section".to_string()))?;
        if line.starts_with(OPTIONS_MARK) {
            break line;
        }
        status_lines.push(line);
    };
    let status = status_lines
        .first()
        .copied()
        .unwrap_or_default()
        .to_string();

    let options = parse_options_line(options_line)?;
    let mode = options.get("@GHC_SL_MODE").cloned().unwrap_or_default();
    let current_layout = options.get("@GHC_SL_LAYOUT").cloned().unwrap_or_default();

    expect_marker(lines.next(), SESSIONS_MARK)?;
    let sessions = lines
        .filter_map(|line| {
            let (id, name) = line.split_once('\t')?;
            Some(SessionInfo {
                id: id.to_string(),
                name: name.to_string(),
            })
        })
        .collect();

    if current_session_name.is_empty() {
        return Err(AppError::TmuxParse(
            "current session name is empty".to_string(),
        ));
    }

    Ok(TmuxSnapshot {
        mode,
        current_layout,
        status,
        width,
        current_session_name,
        host,
        session_created,
        sessions,
        options,
    })
}

fn parse_options_line(options_line: &str) -> AppResult<BTreeMap<String, String>> {
    let mut fields = options_line.split(FIELD_SEP);
    if fields.next() != Some(OPTIONS_MARK) {
        return Err(AppError::TmuxParse(format!(
            "expected options marker, got: {options_line}"
        )));
    }

    let mut options = BTreeMap::new();
    for name in SNAPSHOT_OPTION_NAMES {
        options.insert(
            (*name).to_string(),
            fields.next().unwrap_or_default().to_string(),
        );
    }
    Ok(options)
}

fn parse_context_line(context_line: &str) -> AppResult<(usize, String, String, i64)> {
    let mut fields = context_line.split(FIELD_SEP);
    let marker = fields.next();
    if marker != Some(CONTEXT_MARK) {
        return Err(AppError::TmuxParse(format!(
            "expected context marker, got: {}",
            context_line
        )));
    }

    let width = fields
        .next()
        .and_then(|value| value.parse::<usize>().ok())
        .unwrap_or(200);
    let current_session_name = fields.next().unwrap_or_default().to_string();
    let host = fields.next().unwrap_or_default().to_string();
    let session_created = fields
        .next()
        .and_then(|value| value.parse::<i64>().ok())
        .unwrap_or_default();

    Ok((width, current_session_name, host, session_created))
}

fn expect_marker(line: Option<&str>, marker: &str) -> AppResult<()> {
    if line == Some(marker) {
        return Ok(());
    }

    Err(AppError::TmuxParse(format!(
        "expected marker {marker}, got: {}",
        line.unwrap_or("<missing>")
    )))
}

const FIELD_SEP: char = '\u{1f}';
const CONTEXT_MARK: &str = "__GHC_STATUS_CONTEXT__";
const STATUS_MARK: &str = "__GHC_STATUS_STATUS__";
const OPTIONS_MARK: &str = "__GHC_STATUS_OPTIONS__";
const SESSIONS_MARK: &str = "__GHC_STATUS_SESSIONS__";

const SNAPSHOT_OPTION_NAMES: &[&str] = &[
    "@GHC_SL_MODE",
    "@GHC_SL_LAYOUT",
    "@GHC_SL_STATUS02_SESSION_FORMAT",
    "@GHC_SL_STATUS02_CURRENT_FORMAT",
    "status-left",
    "status-right",
    "@GHC_STATUS_COMPONENT_CACHE_session_list",
    "@GHC_STATUS_COMPONENT_CACHE_duration",
];

#[cfg(test)]
mod tests {
    use super::{
        CONTEXT_MARK, FIELD_SEP, OPTIONS_MARK, SESSIONS_MARK, SNAPSHOT_OPTION_NAMES, STATUS_MARK,
        parse_snapshot_output,
    };

    #[test]
    fn parses_snapshot_output() {
        let options = std::iter::repeat_n("", SNAPSHOT_OPTION_NAMES.len())
            .collect::<Vec<_>>()
            .join(&FIELD_SEP.to_string());
        let output = format!(
            "{CONTEXT_MARK}{FIELD_SEP}120{FIELD_SEP}yui{FIELD_SEP}host{FIELD_SEP}42
{STATUS_MARK}
on
{OPTIONS_MARK}{FIELD_SEP}{options}
{SESSIONS_MARK}
$1	yui
$2	dev"
        );

        let snapshot = parse_snapshot_output(&output).unwrap();
        assert_eq!(snapshot.width, 120);
        assert_eq!(snapshot.status, "on");
        assert_eq!(snapshot.current_session_name, "yui");
        assert_eq!(snapshot.sessions.len(), 2);
    }

    #[test]
    fn parses_empty_status_and_tabbed_cache_options() {
        let mut option_values = vec![""; SNAPSHOT_OPTION_NAMES.len()];
        option_values[0] = "02";
        option_values[6] = "key	literal	rich";
        let options = option_values.join(&FIELD_SEP.to_string());
        let output = format!(
            "{CONTEXT_MARK}{FIELD_SEP}200{FIELD_SEP}yui{FIELD_SEP}host{FIELD_SEP}42
{STATUS_MARK}
{OPTIONS_MARK}{FIELD_SEP}{options}
{SESSIONS_MARK}
$1	yui"
        );

        let snapshot = parse_snapshot_output(&output).unwrap();
        assert_eq!(snapshot.status, "");
        assert_eq!(snapshot.mode, "02");
        assert_eq!(
            snapshot
                .options
                .get("@GHC_STATUS_COMPONENT_CACHE_session_list")
                .unwrap(),
            "key	literal	rich"
        );
    }
}
