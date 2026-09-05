use super::normalize::normalize_path;

pub fn join(from_uri: &str, to_path: &str) -> Option<String> {
    use super::parse::{build, parse};
    let parts = parse(from_uri)?;
    let joined = join_path(parts.path, to_path);
    Some(build(parts.protocol, &joined, None))
}

fn join_path(from: &str, to: &str) -> String {
    let mut combined = String::with_capacity(from.len() + 1 + to.len());
    combined.push_str(from);
    combined.push('/');
    combined.push_str(to);
    normalize_path(&combined)
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/uri/join_test.rs"
    ));
}
