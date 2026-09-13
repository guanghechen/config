//! Unicode file codecs with Neovim's explicit byte order. No I/O or locale dependency.

use std::borrow::Cow;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Unicode {
    Utf8,
    Utf16Be,
    Utf16Le,
    Ucs2Be,
    Ucs2Le,
    Ucs4Be,
    Ucs4Le,
}

pub struct Decoded<'a> {
    pub text: Cow<'a, [u8]>,
    pub bomb: bool,
}

/// Canonicalize Unicode aliases; leave legacy names to iconv, apart from lowercasing.
pub fn normalize(name: &[u8]) -> Cow<'_, [u8]> {
    if name.is_empty() {
        return Cow::Borrowed(b"utf-8");
    }
    if let Some(encoding) = Unicode::parse(name) {
        return Cow::Borrowed(encoding.name().as_bytes());
    }
    let lowercase = name.to_ascii_lowercase();
    let alias: Vec<_> = lowercase
        .iter()
        .map(|&byte| if byte == b'_' { b'-' } else { byte })
        .collect();
    match Unicode::parse(&alias) {
        Some(encoding) => Cow::Borrowed(encoding.name().as_bytes()),
        None => Cow::Owned(lowercase),
    }
}

impl Unicode {
    /// Names here are lowercase with hyphens; use normalize() at the external boundary.
    pub fn parse(name: &[u8]) -> Option<Self> {
        Some(match name {
            b"utf-8" | b"utf8" => Self::Utf8,
            b"utf-16" | b"utf16" | b"utf-16be" | b"utf16be" => Self::Utf16Be,
            b"utf-16le" | b"utf16le" => Self::Utf16Le,
            b"ucs-2" | b"ucs2" | b"ucs-2be" | b"ucs2be" | b"unicode" => Self::Ucs2Be,
            b"ucs-2le" | b"ucs2le" => Self::Ucs2Le,
            b"ucs-4" | b"ucs4" | b"ucs-4be" | b"ucs4be" | b"utf-32" | b"utf32" | b"utf-32be"
            | b"utf32be" => Self::Ucs4Be,
            b"ucs-4le" | b"ucs4le" | b"utf-32le" | b"utf32le" => Self::Ucs4Le,
            _ => return None,
        })
    }

    pub fn name(self) -> &'static str {
        match self {
            Self::Utf8 => "utf-8",
            Self::Utf16Be => "utf-16",
            Self::Utf16Le => "utf-16le",
            Self::Ucs2Be => "ucs-2",
            Self::Ucs2Le => "ucs-2le",
            Self::Ucs4Be => "ucs-4",
            Self::Ucs4Le => "ucs-4le",
        }
    }

    fn bom(self) -> &'static [u8] {
        match self {
            Self::Utf8 => b"\xef\xbb\xbf",
            Self::Utf16Be | Self::Ucs2Be => b"\xfe\xff",
            Self::Utf16Le | Self::Ucs2Le => b"\xff\xfe",
            Self::Ucs4Be => b"\0\0\xfe\xff",
            Self::Ucs4Le => b"\xff\xfe\0\0",
        }
    }

    fn opposite_bom(self) -> Option<&'static [u8]> {
        Some(match self {
            Self::Utf8 => return None,
            Self::Utf16Be | Self::Ucs2Be => Self::Utf16Le.bom(),
            Self::Utf16Le | Self::Ucs2Le => Self::Utf16Be.bom(),
            Self::Ucs4Be => Self::Ucs4Le.bom(),
            Self::Ucs4Le => Self::Ucs4Be.bom(),
        })
    }

    fn little_endian(self) -> bool {
        matches!(self, Self::Utf16Le | Self::Ucs2Le | Self::Ucs4Le)
    }

    pub fn decode(self, bytes: &[u8]) -> Result<Decoded<'_>, &'static str> {
        let payload = bytes.strip_prefix(self.bom());
        if payload.is_none()
            && self
                .opposite_bom()
                .is_some_and(|bom| bytes.starts_with(bom))
        {
            return Err("BOM byte order conflicts with encoding");
        }
        let bomb = payload.is_some();
        let bytes = payload.unwrap_or(bytes);
        if self == Self::Utf8 {
            // Ordinary buffers may contain invalid UTF-8. Preserve their existing byte contract.
            return Ok(Decoded {
                text: Cow::Borrowed(bytes),
                bomb,
            });
        }

        let mut text = String::with_capacity(bytes.len());
        let little = self.little_endian();
        if matches!(self, Self::Ucs4Be | Self::Ucs4Le) {
            if !bytes.len().is_multiple_of(4) {
                return Err("truncated code unit");
            }
            for unit in bytes.chunks_exact(4) {
                let unit = [unit[0], unit[1], unit[2], unit[3]];
                let scalar = if little {
                    u32::from_le_bytes(unit)
                } else {
                    u32::from_be_bytes(unit)
                };
                text.push(char::from_u32(scalar).ok_or("invalid Unicode scalar")?);
            }
        } else {
            if !bytes.len().is_multiple_of(2) {
                return Err("truncated code unit");
            }
            let units = bytes.chunks_exact(2).map(|unit| {
                let unit = [unit[0], unit[1]];
                if little {
                    u16::from_le_bytes(unit)
                } else {
                    u16::from_be_bytes(unit)
                }
            });
            if matches!(self, Self::Ucs2Be | Self::Ucs2Le) {
                for unit in units {
                    text.push(char::from_u32(u32::from(unit)).ok_or("UCS-2 contains a surrogate")?);
                }
            } else {
                for scalar in char::decode_utf16(units) {
                    text.push(scalar.map_err(|_| "invalid UTF-16 surrogate pair")?);
                }
            }
        }
        Ok(Decoded {
            text: Cow::Owned(text.into_bytes()),
            bomb,
        })
    }

    pub fn encode(self, text: &[u8], bomb: bool) -> Result<Cow<'_, [u8]>, &'static str> {
        if self == Self::Utf8 && !bomb {
            return Ok(Cow::Borrowed(text));
        }
        let mut bytes = Vec::with_capacity(text.len() + if bomb { self.bom().len() } else { 0 });
        if bomb {
            // The marker is independent of a leading U+FEFF in the document body.
            bytes.extend_from_slice(self.bom());
        }
        if self == Self::Utf8 {
            bytes.extend_from_slice(text);
            return Ok(Cow::Owned(bytes));
        }

        let text = std::str::from_utf8(text).map_err(|_| "invalid UTF-8 input")?;
        let little = self.little_endian();
        if matches!(self, Self::Ucs4Be | Self::Ucs4Le) {
            for scalar in text.chars() {
                bytes.extend_from_slice(&if little {
                    (scalar as u32).to_le_bytes()
                } else {
                    (scalar as u32).to_be_bytes()
                });
            }
        } else {
            let ucs2 = matches!(self, Self::Ucs2Be | Self::Ucs2Le);
            for scalar in text.chars() {
                if ucs2 && scalar as u32 > 0xffff {
                    return Err("UCS-2 cannot represent non-BMP characters");
                }
                for unit in scalar.encode_utf16(&mut [0; 2]) {
                    bytes.extend_from_slice(&if little {
                        unit.to_le_bytes()
                    } else {
                        unit.to_be_bytes()
                    });
                }
            }
        }
        Ok(Cow::Owned(bytes))
    }
}

#[cfg(test)]
mod tests {
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
}
