//! Opt-in worker timings, compiled only into Rust tests.

use std::cell::RefCell;
use std::marker::PhantomData;
use std::rc::Rc;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

#[derive(Clone, Copy, Debug)]
#[repr(usize)]
pub(super) enum Stage {
    Job,
    SourceRead,
    SourceValues,
    Validate,
    Open,
    Transfer,
    Staging,
    Journal,
    PublishFs,
    PublishModel,
    Results,
    Cleanup,
    ExecutionWait,
    Permissions,
    OpenCall,
    Metadata,
    CreateCall,
    Close,
}

const NAMES: [&str; 18] = [
    "job",
    "source_read",
    "source_values",
    "validate",
    "open",
    "transfer",
    "staging",
    "journal",
    "publish_fs",
    "publish_model",
    "results",
    "cleanup",
    "execution_wait",
    "permissions",
    "open_call",
    "metadata",
    "create_call",
    "close",
];

#[derive(Clone, Copy, Default)]
struct Record {
    calls: u64,
    inclusive: Duration,
    exclusive: Duration,
}

#[derive(Default)]
pub(super) struct Profile(Mutex<[Record; NAMES.len()]>);

struct Active {
    started: Instant,
    children: Duration,
}

thread_local! {
    static CURRENT: RefCell<Option<Arc<Profile>>> = const { RefCell::new(None) };
    static STACK: RefCell<Vec<Active>> = const { RefCell::new(Vec::new()) };
}

pub(super) struct Scope {
    previous: Option<Arc<Profile>>,
    _thread: PhantomData<Rc<()>>,
}

pub(super) fn current() -> Option<Arc<Profile>> {
    CURRENT.with(|profile| profile.borrow().clone())
}

pub(super) fn enter(profile: Option<Arc<Profile>>) -> Scope {
    STACK.with(|stack| assert!(stack.borrow().is_empty()));
    Scope {
        previous: CURRENT.with(|active| active.replace(profile)),
        _thread: PhantomData,
    }
}

impl Drop for Scope {
    fn drop(&mut self) {
        STACK.with(|stack| assert!(stack.borrow().is_empty()));
        CURRENT.with(|active| active.replace(self.previous.take()));
    }
}

pub(super) struct Span {
    profile: Arc<Profile>,
    stage: Stage,
    depth: usize,
    _thread: PhantomData<Rc<()>>,
}

pub(super) fn span(stage: Stage) -> Option<Span> {
    let profile = current()?;
    let depth = STACK.with(|stack| {
        let mut stack = stack.borrow_mut();
        stack.push(Active {
            started: Instant::now(),
            children: Duration::ZERO,
        });
        stack.len()
    });
    Some(Span {
        profile,
        stage,
        depth,
        _thread: PhantomData,
    })
}

impl Drop for Span {
    fn drop(&mut self) {
        let (inclusive, exclusive) = STACK.with(|stack| {
            let mut stack = stack.borrow_mut();
            assert_eq!(stack.len(), self.depth);
            let active = stack.pop().unwrap();
            let inclusive = active.started.elapsed();
            if let Some(parent) = stack.last_mut() {
                parent.children += inclusive;
            }
            (inclusive, inclusive - active.children)
        });
        let mut records = self.profile.0.lock().unwrap();
        let record = &mut records[self.stage as usize];
        record.calls += 1;
        record.inclusive += inclusive;
        record.exclusive += exclusive;
    }
}

impl Profile {
    pub fn finished(&self) -> bool {
        self.0.lock().unwrap()[Stage::Job as usize].calls != 0
    }

    pub fn report(&self, files: usize, trial: usize) {
        for (name, record) in NAMES.iter().zip(self.0.lock().unwrap().iter()) {
            eprintln!(
                "copy_stage files={files} trial={trial} stage={name} calls={} inclusive_ns={} exclusive_ns={}",
                record.calls,
                record.inclusive.as_nanos(),
                record.exclusive.as_nanos()
            );
        }
    }
}

#[test]
fn t_profile_accounts_nested_time_once_and_restores_thread_scope() {
    assert!(span(Stage::Job).is_none());
    let profile = Arc::new(Profile::default());
    {
        let _scope = enter(Some(profile.clone()));
        let outer = span(Stage::Job);
        {
            let _child = span(Stage::SourceRead);
            std::thread::sleep(Duration::from_millis(1));
        }
        drop(outer);
    }
    assert!(current().is_none());
    let records = profile.0.lock().unwrap();
    let total = records[Stage::Job as usize];
    let child = records[Stage::SourceRead as usize];
    assert_eq!(total.calls, 1);
    assert_eq!(child.calls, 1);
    assert_eq!(total.inclusive, total.exclusive + child.exclusive);
    assert_eq!(child.inclusive, child.exclusive);
}
