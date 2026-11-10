use super::{Options, Snapshot, collect};
use crate::job::{self, QueryJob};
use std::sync::Arc;

pub type StatusJob = QueryJob<Arc<Snapshot>>;

pub fn start_status(options: Options) -> Result<StatusJob, String> {
    if !options.cwd.is_absolute() {
        return Err("Git status cwd must be absolute".into());
    }
    job::spawn("yoz-git-status", move |cancelled| {
        collect(&options, cancelled).map(Arc::new)
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::git::test_support::Fixture;
    use crate::job::Outcome;
    use crate::test_support::eventually;

    #[test]
    fn t_completed_result_is_repeatable_and_disposal_is_idempotent() {
        let fixture = Fixture::new();
        fixture.write("new", "content");
        let mut job = start_status(fixture.options()).unwrap();
        eventually(|| job.poll().unwrap().is_some());
        let Some(Outcome::Completed(first)) = job.poll().unwrap().cloned() else {
            panic!("completed")
        };
        let Some(Outcome::Completed(second)) = job.poll().unwrap() else {
            panic!("completed")
        };
        assert!(Arc::ptr_eq(&first, second));
        job.dispose();
        job.dispose();
        assert!(job.poll().is_err());
        assert!(job.cancel().is_err());
        assert_eq!(first.entries.len(), 1);
    }

    #[test]
    fn t_relative_cwd_is_rejected_before_worker_creation() {
        let fixture = Fixture::new();
        let mut options = fixture.options();
        options.cwd = "relative".into();
        assert!(start_status(options).is_err());
    }
}
