use super::get_cwd;
use super::resolve::resolve_borrowed;

pub fn is_descendant(from: &str, to: &str) -> bool {
    let cwd_guard = get_cwd();
    let cwd: &str = &cwd_guard;
    let abs_from = resolve_borrowed(cwd, from);
    let abs_to = resolve_borrowed(cwd, to);
    let mut to_components = abs_to.split_terminator('/');

    abs_from.split_terminator('/').all(|from_component| {
        to_components
            .next()
            .is_some_and(|to_component| from_component == to_component)
    })
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/canonical_path/is_descendant_test.rs"
    ));
}
