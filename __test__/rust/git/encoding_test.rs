use super::*;

const FORMATS: [Unicode; 7] = [
    Unicode::Utf8,
    Unicode::Utf16Be,
    Unicode::Utf16Le,
    Unicode::Ucs2Be,
    Unicode::Ucs2Le,
    Unicode::Ucs4Be,
    Unicode::Ucs4Le,
];

#[test]
fn t_unicode_aliases_are_canonical_but_legacy_names_only_lowercase() {
    for (alias, expected) in [
        ("", "utf-8"),
        ("UTF_8", "utf-8"),
        ("utf8", "utf-8"),
        ("UTF16", "utf-16"),
        ("UTF_16BE", "utf-16"),
        ("utf16le", "utf-16le"),
        ("UTF_16LE", "utf-16le"),
        ("unicode", "ucs-2"),
        ("UCS2", "ucs-2"),
        ("UCS_2BE", "ucs-2"),
        ("ucs2le", "ucs-2le"),
        ("UCS_2LE", "ucs-2le"),
        ("UCS4", "ucs-4"),
        ("ucs-4be", "ucs-4"),
        ("UTF32", "ucs-4"),
        ("UTF_32BE", "ucs-4"),
        ("ucs4le", "ucs-4le"),
        ("UTF32LE", "ucs-4le"),
        ("UTF_32LE", "ucs-4le"),
        ("LATIN1", "latin1"),
        ("ISO_8859-1", "iso_8859-1"),
        ("SHIFT_JIS", "shift_jis"),
        ("unknown", "unknown"),
    ] {
        assert_eq!(normalize(alias.as_bytes()), expected.as_bytes(), "{alias}");
    }
    assert_eq!(normalize(b"\xff_UNKNOWN"), b"\xff_unknown".as_slice());
    assert!(Unicode::parse(b"latin1").is_none());
    for encoding in FORMATS {
        assert_eq!(Unicode::parse(encoding.name().as_bytes()), Some(encoding));
    }
}

#[test]
fn t_fixed_code_units_use_explicit_byte_order_and_no_implicit_bom() {
    let text = "A\0é中".as_bytes();
    for (encoding, expected) in [
        (Unicode::Utf8, b"A\0\xc3\xa9\xe4\xb8\xad".as_slice()),
        (Unicode::Utf16Be, b"\0A\0\0\0\xe9\x4e\x2d"),
        (Unicode::Utf16Le, b"A\0\0\0\xe9\0\x2d\x4e"),
        (Unicode::Ucs2Be, b"\0A\0\0\0\xe9\x4e\x2d"),
        (Unicode::Ucs2Le, b"A\0\0\0\xe9\0\x2d\x4e"),
        (Unicode::Ucs4Be, b"\0\0\0A\0\0\0\0\0\0\0\xe9\0\0\x4e\x2d"),
        (Unicode::Ucs4Le, b"A\0\0\0\0\0\0\0\xe9\0\0\0\x2d\x4e\0\0"),
    ] {
        assert_eq!(encoding.encode(text, false).unwrap(), expected);
        let decoded = encoding.decode(expected).unwrap();
        assert_eq!(decoded.text, text);
        assert!(!decoded.bomb);
    }
    for (encoding, expected) in [
        (Unicode::Utf16Be, b"\xd8\x3d\xde\x42".as_slice()),
        (Unicode::Utf16Le, b"\x3d\xd8\x42\xde"),
        (Unicode::Ucs4Be, b"\0\x01\xf6\x42"),
        (Unicode::Ucs4Le, b"\x42\xf6\x01\0"),
    ] {
        assert_eq!(encoding.encode("🙂".as_bytes(), false).unwrap(), expected);
        assert_eq!(encoding.decode(expected).unwrap().text, "🙂".as_bytes());
    }
}

#[test]
fn t_marker_and_leading_feff_are_independent_and_only_one_marker_is_removed() {
    for encoding in FORMATS {
        let text = "\u{feff}start\n".as_bytes();
        let bare = encoding.encode(text, false).unwrap();
        let marked = encoding.encode(text, true).unwrap();
        assert_eq!(marked.as_ref(), [encoding.bom(), bare.as_ref()].concat());
        assert!(marked.starts_with(&[encoding.bom(), encoding.bom()].concat()));
        let decoded = encoding.decode(&marked).unwrap();
        assert!(decoded.bomb);
        assert_eq!(decoded.text, text);
        assert_eq!(
            encoding.encode(&decoded.text, decoded.bomb).unwrap(),
            marked
        );

        // A single leading U+FEFF is inherently indistinguishable from a marker.
        let decoded = encoding.decode(&bare).unwrap();
        assert!(decoded.bomb);
        assert_eq!(decoded.text, b"start\n".as_slice());
        assert_eq!(encoding.encode(&decoded.text, decoded.bomb).unwrap(), bare);
    }
}

#[test]
fn t_empty_and_bom_only_files_round_trip() {
    for encoding in FORMATS {
        for bomb in [false, true] {
            let bytes = encoding.encode(b"", bomb).unwrap();
            assert_eq!(bytes.as_ref(), if bomb { encoding.bom() } else { b"" });
            let decoded = encoding.decode(&bytes).unwrap();
            assert_eq!(decoded.bomb, bomb);
            assert!(decoded.text.is_empty());
        }
    }
}

#[test]
fn t_utf8_preserves_arbitrary_bytes_and_borrows_when_no_marker_changes() {
    let bytes = b"\xff\0\xc0\x80\xed\xa0\x80\xf4\x90\x80\x80";
    let decoded = Unicode::Utf8.decode(bytes).unwrap();
    assert_eq!(decoded.text, bytes.as_slice());
    assert!(matches!(decoded.text, Cow::Borrowed(_)));
    let encoded = Unicode::Utf8.encode(bytes, false).unwrap();
    assert_eq!(encoded, bytes.as_slice());
    assert!(matches!(encoded, Cow::Borrowed(_)));
    let marked = Unicode::Utf8.encode(bytes, true).unwrap();
    assert_eq!(
        Unicode::Utf8.decode(&marked).unwrap().text,
        bytes.as_slice()
    );
}

#[test]
fn t_truncated_units_and_invalid_scalars_never_return_partial_text() {
    for (encoding, bytes) in [
        (Unicode::Utf16Be, b"\0".as_slice()),
        (Unicode::Utf16Le, b"\xff\xfe\0"),
        (Unicode::Ucs2Be, b"\0A\0"),
        (Unicode::Ucs2Le, b"A\0\0"),
        (Unicode::Ucs4Be, b"\0\0\0"),
        (Unicode::Ucs4Le, b"\xff\xfe\0\0\0"),
        (Unicode::Utf16Be, b"\0A\xd8\0"),
        (Unicode::Utf16Be, b"\xdc\0"),
        (Unicode::Utf16Le, b"\0\xd8A\0"),
        (Unicode::Utf16Le, b"\0\xdc\0\xd8"),
        (Unicode::Ucs2Be, b"\xd8\x3d\xde\x42"),
        (Unicode::Ucs2Le, b"\x3d\xd8\x42\xde"),
        (Unicode::Ucs4Be, b"\0\0\xd8\0"),
        (Unicode::Ucs4Le, b"\0\xd8\0\0"),
        (Unicode::Ucs4Be, b"\0\x11\0\0"),
        (Unicode::Ucs4Le, b"\0\0\x11\0"),
    ] {
        assert!(encoding.decode(bytes).is_err(), "{encoding:?}: {bytes:?}");
        let valid = encoding.encode(b"OK", true).unwrap();
        assert_eq!(encoding.decode(&valid).unwrap().text, b"OK".as_slice());
    }
}

#[test]
fn t_opposite_bom_is_rejected_without_cross_width_sniffing() {
    for encoding in FORMATS.into_iter().filter(|e| *e != Unicode::Utf8) {
        let opposite = encoding.opposite_bom().unwrap();
        assert_eq!(
            encoding.decode(opposite).err(),
            Some("BOM byte order conflicts with encoding")
        );
    }
    let decoded = Unicode::Utf16Le.decode(b"\xff\xfe\0\0").unwrap();
    assert!(decoded.bomb);
    assert_eq!(decoded.text, b"\0".as_slice());
    let decoded = Unicode::Utf16Be.decode(b"\xfe\xff\xff\xfe").unwrap();
    assert_eq!(decoded.text, "\u{fffe}".as_bytes());
}

#[test]
fn t_non_utf8_codecs_reject_invalid_utf8_and_ucs2_rejects_astral_characters() {
    for encoding in FORMATS.into_iter().filter(|e| *e != Unicode::Utf8) {
        for bytes in [
            b"\xff".as_slice(),
            b"\xc0\x80",
            b"\xed\xa0\x80",
            b"\xf4\x90\x80\x80",
            b"\xc3",
        ] {
            for bomb in [false, true] {
                assert_eq!(
                    encoding.encode(bytes, bomb).err(),
                    Some("invalid UTF-8 input")
                );
            }
        }
    }
    for encoding in [Unicode::Ucs2Be, Unicode::Ucs2Le] {
        for bomb in [false, true] {
            assert_eq!(
                encoding.encode("prefix🙂".as_bytes(), bomb).err(),
                Some("UCS-2 cannot represent non-BMP characters")
            );
        }
    }
}

#[test]
fn t_all_representable_scalars_round_trip_in_both_byte_orders() {
    let all: String = (0..=0x10ffff).filter_map(char::from_u32).collect();
    let bmp: String = (0..=0xffff).filter_map(char::from_u32).collect();
    for encoding in FORMATS {
        let text = if matches!(encoding, Unicode::Ucs2Be | Unicode::Ucs2Le) {
            bmp.as_bytes()
        } else {
            all.as_bytes()
        };
        for bomb in [false, true] {
            let bytes = encoding.encode(text, bomb).unwrap();
            let decoded = encoding.decode(&bytes).unwrap();
            assert_eq!(decoded.bomb, bomb);
            assert_eq!(decoded.text, text, "{encoding:?}");
        }
    }
}
