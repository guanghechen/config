//! Git domain and cancellable queries, with Lua bindings isolated in `lua`.

mod blame;
pub mod encoding;
mod ignore;
mod job;
mod lua;
mod model;
mod parse;
mod process;
pub mod staging;
mod status;
pub mod word_diff;

pub use blame::{
    BlameCommit, BlameJob, BlameLine, BlameOptions, BlameSnapshot, BlameSource, start_blame,
};
pub use ignore::{IgnoreCache, IgnoreJob, IgnoreReport, IgnoreWarning};
pub use job::{Outcome, StatusJob, start_status};
pub(crate) use lua::module;
pub use model::{CODES, Entry, Info, Numstat, Numstats, Snapshot, Stage, code_bit};
pub use status::{Options, collect};

#[cfg(test)]
mod test_support;
