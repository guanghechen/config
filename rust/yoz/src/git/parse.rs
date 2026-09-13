use super::model::{Entry, Numstat, code_bit};
use std::collections::BTreeMap;

#[derive(Debug)]
pub struct RawRecord {
    pub relative: Vec<u8>,
    pub previous: Option<Vec<u8>>,
    pub old: Option<Vec<u8>>,
    pub new: Option<Vec<u8>>,
    pub code: u16,
}

pub type Stats = BTreeMap<Vec<u8>, Numstat>;

fn fields(output: &[u8]) -> Result<Vec<&[u8]>, String> {
    if !output.is_empty() && !output.ends_with(b"\0") {
        return Err("Incomplete Git NUL protocol output".into());
    }
    Ok(output.split(|byte| *byte == 0).collect())
}

fn object(bytes: &[u8]) -> Result<Option<Vec<u8>>, String> {
    if bytes.is_empty() || !bytes.iter().all(u8::is_ascii_hexdigit) {
        return Err("Malformed Git object id".into());
    }
    Ok(bytes
        .iter()
        .any(|byte| *byte != b'0')
        .then(|| bytes.to_vec()))
}

fn path_at<'a>(fields: &[&'a [u8]], index: usize) -> Result<&'a [u8], String> {
    fields
        .get(index)
        .copied()
        .filter(|path| !path.is_empty())
        .ok_or_else(|| "Missing Git pathname".into())
}

fn mode(bytes: &[u8]) -> bool {
    !bytes.is_empty() && bytes.iter().all(|byte| (b'0'..=b'7').contains(byte))
}

pub fn raw(output: &[u8], numstat: bool) -> Result<(Vec<RawRecord>, Stats), String> {
    let fields = fields(output)?;
    let mut records = Vec::new();
    let mut index = 0;
    while index + 1 < fields.len() && fields[index].starts_with(b":") {
        let header: Vec<_> = fields[index][1..].split(|byte| *byte == b' ').collect();
        if header.len() != 5 || !mode(header[0]) || !mode(header[1]) || header[4].is_empty() {
            return Err("Malformed Git raw record".into());
        }
        let code = header[4][0];
        let first = path_at(&fields, index + 1)?;
        let (relative, previous) = if code == b'R' || code == b'C' {
            let destination = path_at(&fields, index + 2)?;
            index += 3;
            (destination.to_vec(), Some(first.to_vec()))
        } else {
            index += 2;
            (first.to_vec(), None)
        };
        records.push(RawRecord {
            relative,
            previous,
            old: object(header[2])?,
            new: object(header[3])?,
            code: code_bit(code)?,
        });
    }

    let mut stats = BTreeMap::new();
    while index + 1 < fields.len() {
        if !numstat {
            return Err("Unexpected data after Git raw records".into());
        }
        let record: Vec<_> = fields[index].splitn(3, |byte| *byte == b'\t').collect();
        if record.len() != 3 {
            return Err("Malformed Git numstat record".into());
        }
        let relative = if record[2].is_empty() {
            let path = path_at(&fields, index + 2)?;
            path_at(&fields, index + 1)?;
            index += 3;
            path
        } else {
            index += 1;
            record[2]
        };
        if record[0] == b"-" && record[1] == b"-" {
            continue;
        }
        let number = |bytes: &[u8]| -> Result<u64, String> {
            std::str::from_utf8(bytes)
                .ok()
                .and_then(|text| text.parse().ok())
                .ok_or_else(|| "Malformed Git numstat count".into())
        };
        stats.insert(
            relative.to_vec(),
            Numstat {
                insertions: number(record[0])?,
                deletions: number(record[1])?,
            },
        );
    }
    Ok((records, stats))
}

pub fn paths(output: &[u8]) -> Result<Vec<Vec<u8>>, String> {
    let mut result = fields(output)?;
    result.pop();
    if result.iter().any(|path| path.is_empty()) {
        return Err("Empty Git pathname".into());
    }
    Ok(result.into_iter().map(<[u8]>::to_vec).collect())
}

pub fn entry<'a>(
    entries: &'a mut BTreeMap<Vec<u8>, Entry>,
    root: &[u8],
    relative: &[u8],
) -> &'a mut Entry {
    let mut absolute = root.to_vec();
    if !absolute.ends_with(b"/") {
        absolute.push(b'/');
    }
    absolute.extend_from_slice(relative);
    entries.entry(absolute).or_insert_with(|| Entry {
        relative: relative.to_vec(),
        ..Entry::default()
    })
}

#[derive(Debug)]
pub enum Porcelain {
    Complete(BTreeMap<Vec<u8>, Entry>),
    Raw { untracked: Vec<Vec<u8>> },
}

pub fn porcelain(output: &[u8], root: &[u8]) -> Result<Porcelain, String> {
    let fields = fields(output)?;
    let mut entries = BTreeMap::new();
    let mut untracked = Vec::new();
    let mut needs_raw = false;
    let (mut staged_add, mut staged_source) = (false, false);
    let (mut unstaged_add, mut unstaged_source) = (false, false);
    let mut index = 0;
    while index + 1 < fields.len() {
        let record = fields[index];
        match record.first() {
            Some(b'u') => needs_raw = true,
            Some(b'1' | b'2') => {
                let parts: Vec<_> = record.splitn(9, |byte| *byte == b' ').collect();
                if parts.len() != 9
                    || parts[1].len() != 2
                    || parts[2].len() != 4
                    || !mode(parts[3])
                    || !mode(parts[4])
                    || !mode(parts[5])
                    || parts[8].is_empty()
                {
                    return Err("Malformed Git porcelain-v2 tracked record".into());
                }
                let (staged, unstaged) = (parts[1][0], parts[1][1]);
                needs_raw |= parts[2] != b"N..." || matches!(unstaged, b'R' | b'C');
                let mut relative = parts[8];
                if parts[0] == b"2" {
                    let score: Vec<_> = relative.splitn(2, |byte| *byte == b' ').collect();
                    if score.len() != 2
                        || score[0].len() < 2
                        || !matches!(score[0][0], b'R' | b'C')
                        || !score[0][1..].iter().all(u8::is_ascii_digit)
                        || score[1].is_empty()
                    {
                        return Err("Malformed Git porcelain-v2 rename record".into());
                    }
                    relative = score[1];
                    index += 1;
                    path_at(&fields, index)?;
                    // Status and diff can use different rename/copy policies.
                    needs_raw = true;
                }
                let head = object(parts[6])?;
                let cached = object(parts[7])?;
                let item = entry(&mut entries, root, relative);
                if staged != b'.' {
                    item.staged |= code_bit(staged)?;
                    item.staged_old = head;
                    item.staged_new = cached.clone();
                    staged_add |= staged == b'A';
                    staged_source |= staged != b'A';
                }
                if unstaged != b'.' {
                    item.unstaged |= code_bit(unstaged)?;
                    item.unstaged_old = cached;
                    unstaged_add |= unstaged == b'A';
                    unstaged_source |= unstaged != b'A';
                }
            }
            Some(b'?') if record.starts_with(b"? ") && record.len() > 2 => {
                let relative = &record[2..];
                untracked.push(relative.to_vec());
                entry(&mut entries, root, relative).unstaged |= code_bit(b'?')?;
            }
            Some(b'#') => {}
            _ => return Err("Unexpected Git porcelain-v2 record".into()),
        }
        index += 1;
    }
    if needs_raw || (staged_add && staged_source) || (unstaged_add && unstaged_source) {
        Ok(Porcelain::Raw { untracked })
    } else {
        Ok(Porcelain::Complete(entries))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn t_raw_identity_rename_and_numstat_share_literal_paths() {
        let (records, stats) = raw(b":100644 100644 aaaaaaa bbbbbbb R100\0old\tfile\0new\nfile\0:100644 100644 aaaaaaa bbbbbbb M\0binary\0"
            .iter().chain(b"3\t1\t\0old\tfile\0new\nfile\0-\t-\tbinary\0").copied().collect::<Vec<_>>().as_slice(), true).unwrap();
        assert_eq!(records[0].relative, b"new\nfile");
        assert_eq!(
            records[0].previous.as_deref(),
            Some(b"old\tfile".as_slice())
        );
        assert_eq!(records[0].old.as_deref(), Some(b"aaaaaaa".as_slice()));
        assert_eq!(stats[b"new\nfile".as_slice()].insertions, 3);
        assert!(!stats.contains_key(b"binary".as_slice()));
    }

    #[test]
    fn t_porcelain_mixed_snapshot_and_untracked_are_complete() {
        let Porcelain::Complete(entries) = porcelain(
            b"1 MM N... 100644 100644 100644 aaaaaaa bbbbbbb mixed\0? untracked\0",
            b"/repo",
        )
        .unwrap() else {
            panic!("complete")
        };
        let item = &entries[b"/repo/mixed".as_slice()];
        assert_eq!(item.info().display, "MM");
        assert_eq!(item.unstaged_old.as_deref(), Some(b"bbbbbbb".as_slice()));
        assert!(item.unstaged_new.is_none());
        assert_eq!(entries[b"/repo/untracked".as_slice()].info().stage, None);
    }

    #[test]
    fn t_unborn_intent_to_add_and_non_utf8_paths() {
        let Porcelain::Complete(entries) = porcelain(
            b"1 A. N... 000000 100644 100644 0000000 aaaaaaa \xff\r\n\\name\0"
                .iter()
                .chain(b"1 .A N... 000000 000000 100644 0000000 0000000 intent\0")
                .copied()
                .collect::<Vec<_>>()
                .as_slice(),
            b"/repo",
        )
        .unwrap() else {
            panic!("complete")
        };
        assert!(
            entries[b"/repo/\xff\r\n\\name".as_slice()]
                .staged_old
                .is_none()
        );
        assert!(entries[b"/repo/intent".as_slice()].unstaged_old.is_none());
        assert_eq!(entries[b"/repo/intent".as_slice()].unstaged, 16);
    }

    #[test]
    fn t_rename_source_cannot_be_mistaken_for_an_untracked_record() {
        let Porcelain::Raw { untracked } = porcelain(b"2 R. N... 100644 100644 100644 aaaaaaa bbbbbbb R100 target\0? not-an-untracked-record\0? real\0", b"/repo").unwrap() else { panic!("raw required") };
        assert_eq!(untracked, vec![b"real".to_vec()]);
    }

    #[test]
    fn t_rename_candidates_and_submodules_require_raw_semantics() {
        for output in [
            b"1 A. N... 000000 100644 100644 0000000 bbbbbbb copy\0\
              1 M. N... 100644 100644 100644 aaaaaaa ccccccc original\0"
                .as_slice(),
            b"u UU N... 100644 100644 100644 100644 aaaaaaa bbbbbbb ccccccc file\0",
            b"1 .M S..U 160000 160000 160000 aaaaaaa aaaaaaa module\0",
        ] {
            assert!(matches!(
                porcelain(output, b"/repo").unwrap(),
                Porcelain::Raw { .. }
            ));
        }
    }

    #[test]
    fn t_malformed_records_reject_partial_snapshots() {
        for output in [
            b"? incomplete".as_slice(),
            b"? good\0invalid\0",
            b"1 broken\0",
            b"? \0",
            b"2 R. N... 100644 100644 100644 aaaaaaa bbbbbbb R100 target\0",
        ] {
            assert!(porcelain(output, b"/repo").is_err());
        }
        assert!(raw(b":100644 100644 aaaaaaa bbbbbbb R100\0old\0", false).is_err());
        assert!(raw(b"1\t0\t\0only-source\0", true).is_err());
    }
}
