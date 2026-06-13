pub fn shell_quote(value: &str) -> String {
    format!("'{}'", value.replace('\'', "'\\''"))
}

#[cfg(test)]
mod tests {
    use super::shell_quote;

    #[test]
    fn quotes_shell_arguments() {
        assert_eq!(shell_quote("/tmp/app"), "'/tmp/app'");
        assert_eq!(shell_quote("/tmp/with space/app"), "'/tmp/with space/app'");
        assert_eq!(shell_quote("/tmp/it's/app"), "'/tmp/it'\\''s/app'");
    }
}
