//! fzf-style fuzzy matching for pickers and Explorer filters.
//!
//! The algorithms port fzf v0.74.5 (`src/algo/algo.go`, `src/pattern.go`; MIT License, Copyright (c)
//! 2013-2024 Junegunn Choi). Matching runs over a [`Corpus`] that keeps candidates on the native side.

mod algo;
mod class;
mod corpus;
mod lua;
mod matcher;
mod pattern;
mod text;

pub use class::Scheme;
pub use corpus::{Corpus, Query, Ranked};
pub use pattern::CaseMode;

pub(crate) use lua::module;
pub(crate) use text::TextMatcher;

#[cfg(test)]
mod perf_tests;
#[cfg(test)]
mod tests;
