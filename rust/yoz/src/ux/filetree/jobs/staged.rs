use super::*;
use crate::ux::filetree::io::staging::Staging;
use std::fs;

#[cfg(test)]
mod tests;

struct Directory {
    source: Item,
    path: PathBuf,
    target: PathBuf,
    staged: usize,
    children: Cursor,
    success: bool,
    result_start: usize,
    charge: Option<Reservation>,
}

impl Runner {
    fn staged_reservation(
        &mut self,
        entry: &Entry,
        path: &Path,
        target: &Path,
    ) -> Result<Reservation> {
        let bytes = 4096
            + entry.encoded_len() * 2
            + path.as_os_str().len() * 2
            + target.as_os_str().len() * 2;
        self.reserve(bytes)
    }

    fn discard_results(&mut self, results: &mut Vec<Arc<ItemResult>>, start: usize) {
        results.truncate(start);
        if results.capacity() > results.len() * 2 {
            results.shrink_to_fit();
        }
    }

    pub(super) fn copy_directory(
        &mut self,
        source: Item,
        target: Resource,
        path: PathBuf,
        destination: Destination,
        charge: Reservation,
    ) -> Result<bool> {
        self.flush_copies();
        self.check()?;
        let _memory = self.memory.enter();
        let expected = Signature::entry(&source.entry()?, false);
        let parent = source.parent_signature(&self.plan.source)?;
        let children = match self.cursor(&source) {
            Ok(children) => children,
            Err(error) => {
                self.record(
                    &source,
                    path,
                    Some(destination.path),
                    ItemStatus::Failed,
                    Some(std::io::Error::other(error.clone())),
                    None,
                    charge,
                );
                return if self.job.0.cancel.load(Ordering::Acquire)
                    || error.code == ErrorCode::ResourceLimit
                {
                    Err(error)
                } else {
                    Ok(false)
                };
            }
        };
        let mut staged = {
            let _execution = EXECUTOR.lock().unwrap_or_else(|error| error.into_inner());
            self.check()?;
            self.check_item(&source)?;
            let created = (|| {
                self.verify_directory(&expected, &path)
                    .map_err(std::io::Error::other)?;
                if let Some(parent) = &parent {
                    self.verify_directory(parent, path.parent().expect("source parent"))
                        .map_err(std::io::Error::other)?;
                }
                Staging::new(
                    &destination,
                    fs::symlink_metadata(&path)?.permissions(),
                    self.job.0.task_memory.clone(),
                )
            })();
            match created {
                Ok(staged) => staged,
                Err(error) => {
                    let fatal = error
                        .get_ref()
                        .and_then(|error| error.downcast_ref::<Error>())
                        .filter(|error| error.code == ErrorCode::ResourceLimit)
                        .cloned();
                    self.record(
                        &source,
                        path,
                        Some(destination.path),
                        ItemStatus::Failed,
                        Some(error),
                        None,
                        charge,
                    );
                    return fatal.map_or(Ok(false), Err);
                }
            }
        };
        let mut results = Vec::new();
        let mut stack = vec![Directory {
            source: source.clone(),
            path: path.clone(),
            target: destination.path.clone(),
            staged: 0,
            children,
            success: true,
            result_start: 0,
            charge: None,
        }];
        let walked = (|| -> Result<bool> {
            loop {
                self.check()?;
                let current = stack.last_mut().expect("directory copy frame");
                self.fill_cursor(&mut current.children)?;
                let child = current.children.pop();
                let Some(source) = child else {
                    let directory = stack.pop().expect("completed directory");
                    let success = directory.success;
                    if let Some(charge) = directory.charge {
                        if success {
                            self.discard_results(&mut results, directory.result_start);
                        }
                        results.push(self.result(
                            &directory.source,
                            directory.path,
                            Some(directory.target),
                            if success {
                                ItemStatus::Success
                            } else {
                                ItemStatus::Failed
                            },
                            None,
                            None,
                            charge,
                        ));
                    }
                    let Some(parent) = stack.last_mut() else {
                        return Ok(success);
                    };
                    parent.success &= success;
                    continue;
                };
                #[cfg(test)]
                let values = crate::ux::filetree::profile::span(
                    crate::ux::filetree::profile::Stage::SourceValues,
                );
                let entry = source.entry()?;
                let source_path = source.path.clone();
                let target_path = current.target.join(&entry.name);
                let parent_node = current.staged;
                let parent_expected = Signature::entry(&current.source.entry()?, true);
                let source_parent = current.path.clone();
                let charge = self.staged_reservation(&entry, &source_path, &target_path)?;
                let signature = Signature::entry(&entry, false);
                #[cfg(test)]
                drop(values);
                if entry.kind == Kind::Directory {
                    let prepared = self.cursor(&source).and_then(|children| {
                        let _execution = EXECUTOR.lock().unwrap_or_else(|error| error.into_inner());
                        self.check()?;
                        self.check_item(&source)?;
                        let result = (|| {
                            self.verify_directory(&parent_expected, &source_parent)
                                .map_err(std::io::Error::other)?;
                            self.verify_directory(&signature, &source_path)
                                .map_err(std::io::Error::other)?;
                            let permissions = fs::symlink_metadata(&source_path)?.permissions();
                            staged.create_directory(parent_node, &entry.name, permissions)
                        })();
                        result
                            .map(|index| (children, index))
                            .map_err(|error| resource::io_error("stage directory", error))
                    });
                    match prepared {
                        Ok((children, index)) => {
                            stack.push(Directory {
                                source,
                                path: source_path,
                                target: target_path,
                                staged: index,
                                children,
                                success: true,
                                result_start: results.len(),
                                charge: Some(charge),
                            });
                        }
                        Err(error) => {
                            stack.last_mut().expect("parent").success = false;
                            results.push(self.result(
                                &source,
                                source_path,
                                Some(target_path),
                                ItemStatus::Failed,
                                Some(std::io::Error::other(error.clone())),
                                None,
                                charge,
                            ));
                            if staged.damaged() || error.code == ErrorCode::ResourceLimit {
                                return Err(error);
                            }
                        }
                    }
                    continue;
                }
                let copied = {
                    #[cfg(test)]
                    let waiting = crate::ux::filetree::profile::span(
                        crate::ux::filetree::profile::Stage::ExecutionWait,
                    );
                    let _execution = EXECUTOR.lock().unwrap_or_else(|error| error.into_inner());
                    #[cfg(test)]
                    drop(waiting);
                    self.check_item(&source)?;
                    self.verify_directory(&parent_expected, &source_parent)?;
                    let job = self.job.clone();
                    (|| {
                        staged.copy(
                            &mut self.copier,
                            &source_path,
                            &signature,
                            parent_node,
                            &entry.name,
                            &job.0.cancel,
                            |bytes| job.copied(bytes),
                        )?;
                        Ok::<_, std::io::Error>(())
                    })()
                };
                let fatal = copied
                    .as_ref()
                    .err()
                    .and_then(|error| error.get_ref())
                    .and_then(|error| error.downcast_ref::<Error>())
                    .filter(|error| error.code == ErrorCode::ResourceLimit)
                    .cloned();
                let success = copied.is_ok();
                stack.last_mut().expect("parent").success &= success;
                results.push(self.result(
                    &source,
                    source_path,
                    Some(target_path),
                    if success {
                        ItemStatus::Success
                    } else {
                        ItemStatus::Failed
                    },
                    copied.err(),
                    None,
                    charge,
                ));
                if let Some(error) = fatal {
                    return Err(error);
                }
                if staged.damaged() {
                    return Err(Error::stale("staged output ownership changed"));
                }
            }
        })();
        for directory in stack.into_iter().rev() {
            if let Some(charge) = directory.charge {
                results.push(self.result(
                    &directory.source,
                    directory.path,
                    Some(directory.target),
                    ItemStatus::Failed,
                    Some(std::io::Error::new(
                        std::io::ErrorKind::Interrupted,
                        "directory copy stopped before completion",
                    )),
                    None,
                    charge,
                ));
            }
        }
        let success = matches!(walked, Ok(true));
        let published = {
            let _phase = self.job.phase(JobPhase::Publishing);
            let _execution = EXECUTOR.lock().unwrap_or_else(|error| error.into_inner());
            let result = (|| -> std::io::Result<()> {
                self.check_context().map_err(std::io::Error::other)?;
                source
                    .current(&self.tree.source(), &self.plan.source)
                    .map_err(std::io::Error::other)?;
                job_owner::current(&self.tree.source(), &target, true)
                    .map_err(std::io::Error::other)?;
                self.verify_directory(&expected, &path)
                    .map_err(std::io::Error::other)?;
                if let Some(parent) = &parent {
                    self.verify_directory(parent, path.parent().expect("source parent"))
                        .map_err(std::io::Error::other)?;
                }
                staged.publish(&destination)
            })();
            match result {
                Ok(()) => Ok(io::observed_output(&destination.path, Some(staged.file()))),
                Err(error) => {
                    let result = match staged.clean() {
                        Ok(()) => error,
                        Err(cleanup) => {
                            std::io::Error::new(error.kind(), format!("{error}; {cleanup}"))
                        }
                    };
                    Err(result)
                }
            }
        };
        drop(staged);
        match published {
            Err(error) => {
                self.discard_results(&mut results, 0);
                self.record(
                    &source,
                    path,
                    Some(destination.path),
                    ItemStatus::Failed,
                    Some(error),
                    None,
                    charge,
                );
                if let Err(error) = walked {
                    return Err(error);
                }
                Ok(false)
            }
            Ok(observed) => {
                if success {
                    self.discard_results(&mut results, 0);
                }
                let sync = observed
                    .map_err(|error| resource::io_error("read published directory", error))
                    .and_then(|entry| {
                        self.publish(&source, Some(target), Some(entry), false, None, None, None)
                            .map(|_| ())
                    });
                for result in results {
                    self.deliver(result);
                }
                self.record(
                    &source,
                    path,
                    Some(destination.path),
                    if success {
                        ItemStatus::Success
                    } else {
                        ItemStatus::Failed
                    },
                    None,
                    sync.err(),
                    charge,
                );
                walked
            }
        }
    }
}
