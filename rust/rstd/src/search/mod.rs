mod search_in_files;
mod search_in_lines;
mod search_in_lines_literal;
mod search_in_lines_regex;
mod search_in_text;

pub use crate::types::{
    ISearchBlockMatch, ISearchFileMatch, ISearchInFilesFailedResult, ISearchInFilesOptions,
    ISearchInFilesSucceedResult, ISearchInLinesLineMatch, ISearchInLinesLiteralLineMatch,
    ISearchInLinesLiteralMatchPoint, ISearchInLinesLiteralOptions, ISearchInLinesMatchPoint,
    ISearchInLinesOptions, ISearchInLinesRegexLineMatch, ISearchInLinesRegexMatchPoint,
    ISearchInLinesRegexOptions, ISearchInTextOptions, ISearchMatchPoint,
};
pub use search_in_files::*;
pub use search_in_lines::*;
pub use search_in_lines_literal::*;
pub use search_in_lines_regex::*;
pub use search_in_text::*;
