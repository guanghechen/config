use super::SEP;
use super::get_cwd;
use super::resolve::resolve_borrowed;

pub fn relative(from: &str, to: &str, keep_tailing_slash: bool) -> String {
    let cwd_guard = get_cwd();
    let cwd: &str = &cwd_guard;
    let abs_from = resolve_borrowed(cwd, from);
    let abs_to = resolve_borrowed(cwd, to);
    let should_append_slash = keep_tailing_slash
        && to.len() > 1
        && to.ends_with(['/', '\\'])
        && abs_to != "/"
        && abs_to.contains('/');

    let mut from_components = abs_from.split_terminator('/');
    let mut to_components = abs_to.split_terminator('/');
    if from_components.next() != to_components.next() {
        return with_tailing_slash(abs_to.into_owned(), should_append_slash);
    }

    loop {
        let from_component = from_components.next();
        let to_component = to_components.next();
        if from_component == to_component {
            if from_component.is_none() {
                return if should_append_slash {
                    "./".to_string()
                } else {
                    ".".to_string()
                };
            }
            continue;
        }

        let parent_count = usize::from(from_component.is_some()) + from_components.count();
        return build_relative(
            parent_count,
            to_component.into_iter().chain(to_components),
            should_append_slash,
            abs_to.len(),
        );
    }
}

fn build_relative<'a>(
    parent_count: usize,
    to_components: impl Iterator<Item = &'a str>,
    should_append_slash: bool,
    to_len: usize,
) -> String {
    let mut result = String::with_capacity(parent_count * 3 + to_len);
    for _ in 0..parent_count {
        if !result.is_empty() {
            result.push(SEP);
        }
        result.push_str("..");
    }

    for component in to_components {
        if !result.is_empty() {
            result.push(SEP);
        }
        result.push_str(component);
    }

    if should_append_slash {
        result.push(SEP);
    }
    result
}

fn with_tailing_slash(mut filepath: String, should_append_slash: bool) -> String {
    if should_append_slash {
        filepath.push(SEP);
    }
    filepath
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/canonical_path/relative_test.rs"
    ));
}
