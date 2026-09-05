pub struct UriParts<'a> {
    pub protocol: &'a str,
    pub path: &'a str,
    pub hash: Option<&'a str>,
}

pub fn parse(uri: &str) -> Option<UriParts<'_>> {
    let protocol_end = uri.find("://")?;
    let protocol = &uri[..protocol_end];
    if protocol.is_empty() {
        return None;
    }

    let rest = &uri[protocol_end + 3..];
    let (path, hash) = match rest.find('#') {
        Some(hash_pos) => (&rest[..hash_pos], Some(&rest[hash_pos + 1..])),
        None => (rest, None),
    };

    Some(UriParts {
        protocol,
        path,
        hash,
    })
}

pub fn build(protocol: &str, path: &str, hash: Option<&str>) -> String {
    let mut result = String::with_capacity(protocol.len() + 3 + path.len() + hash.map_or(0, |h| h.len() + 1));
    result.push_str(protocol);
    result.push_str("://");
    result.push_str(path);
    if let Some(h) = hash {
        result.push('#');
        result.push_str(h);
    }
    result
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/uri/parse_test.rs"
    ));
}
