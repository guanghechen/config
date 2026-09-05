use super::{
    Backend, copy_ascii_capable, is_ascii_capable, resolve, source_id, validate_source_id,
};

#[test]
fn t_rejects_invalid_source_ids() {
    assert!(validate_source_id("").is_err());
    assert!(validate_source_id("invalid\0source").is_err());
}

#[test]
fn t_identifies_the_current_ascii_capable_source() {
    let (_, im) = copy_ascii_capable().expect("read current ASCII-capable source");
    assert_eq!(is_ascii_capable(im.as_ptr().cast(), "im.test"), Ok(true));
}

#[test]
fn t_reads_current_ascii_and_unknown_sources_without_changing_current_source() {
    let mut im = Backend::default();
    let before = im.capture().expect("read current input source");

    let (expected, _) = copy_ascii_capable().expect("read current ASCII-capable source");
    let resolved = resolve(&expected).expect("resolve current ASCII-capable source");
    assert_eq!(source_id(resolved.as_ptr().cast(), "im.test"), Ok(expected));

    let error = im
        .restore("dev.yoz.im.does-not-exist")
        .expect_err("unknown source must fail");

    assert!(error.contains("Enabled input source not found"));
    assert_eq!(im.capture(), Ok(before));
}
