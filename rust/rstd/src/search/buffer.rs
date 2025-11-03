use super::text_utils::compute_line_offsets;
use std::borrow::Cow;
use std::ops::Range;

pub struct ISearchBuffer<'a> {
    text: Cow<'a, str>,
    line_offsets: Vec<usize>,
    line_ranges: Vec<Range<usize>>,
}

impl<'a> ISearchBuffer<'a> {
    pub fn from_text(text: &'a str) -> Self {
        Self::new(Cow::Borrowed(text))
    }

    pub fn as_str(&self) -> &str {
        self.text.as_ref()
    }

    pub fn as_bytes(&self) -> &[u8] {
        self.as_str().as_bytes()
    }

    pub fn line_offsets(&self) -> &[usize] {
        &self.line_offsets
    }

    pub fn line_count(&self) -> usize {
        self.line_ranges.len()
    }

    pub fn line_content_end(&self, line_number: usize) -> usize {
        if line_number == 0 {
            return 0;
        }

        let index = line_number.saturating_sub(1);
        if let Some(range) = self.line_ranges.get(index) {
            return range.end;
        }

        self.line_offsets
            .get(line_number)
            .copied()
            .unwrap_or_else(|| self.text.len())
    }

    pub fn line_slice(&self, index: usize) -> &str {
        if index >= self.line_ranges.len() {
            return "";
        }

        let range = self.line_ranges[index].clone();
        &self.as_str()[range]
    }

    pub fn iter_lines(&'a self) -> ISearchBufferIter<'a> {
        ISearchBufferIter {
            buffer: self,
            index: 0,
        }
    }

    fn new(text: Cow<'a, str>) -> Self {
        let offsets = compute_line_offsets(text.as_bytes());
        let ranges = compute_line_ranges(text.as_bytes(), &offsets);
        Self {
            text,
            line_offsets: offsets,
            line_ranges: ranges,
        }
    }
}

impl ISearchBuffer<'static> {
    pub fn from_lines(lines: &[String]) -> Self {
        if lines.is_empty() {
            return ISearchBuffer::new(Cow::Owned(String::new()));
        }

        let mut capacity = lines.iter().map(|line| line.len()).sum::<usize>();
        capacity = capacity.saturating_add(lines.len().saturating_sub(1));

        let mut text = String::with_capacity(capacity);
        for (index, line) in lines.iter().enumerate() {
            if index > 0 {
                text.push('\n');
            }
            text.push_str(line);
        }

        ISearchBuffer::new(Cow::Owned(text))
    }
}

pub struct ISearchBufferIter<'a> {
    buffer: &'a ISearchBuffer<'a>,
    index: usize,
}

impl<'a> Iterator for ISearchBufferIter<'a> {
    type Item = &'a str;

    fn next(&mut self) -> Option<Self::Item> {
        if self.index >= self.buffer.line_ranges.len() {
            return None;
        }

        let line = self.buffer.line_slice(self.index);
        self.index += 1;
        Some(line)
    }
}

fn compute_line_ranges(bytes: &[u8], offsets: &[usize]) -> Vec<Range<usize>> {
    if offsets.len() < 2 {
        return Vec::new();
    }

    let mut ranges = Vec::with_capacity(offsets.len().saturating_sub(1));
    for window in offsets.windows(2) {
        let start = window[0];
        let mut end = window[1];

        if end > start {
            if matches!(bytes.get(end.saturating_sub(1)), Some(b'\n')) {
                end = end.saturating_sub(1);
                if matches!(bytes.get(end.saturating_sub(1)), Some(b'\r')) {
                    end = end.saturating_sub(1);
                }
            } else if matches!(bytes.get(end.saturating_sub(1)), Some(b'\r')) {
                end = end.saturating_sub(1);
            }
        }

        ranges.push(start..end);
    }

    ranges
}
