#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum MoveDirection {
    Previous,
    Next,
}

impl MoveDirection {
    pub fn parse(value: &str) -> Option<Self> {
        match value {
            "prev" | "previous" | "left" => Some(Self::Previous),
            "next" | "right" => Some(Self::Next),
            _ => None,
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum FocusTarget {
    Previous,
    Next,
    Index(usize),
}

impl FocusTarget {
    pub fn parse(value: &str) -> Option<Self> {
        match value {
            "prev" | "previous" => Some(Self::Previous),
            "next" => Some(Self::Next),
            _ => value.parse::<usize>().ok().map(Self::Index),
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum SwapOutcome {
    Changed(String),
    AlreadyFirst,
    AlreadyLast,
    CurrentMissing,
}
