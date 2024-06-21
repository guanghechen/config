pub fn parse_comma_list(input: &str) -> Vec<String> {
    let parts: Vec<String> = input
        //-
        .split(',')
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .map(|s| s.to_string())
        .collect();
    parts
}

pub fn normalize_comma_list(input: &str) -> String {
    let parts: Vec<String> = parse_comma_list(input);
    parts.join(", ")
}

pub struct NewlineIndices<'a> {
    text: &'a str,
    next_index: usize,
}

impl<'a> NewlineIndices<'a> {
    pub fn new(text: &'a str) -> Self {
        NewlineIndices {
            text,
            next_index: 0,
        }
    }
}

impl<'a> Iterator for NewlineIndices<'a> {
    type Item = usize;

    fn next(&mut self) -> Option<usize> {
        if self.next_index < self.text.len() {
            match self.text[self.next_index..].find('\n') {
                Some(index) => {
                    let newline_index = self.next_index + index;
                    self.next_index = newline_index + 1;
                    return Some(newline_index);
                }
                None => return Some(self.text.len()),
            }
        }
        None
    }
}
