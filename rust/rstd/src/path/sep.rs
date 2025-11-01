#[cfg(windows)]
pub const SEP: char = '\\';

#[cfg(not(windows))]
pub const SEP: char = '/';
