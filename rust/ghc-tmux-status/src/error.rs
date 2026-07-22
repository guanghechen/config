use std::fmt::{Display, Formatter};

pub type AppResult<T> = Result<T, AppError>;

#[derive(Debug)]
pub enum AppError {
    Usage(String),
    TmuxCommand {
        command: String,
        stderr: String,
    },
    TmuxParse(String),
    Render(String),
    CommandTimeout {
        command: String,
        timeout_ms: u128,
    },
    CommandOutputTooLarge {
        command: String,
        stream: &'static str,
        limit_bytes: usize,
    },
    Io(std::io::Error),
}

impl Display for AppError {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Usage(message) => write!(formatter, "{message}"),
            Self::TmuxCommand { command, stderr } => {
                write!(formatter, "tmux command failed: {command}: {stderr}")
            }
            Self::TmuxParse(message) => write!(formatter, "tmux parse failed: {message}"),
            Self::Render(message) => write!(formatter, "render failed: {message}"),
            Self::CommandTimeout {
                command,
                timeout_ms,
            } => write!(
                formatter,
                "command timed out after {timeout_ms}ms: {command}"
            ),
            Self::CommandOutputTooLarge {
                command,
                stream,
                limit_bytes,
            } => write!(
                formatter,
                "command {stream} exceeded {limit_bytes} bytes: {command}"
            ),
            Self::Io(error) => write!(formatter, "io failed: {error}"),
        }
    }
}

impl std::error::Error for AppError {}

impl From<std::io::Error> for AppError {
    fn from(error: std::io::Error) -> Self {
        Self::Io(error)
    }
}
