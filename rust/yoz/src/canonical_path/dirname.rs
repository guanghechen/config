use super::SEP;
use super::normalize;

pub fn dirname(filepath: &str, keep_tailing_slash: bool) -> String {
    if filepath.is_empty() {
        if keep_tailing_slash {
            return format!("..{}", SEP);
        }
        return "..".to_string();
    }

    let mut result = normalize(filepath, false);
    let bytes = result.as_bytes();
    if bytes.len() == 2 && bytes[0].is_ascii_alphabetic() && bytes[1] == b':' {
        if keep_tailing_slash {
            result.push(SEP);
        }
        return result;
    }

    let Some(index) = result.rfind(SEP) else {
        return parent(keep_tailing_slash);
    };
    if index == 0 {
        result.truncate(1);
        return result;
    }

    result.truncate(index);
    if keep_tailing_slash {
        result.push(SEP);
    }
    result
}

fn parent(keep_tailing_slash: bool) -> String {
    if keep_tailing_slash {
        "../".to_string()
    } else {
        "..".to_string()
    }
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/canonical_path/dirname_test.rs"
    ));
}
