use super::get_cwd;
use super::is_absolute;
use super::split;
use std::borrow::Cow;

pub fn is_descendant(from: &str, to: &str) -> bool {
    let cwd_guard = get_cwd();
    let cwd: &str = &cwd_guard;

    let abs_from = if is_absolute(from) {
        Cow::Borrowed(from)
    } else {
        Cow::Owned(format!("{}/{}", cwd, from))
    };

    let abs_to = if is_absolute(to) {
        Cow::Borrowed(to)
    } else {
        Cow::Owned(format!("{}/{}", cwd, to))
    };

    let from_pieces = split(abs_from.as_ref(), false);
    let to_pieces = split(abs_to.as_ref(), false);

    let n1 = from_pieces.len();
    let n2 = to_pieces.len();

    if n1 > n2 {
        return false;
    }

    for i in 0..n1 {
        if from_pieces[i] != to_pieces[i] {
            return false;
        }
    }
    true
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/path/is_descendant_test.rs"
    ));
}
