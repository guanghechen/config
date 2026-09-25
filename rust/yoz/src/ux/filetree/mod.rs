//! Native filesystem resources composed with Treeview's data owner.

mod annotations;
mod details;
mod index;
mod io;
mod job_owner;
mod jobs;
pub(crate) mod lua;
mod model;
mod reader;
mod resource;
mod runtime;
mod scan;
mod watch;
mod work;

pub use annotations::{Annotation, AnnotationKind, AnnotationRows};
pub use details::Details;
pub use jobs::{
    CreatePlan, ItemResult, ItemStatus, Job, JobStatus, OperationKind, OperationPlan, TaskContext,
};
pub use model::{Entry, FileIdentity, Kind, display_name};
pub use resource::Resource;
pub use runtime::Filetree;
pub use watch::Status as WatchStatus;
pub use work::Request;

#[cfg(test)]
mod tests;

#[cfg(test)]
mod jobs_tests;
