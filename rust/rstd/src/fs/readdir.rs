use crate::types::fs::{IFsFileItemWithStatus, IFsFileType, IFsReaddirError, IFsReaddirResult};
use chrono::{DateTime, Local};
#[cfg(unix)]
use std::ffi::CStr;
use std::fs;
#[cfg(unix)]
use std::os::unix::fs::MetadataExt;
#[cfg(windows)]
use std::os::windows::fs::MetadataExt;
use std::path::Path;
use std::time::SystemTime;

pub fn readdir(dirpath: &str) -> Result<IFsReaddirResult, IFsReaddirError> {
    let path = Path::new(dirpath);

    let itself = match flat_filestatus(path) {
        Ok(item) => item,
        Err(error) => {
            return Err(IFsReaddirError {
                error: format!("[readdir] Failed to flat filestatus: {error}"),
            });
        }
    };

    match fs::read_dir(path) {
        Ok(entries) => {
            let mut items = Vec::new();

            for entry in entries {
                match entry {
                    Ok(entry) => match flat_filestatus(&entry.path()) {
                        Ok(item) => items.push(item),
                        Err(error) => {
                            return Err(IFsReaddirError {
                                error: format!("[readdir] Failed to flat filestatus: {error}"),
                            });
                        }
                    },
                    Err(error) => {
                        return Err(IFsReaddirError {
                            error: format!("[readdir] Failed to resolve entry: {error}"),
                        });
                    }
                }
            }

            items.sort_by(|a, b| {
                let filetype_ordering = a.filetype.ordinal().cmp(&b.filetype.ordinal());
                if filetype_ordering == std::cmp::Ordering::Equal {
                    a.filename.cmp(&b.filename)
                } else {
                    filetype_ordering
                }
            });

            Ok(IFsReaddirResult { itself, items })
        }
        Err(error) => Err(IFsReaddirError {
            error: format!("[readdir] Failed to read directory: {error}"),
        }),
    }
}

pub fn get_filesize(filepath: &str) -> Result<String, String> {
    let metadata =
        fs::metadata(filepath).map_err(|error| format!("Failed to get metadata {error}"))?;

    Ok(format_filesize(metadata.len()))
}

fn flat_filestatus(path: &Path) -> Result<IFsFileItemWithStatus, String> {
    let metadata = fs::metadata(path)
        .map_err(|error| format!("Failed to get metadata for {}: {error}", path.display()))?;

    let filetype = if metadata.is_dir() {
        IFsFileType::Directory
    } else {
        IFsFileType::File
    };

    let filename = path
        .file_name()
        .unwrap_or_default()
        .to_string_lossy()
        .into_owned();

    #[cfg(unix)]
    let permission = format_permissions(&filetype, metadata.mode());
    #[cfg(windows)]
    let permission = format_permissions_windows(&filetype, metadata.file_attributes());

    #[cfg(unix)]
    let owner = get_username_from_uid(metadata.uid()).unwrap_or_else(|| "unknown".to_owned());
    #[cfg(windows)]
    let owner = "unknown".to_owned();

    #[cfg(unix)]
    let group = get_groupname_from_gid(metadata.gid()).unwrap_or_else(|| "unknown".to_owned());
    #[cfg(windows)]
    let group = "unknown".to_owned();

    let filesize = format_filesize(metadata.len());
    let modify_time = metadata
        .modified()
        .map(format_time)
        .map_err(|error| format!("Failed to get date: {error}"))?;

    Ok(IFsFileItemWithStatus {
        filetype,
        filename,
        permission,
        filesize,
        owner,
        group,
        modify_time,
    })
}

#[cfg(unix)]
fn format_permissions(filetype: &IFsFileType, mode: u32) -> String {
    let mut perm = String::with_capacity(10);
    match filetype {
        IFsFileType::File => perm.push('-'),
        IFsFileType::Directory => perm.push('d'),
    };

    perm.push(if mode & 0o400 != 0 { 'r' } else { '-' });
    perm.push(if mode & 0o200 != 0 { 'w' } else { '-' });
    perm.push(if mode & 0o100 != 0 { 'x' } else { '-' });
    perm.push(if mode & 0o040 != 0 { 'r' } else { '-' });
    perm.push(if mode & 0o020 != 0 { 'w' } else { '-' });
    perm.push(if mode & 0o010 != 0 { 'x' } else { '-' });
    perm.push(if mode & 0o004 != 0 { 'r' } else { '-' });
    perm.push(if mode & 0o002 != 0 { 'w' } else { '-' });
    perm.push(if mode & 0o001 != 0 { 'x' } else { '-' });
    perm
}

#[cfg(windows)]
fn format_permissions_windows(filetype: &IFsFileType, attributes: u32) -> String {
    let mut perm = String::with_capacity(10);
    match filetype {
        IFsFileType::File => perm.push('-'),
        IFsFileType::Directory => perm.push('d'),
    };

    if attributes & 0x00000001 != 0 {
        perm.push('r');
        perm.push('-');
        perm.push('-');
    } else {
        perm.push('r');
        perm.push('w');
        perm.push('-');
    }

    perm
}

const KB: u64 = 1024;
const MB: u64 = KB * 1024;
const GB: u64 = MB * 1024;
const TB: u64 = GB * 1024;

fn format_filesize(size_bytes: u64) -> String {
    let (value, unit) = if size_bytes >= TB {
        (size_bytes as f64 / TB as f64, "TB")
    } else if size_bytes >= GB {
        (size_bytes as f64 / GB as f64, "GB")
    } else if size_bytes >= MB {
        (size_bytes as f64 / MB as f64, "MB")
    } else if size_bytes >= KB {
        (size_bytes as f64 / KB as f64, "KB")
    } else {
        return format!("{size_bytes}B");
    };

    let remain: u32 = ((value * 100.0).round() as u32) % 100;
    if remain == 0 {
        format!("{}{unit}", value.round())
    } else if remain.is_multiple_of(10) {
        format!("{value:.1}{unit}")
    } else {
        format!("{value:.2}{unit}")
    }
}

fn format_time(timestamp: SystemTime) -> String {
    let datetime: DateTime<Local> = DateTime::from(timestamp);
    datetime.format("%b %d %H:%M").to_string()
}

#[cfg(unix)]
fn get_username_from_uid(uid: u32) -> Option<String> {
    unsafe {
        let pw = libc::getpwuid(uid as libc::uid_t);
        if pw.is_null() {
            return None;
        }
        let name = (*pw).pw_name;
        if name.is_null() {
            return None;
        }
        CStr::from_ptr(name).to_str().ok().map(|s| s.to_owned())
    }
}

#[cfg(unix)]
fn get_groupname_from_gid(gid: u32) -> Option<String> {
    unsafe {
        let gr = libc::getgrgid(gid as libc::gid_t);
        if gr.is_null() {
            return None;
        }
        let name = (*gr).gr_name;
        if name.is_null() {
            return None;
        }
        CStr::from_ptr(name).to_str().ok().map(|s| s.to_owned())
    }
}
