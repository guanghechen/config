use super::normalize::normalize;

pub fn join(from: &str, to: &str, keep_tailing_slash: bool, sep: char) -> String {
    let mut combined = String::with_capacity(from.len() + 1 + to.len());
    combined.push_str(from);
    combined.push('/');
    combined.push_str(to);
    normalize(&combined, keep_tailing_slash, sep)
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/path/join_test.rs"
    ));
}
