mod search_in_files;
mod search_in_lines_literal;

pub use crate::types::{
    ISearchBlockMatch,
    ISearchFileMatch,
    ISearchInFilesFailedResult,
    ISearchInFilesOptions,
    ISearchInFilesSucceedResult,
    ISearchInLinesLiteralLineMatch,
    ISearchInLinesLiteralMatchPoint,
    ISearchInLinesLiteralOptions,
    ISearchMatchPoint,
};
pub use search_in_files::*;
pub use search_in_lines_literal::*;
