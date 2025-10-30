pub mod oxi;
pub mod types;
pub mod util;

use crate::types::dto::FunResult;
use crate::types::dto::LineMatch;
use crate::types::dto::MoveParams;
use crate::types::dto::ReadAllFilesSucceedResult;
use crate::types::dto::ReaddirSucceedResult;
use crate::types::dto::ReplaceAllMatchesInBufferParams;
use crate::types::dto::ReplaceAllMatchesInBufferResult;
use crate::types::dto::ReplaceCurrentMatchInBufferParams;
use crate::types::dto::ReplaceCurrentMatchInBufferResult;
use crate::types::dto::SearchInBufferParams;
use crate::types::dto::ShowReplacePreviewInBufferParams;
use crate::types::dto::ShowReplacePreviewInBufferResult;
use nvim_oxi::Dictionary;
use nvim_oxi::Function;
use nvim_oxi::Object;

#[nvim_oxi::plugin]
fn nvim_tools() -> Dictionary {
    Dictionary::from_iter([
        (
            "collect_files",
            Object::from(Function::<
                (String, bool),
                Result<ReadAllFilesSucceedResult, String>,
            >::from_fn(oxi::fs::collect_files)),
        ),
        ////
        (
            "search_in_buffer",
            Object::from(
                Function::<SearchInBufferParams, FunResult<Vec<LineMatch>>>::from_fn(
                    oxi::search::search_in_buffer,
                ),
            ),
        ),
        (
            "show_replace_preview_in_buffer",
            Object::from(Function::<
                ShowReplacePreviewInBufferParams,
                FunResult<ShowReplacePreviewInBufferResult>,
            >::from_fn(
                oxi::search::show_replace_preview_in_buffer
            )),
        ),
        ////
        (
            "replace_file",
            Object::from(Function::from_fn(oxi::replace::replace_file)),
        ),
        (
            "replace_file_by_matches",
            Object::from(Function::from_fn(oxi::replace::replace_file_by_matches)),
        ),
        (
            "replace_file_by_matches_advance",
            Object::from(Function::from_fn(
                oxi::replace::replace_file_by_matches_advance,
            )),
        ),
        (
            "replace_file_preview",
            Object::from(Function::from_fn(oxi::replace::replace_file_preview)),
        ),
        (
            "replace_file_preview_advance",
            Object::from(Function::from_fn(
                oxi::replace::replace_file_preview_advance,
            )),
        ),
        (
            "replace_file_preview_by_matches_advance",
            Object::from(Function::from_fn(
                oxi::replace::replace_file_preview_by_matches_advance,
            )),
        ),
        (
            "replace_text_preview",
            Object::from(Function::from_fn(oxi::replace::replace_text_preview)),
        ),
        (
            "replace_text_preview_advance",
            Object::from(Function::from_fn(
                oxi::replace::replace_text_preview_advance,
            )),
        ),
        (
            "replace_text_preview_by_matches",
            Object::from(Function::from_fn(
                oxi::replace::replace_text_preview_by_matches,
            )),
        ),
        (
            "replace_text_preview_by_matches_advance",
            Object::from(Function::from_fn(
                oxi::replace::replace_text_preview_by_matches_advance,
            )),
        ),
        ////
        (
            "replace_current_match_in_buffer",
            Object::from(Function::<
                ReplaceCurrentMatchInBufferParams,
                FunResult<ReplaceCurrentMatchInBufferResult>,
            >::from_fn(
                oxi::replace::replace_current_match_in_buffer
            )),
        ),
        (
            "replace_all_matches_in_buffer",
            Object::from(Function::<
                ReplaceAllMatchesInBufferParams,
                FunResult<ReplaceAllMatchesInBufferResult>,
            >::from_fn(
                oxi::replace::replace_all_matches_in_buffer
            )),
        ),
        ////
        (
            "get_filesize",
            Object::from(Function::<String, Result<String, String>>::from_fn(
                oxi::fs::get_filesize,
            )),
        ),
        (
            "readdir",
            Object::from(
                Function::<String, Result<ReaddirSucceedResult, String>>::from_fn(oxi::fs::readdir),
            ),
        ),
        (
            "move",
            Object::from(Function::<MoveParams, Result<bool, String>>::from_fn(
                oxi::fs::r#move,
            )),
        ),
    ])
}
