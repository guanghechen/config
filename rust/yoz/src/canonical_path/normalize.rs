use super::SEP;
use std::borrow::Cow;

pub fn normalize(filepath: &str, keep_tailing_slash: bool) -> String {
    let resume_from = match canonical_output_len(filepath, keep_tailing_slash) {
        Ok(output_len) => return filepath[..output_len].to_string(),
        Err(resume_from) => resume_from,
    };
    normalize_from(filepath, keep_tailing_slash, resume_from)
}

pub(crate) fn normalize_borrowed(filepath: &str) -> Cow<'_, str> {
    match canonical_output_len(filepath, false) {
        Ok(output_len) => Cow::Borrowed(&filepath[..output_len]),
        Err(resume_from) => Cow::Owned(normalize_from(filepath, false, resume_from)),
    }
}

fn normalize_from(filepath: &str, keep_tailing_slash: bool, resume_from: usize) -> String {
    let has_prefix_sep = filepath.starts_with(['/', '\\']);
    let has_suffix_sep = filepath.ends_with(['/', '\\']);
    let prefix_len = if resume_from > 1 {
        resume_from - 1
    } else {
        resume_from
    };
    let mut normalizer =
        Normalizer::from_prefix(filepath.len(), &filepath[..prefix_len], has_prefix_sep);
    normalizer.push_path(&filepath[resume_from..]);
    normalizer.finish(keep_tailing_slash, has_suffix_sep, filepath.len())
}

pub(crate) fn normalize_joined(from: &str, to: &str, keep_tailing_slash: bool) -> String {
    let logical_len = from.len() + 1 + to.len();
    let has_prefix_sep = from.is_empty() || from.starts_with(['/', '\\']);
    let has_suffix_sep = to.is_empty() || to.ends_with(['/', '\\']);
    let mut normalizer = Normalizer::new(logical_len, has_prefix_sep);
    normalizer.push_path(from);
    normalizer.push_path(to);
    normalizer.finish(keep_tailing_slash, has_suffix_sep, logical_len)
}

struct Normalizer {
    output: String,
}

impl Normalizer {
    #[inline]
    fn new(capacity: usize, has_prefix_sep: bool) -> Self {
        let mut output = String::with_capacity(capacity.max(1));
        if has_prefix_sep {
            output.push(SEP);
        }
        Self { output }
    }

    #[inline]
    fn from_prefix(capacity: usize, prefix: &str, has_prefix_sep: bool) -> Self {
        let mut output = String::with_capacity(capacity.max(1));
        output.push_str(prefix);
        if output.is_empty() && has_prefix_sep {
            output.push(SEP);
        }
        Self { output }
    }

    #[inline]
    fn push_path(&mut self, filepath: &str) {
        let bytes = filepath.as_bytes();
        let mut start = 0;

        for (index, &byte) in bytes.iter().enumerate() {
            if byte == b'/' || byte == b'\\' {
                self.push_segment(&filepath[start..index]);
                start = index + 1;
            }
        }
        self.push_segment(&filepath[start..]);
    }

    #[inline]
    fn push_segment(&mut self, segment: &str) {
        if segment.is_empty() || segment == "." {
            return;
        }

        if segment == ".." {
            self.push_parent();
            return;
        }

        self.push_separator();
        if is_drive_segment(segment) {
            self.output
                .push(segment.as_bytes()[0].to_ascii_uppercase() as char);
            self.output.push(':');
        } else {
            self.output.push_str(segment);
        }
    }

    #[inline]
    fn push_parent(&mut self) {
        if self.output == "/" {
            return;
        }

        let last = self.output.rsplit('/').next().unwrap_or_default();
        if is_root_segment(last) {
            return;
        }
        if last == ".." || last.is_empty() {
            self.push_separator();
            self.output.push_str("..");
            return;
        }

        match self.output.rfind('/') {
            Some(0) => self.output.truncate(1),
            Some(index) => self.output.truncate(index),
            None => self.output.clear(),
        }
    }

    #[inline]
    fn push_separator(&mut self) {
        if !self.output.is_empty() && !self.output.ends_with('/') {
            self.output.push(SEP);
        }
    }

    #[inline]
    fn finish(
        mut self,
        keep_tailing_slash: bool,
        has_suffix_sep: bool,
        logical_len: usize,
    ) -> String {
        if self.output.is_empty() {
            self.output.push('.');
        }

        if keep_tailing_slash
            && has_suffix_sep
            && logical_len > 1
            && self.output != "/"
            && !is_root_segment(&self.output)
        {
            self.output.push(SEP);
        }
        self.output
    }
}

#[inline]
fn is_drive_segment(segment: &str) -> bool {
    let bytes = segment.as_bytes();
    bytes.len() == 2 && bytes[0].is_ascii_alphabetic() && bytes[1] == b':'
}

#[inline]
fn is_root_segment(segment: &str) -> bool {
    let bytes = segment.as_bytes();
    bytes.len() == 2 && bytes[1] == b':'
}

#[inline]
fn canonical_output_len(filepath: &str, keep_tailing_slash: bool) -> Result<usize, usize> {
    if filepath.is_empty() {
        return Err(0);
    }

    let bytes = filepath.as_bytes();
    let mut start = 0;
    for (index, &byte) in bytes.iter().enumerate() {
        if byte == b'\\' {
            return Err(start);
        }
        if byte != b'/' {
            continue;
        }

        if index == start {
            if index != 0 {
                return Err(start);
            }
        } else if !is_canonical_segment(&filepath[start..index]) {
            return Err(start);
        }
        start = index + 1;
    }

    if start == filepath.len() {
        if filepath.len() == 1 {
            return Ok(1);
        }

        let output_len = filepath.len() - 1;
        if is_root_segment(&filepath[..output_len]) || !keep_tailing_slash {
            return Ok(output_len);
        }
        return Ok(filepath.len());
    }

    if is_canonical_segment(&filepath[start..]) {
        Ok(filepath.len())
    } else {
        Err(start)
    }
}

#[inline]
fn is_canonical_segment(segment: &str) -> bool {
    if segment == "." || segment == ".." {
        return false;
    }

    !is_drive_segment(segment) || !segment.as_bytes()[0].is_ascii_lowercase()
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/canonical_path/normalize_test.rs"
    ));
}
