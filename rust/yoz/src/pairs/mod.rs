//! Pair tokens of a buffer for rainbow highlighting, matchparen and balance-aware typing.
//!
//! Tokenizing and pairing reproduce blink.pairs v0.5.0 (MIT License, Copyright (c) 2025 Liam Dyer) without its
//! nightly SIMD tokenizer; a [`document::Document`] follows line edits and retokenizes later lines while the state
//! entering them changes.

mod document;
mod language;
mod lua;
mod matching;
mod scan;

pub(crate) use lua::module;

#[cfg(test)]
mod perf_tests;
#[cfg(test)]
mod tests;
