use super::normalize::normalize_splits;
use super::split::split;

pub fn relative(from_uri: &str, to_uri: &str) -> Option<String> {
    use super::parse::parse;
    let from_parts = parse(from_uri)?;
    let to_parts = parse(to_uri)?;

    if from_parts.protocol != to_parts.protocol {
        return None;
    }

    Some(relative_path(from_parts.path, to_parts.path))
}

fn relative_path(from: &str, to: &str) -> String {
    let from_pieces = split(from);
    let to_pieces = split(to);

    let to_has_trailing_slash = !to_pieces.is_empty() && to_pieces.last().is_some_and(|s| s.is_empty());

    let from_effective: &[String] = if !from_pieces.is_empty() && from_pieces.last().is_some_and(|s| s.is_empty()) {
        &from_pieces[..from_pieces.len() - 1]
    } else {
        &from_pieces
    };
    let to_effective: &[String] = if to_has_trailing_slash {
        &to_pieces[..to_pieces.len() - 1]
    } else {
        &to_pieces
    };

    let from_is_relative = !from.starts_with('/');
    let to_is_relative = !to.starts_with('/');
    let from_is_dot = from_effective.len() == 1 && from_effective[0] == ".";
    let to_is_dot = to_effective.len() == 1 && to_effective[0] == ".";

    if from_is_dot && to_is_dot {
        if to_has_trailing_slash {
            return "./".to_string();
        }
        return ".".to_string();
    }

    if from_is_dot {
        if to_has_trailing_slash {
            let mut result = normalize_splits(to_effective);
            result.push('/');
            return result;
        }
        return normalize_splits(to_effective);
    }

    if to_is_dot {
        let d = from_effective.len();
        let mut result = String::with_capacity(d * 3);
        for _ in 0..d {
            result.push_str("../");
        }
        return result;
    }

    if from_is_relative && to_is_relative {
        let n1 = from_effective.len();
        let n2 = to_effective.len();
        let n = n1.min(n2);

        let mut m = 0;
        for i in 0..n {
            if from_effective[i] != to_effective[i] {
                break;
            }
            m = i + 1;
        }

        if m == n && n1 == n2 {
            if to_has_trailing_slash {
                return "./".to_string();
            }
            return ".".to_string();
        }

        if m == n && n1 < n2 {
            let mut result = normalize_splits(&to_effective[m..]);
            if to_has_trailing_slash {
                result.push('/');
            }
            return result;
        }

        let d = n1 - m;
        let mut result = String::new();
        for _ in 0..d {
            result.push_str("../");
        }

        if m < n2 {
            result.push_str(&normalize_splits(&to_effective[m..]));
            if to_has_trailing_slash {
                result.push('/');
            }
        }

        return result;
    }

    let n1 = from_effective.len();
    let n2 = to_effective.len();
    let n = n1.min(n2);
    if n < 1 || from_effective[0] != to_effective[0] {
        let mut result = normalize_splits(to_effective);
        if to_has_trailing_slash {
            result.push('/');
        }
        return result;
    }

    let mut m = n;
    for i in 1..n {
        if from_effective[i] != to_effective[i] {
            m = i;
            break;
        }
    }

    if m == n {
        if n1 == n2 {
            if to_has_trailing_slash {
                return "./".to_string();
            }
            return ".".to_string();
        }

        if n1 < n2 {
            let mut result = normalize_splits(&to_effective[m..]);
            if to_has_trailing_slash {
                result.push('/');
            }
            return result;
        }
    }

    let d = n1 - m;
    if n2 == m {
        let mut result = String::with_capacity(d * 3);
        for _ in 0..d {
            result.push_str("../");
        }
        return result;
    }

    let mut result = String::with_capacity(d * 3);
    for _ in 0..d {
        result.push_str("../");
    }
    result.push_str(&normalize_splits(&to_effective[m..]));
    if to_has_trailing_slash {
        result.push('/');
    }
    result
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/uri/relative_test.rs"
    ));
}
