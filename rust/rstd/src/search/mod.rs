mod search_in_files;
mod search_in_lines_literal;
mod search_in_lines_regex;

pub use crate::types::{
    ISearchBlockMatch,
    ISearchFileMatch,
    ISearchInFilesFailedResult,
    ISearchInFilesOptions,
    ISearchInFilesSucceedResult,
    ISearchInLinesLiteralLineMatch,
    ISearchInLinesLiteralMatchPoint,
    ISearchInLinesLiteralOptions,
    ISearchInLinesRegexLineMatch,
    ISearchInLinesRegexMatchPoint,
    ISearchInLinesRegexOptions,
    ISearchMatchPoint,
};
pub use search_in_files::*;
pub use search_in_lines_literal::*;
pub use search_in_lines_regex::*;
