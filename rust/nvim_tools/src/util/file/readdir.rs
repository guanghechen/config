use chrono::{DateTime, Local};
use serde::{Deserialize, Serialize};
use std::ffi::CStr;
#[cfg(unix)]
use std::os::unix::fs::MetadataExt; // Import for Unix-specific metadata extensions
#[cfg(windows)]
use std::os::windows::fs::MetadataExt;
use std::path::Path;
use std::{fs, time::SystemTime}; // Import for Windows-specific metadata extensions

use crate::types::file::{FileItemWithStatus, FileType};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ReaddirSucceedResult {
    pub itself: FileItemWithStatus,
    pub items: Vec<FileItemWithStatus>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ReaddirFailedResult {
    pub error: String,
}

pub fn readdir<P: AsRef<Path>>(dirpath: P) -> Result<ReaddirSucceedResult, ReaddirFailedResult> {
    let itself: FileItemWithStatus = match flat_filestatus(dirpath.as_ref()) {
        Ok(item) => item,
        Err(e) => {
            return Err(ReaddirFailedResult {
                error: format!("[readdir] Failed to flat filestatus: {}", e),
            });
        }
    };

    match fs::read_dir(dirpath) {
        Ok(entries) => {
            let mut items: Vec<FileItemWithStatus> = Vec::new();
            for entry in entries {
                match entry {
                    Ok(entry) => match flat_filestatus(&entry.path()) {
                        Ok(item) => {
                            items.push(item);
                        }
                        Err(e) => {
                            return Err(ReaddirFailedResult {
                                error: format!("[readdir] Failed to flat filestatus: {}", e),
                            });
                        }
                    },
                    Err(e) => {
                        return Err(ReaddirFailedResult {
                            error: format!("[readdir] Failed to resolve entry: {}", e),
                        });
                    }
                }
            }

            // Sort items: directories first, then files, both alphabetically
            items.sort_by(|a, b| {
                // Directory first
                let filetype_ordering: std::cmp::Ordering =
                    a.filetype.ordinal().cmp(&b.filetype.ordinal());

                // Sort in the ordering of alphabetically by filename.
                if filetype_ordering == std::cmp::Ordering::Equal {
                    a.filename.cmp(&b.filename)
                } else {
                    filetype_ordering
                }
            });

            Ok(ReaddirSucceedResult { itself, items })
        }
        Err(e) => Err(ReaddirFailedResult {
            error: format!("[readdir] Failed to read directory: {}", e),
        }),
    }
}

pub fn flat_filestatus(path: &Path) -> Result<FileItemWithStatus, String> {
    let metadata = match fs::metadata(path) {
        Ok(metadata) => metadata,
        Err(e) => {
            return Err(format!(
                "Failed to get metadata for {}: {}",
                path.display(),
                e
            ));
        }
    };

    let filetype: FileType = if metadata.is_dir() {
        FileType::Directory
    } else {
        FileType::File
    };

    let filename: String = path
        .file_name()
        .unwrap_or_default()
        .to_string_lossy()
        .into_owned();

    #[cfg(unix)]
    let permission: String = format_permissions(&filetype, metadata.mode());

    #[cfg(windows)]
    let permission: String = format_permissions_windows(&filetype, metadata.file_attributes());

    let filesize: String = format_filesize(metadata.len());
    let owner: String = get_username_from_uid(metadata.uid()).unwrap_or("unknown".to_owned());
    let group: String = get_groupname_from_gid(metadata.gid()).unwrap_or("unknown".to_owned());
    let modify_time = match metadata.modified() {
        Ok(modified) => format_time(modified),
        Err(e) => return Err(format!("Failed to get date: {}", e)),
    };

    let item: FileItemWithStatus = FileItemWithStatus {
        filetype,
        filename,
        permission,
        filesize,
        owner,
        group,
        modify_time,
    };
    Ok(item)
}

// Convert the permission bits to a string like `ls -l` (Unix-specific)
#[cfg(unix)]
fn format_permissions(filetype: &FileType, mode: u32) -> String {
    let mut perm = String::with_capacity(10);
    match filetype {
        FileType::File => perm.push('-'),
        FileType::Directory => perm.push('d'),
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

// Convert the permission bits to a string for Windows (stub implementation)
#[cfg(windows)]
fn format_permissions_windows(filetype: &FileType, attributes: u32) -> String {
    let mut perm = String::with_capacity(10);
    match filetype {
        FileType::File => perm.push('-'),
        FileType::Directory => perm.push('d'),
    };

    perm.push(if attributes & 0x00000001 != 0 {
        'r'
    } else {
        '-'
    }); // Read-only
    perm.push(if attributes & 0x00000010 != 0 {
        'w'
    } else {
        '-'
    }); // Write-only (stub)
    perm.push(if attributes & 0x00000020 != 0 {
        'x'
    } else {
        '-'
    }); // Executable (stub)
        // Additional Windows-specific attributes handling could be added here
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
        return format!("{}B", size_bytes);
    };
    format!("{:.1}{}", value, unit)
}

pub fn format_time(timestamp: SystemTime) -> String {
    let datetime: DateTime<Local> = DateTime::from(timestamp);
    datetime.format("%b %d %H:%M").to_string()
}

#[cfg(unix)]
fn get_username_from_uid(uid: u32) -> Option<String> {
    unsafe {
        let pw = libc::getpwuid(uid as libc::uid_t);
        if pw.is_null() {
            None
        } else {
            let pw = &*pw;
            Some(CStr::from_ptr(pw.pw_name).to_string_lossy().into_owned())
        }
    }
}

#[cfg(windows)]
fn get_username_from_uid(_uid: u32) -> Option<String> {
    // Windows implementation placeholder
    Some("unknown".to_owned())
}

#[cfg(unix)]
fn get_groupname_from_gid(gid: u32) -> Option<String> {
    unsafe {
        let gr = libc::getgrgid(gid as libc::gid_t);
        if gr.is_null() {
            None
        } else {
            let gr = &*gr;
            Some(CStr::from_ptr(gr.gr_name).to_string_lossy().into_owned())
        }
    }
}

#[cfg(windows)]
fn get_groupname_from_gid(_gid: u32) -> Option<String> {
    // Windows implementation placeholder
    Some("unknown".to_owned())
}
