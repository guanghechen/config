//! Cross-platform input-method access.

#[cfg(target_os = "macos")]
mod osx;
#[cfg(any(target_os = "linux", target_os = "windows", test))]
mod win;
#[cfg(any(target_os = "linux", test))]
mod wsl;

#[cfg(target_os = "macos")]
use osx as platform;
#[cfg(target_os = "windows")]
use win as platform;
#[cfg(target_os = "linux")]
use wsl as platform;

#[cfg(target_os = "macos")]
pub(crate) use osx::Backend;
#[cfg(target_os = "windows")]
pub(crate) use win::Backend;
#[cfg(target_os = "linux")]
pub(crate) use wsl::{Backend, is_available};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(crate) enum InputMethod {
    English,
    Chinese,
}

impl InputMethod {
    pub(crate) fn parse(input_method: &str) -> Result<Self, String> {
        match input_method {
            "English" => Ok(Self::English),
            "Chinese" => Ok(Self::Chinese),
            _ => Err(format!(
                "[im.set_input_method] Unknown input method: {input_method:?}"
            )),
        }
    }

    pub(crate) fn as_str(self) -> &'static str {
        match self {
            Self::English => "English",
            Self::Chinese => "Chinese",
        }
    }
}

impl Backend {
    pub(crate) fn get_input_method(&mut self) -> Result<InputMethod, String> {
        let source_id = self.current()?;
        platform::input_method(&source_id)
            .ok_or_else(|| format!("[im.get_input_method] Unknown input source: {source_id:?}"))
    }

    pub(crate) fn set_input_method(&mut self, input_method: InputMethod) -> Result<(), String> {
        self.select(platform::source_id_for(input_method))
    }
}

pub(crate) fn is_input_method(source_id: &str, input_method: InputMethod) -> bool {
    platform::input_method(source_id) == Some(input_method)
}

#[cfg(test)]
mod tests {
    use super::InputMethod;

    #[test]
    fn t_parses_input_methods() {
        assert_eq!(InputMethod::parse("English"), Ok(InputMethod::English));
        assert_eq!(InputMethod::parse("Chinese"), Ok(InputMethod::Chinese));
        assert!(InputMethod::parse("Japanese").is_err());
    }
}
