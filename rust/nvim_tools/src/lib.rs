pub mod oxi;
pub mod types;
pub mod util;

use crate::types::dto::FunResult;
use crate::types::dto::ReplaceAllMatchesInBufferParams;
use crate::types::dto::ReplaceAllMatchesInBufferResult;
use crate::types::dto::ReplaceCurrentMatchInBufferParams;
use crate::types::dto::ReplaceCurrentMatchInBufferResult;
use crate::types::dto::ShowReplacePreviewInBufferParams;
use crate::types::dto::ShowReplacePreviewInBufferResult;
use nvim_oxi::Dictionary;
use nvim_oxi::Function;
use nvim_oxi::Object;

#[nvim_oxi::plugin]
fn nvim_tools() -> Dictionary {
    Dictionary::from_iter([
        (
            "show_replace_preview_in_buffer",
            Object::from(Function::<
                ShowReplacePreviewInBufferParams,
                FunResult<ShowReplacePreviewInBufferResult>,
            >::from_fn(
                oxi::replace::show_replace_preview_in_buffer
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
    ])
}
