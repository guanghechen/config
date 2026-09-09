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
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/git/encoding_test.rs"
    ));
}
