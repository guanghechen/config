mod search_in_files;
mod search_in_lines;
mod search_in_lines_literal;
mod search_in_lines_regex;
mod search_in_text;
mod text_utils;

pub use crate::types::{
    IFileMatch, ISearchFailedResult, ISearchFileResult, ISearchInFilesOptions, ISearchInLinesLineMatch,
    ISearchInLinesLiteralLineMatch, ISearchInLinesLiteralMatchPoint, ISearchInLinesLiteralOptions,
    ISearchInLinesMatchPoint, ISearchInLinesOptions, ISearchInLinesRegexLineMatch,
    ISearchInLinesRegexMatchPoint, ISearchInLinesRegexOptions, ISearchInTextOptions, ISearchTextResult,
    ITextMatch,
};
pub use search_in_files::*;
pub use search_in_lines::*;
pub use search_in_lines_literal::*;
pub use search_in_lines_regex::*;
pub use search_in_text::*;
