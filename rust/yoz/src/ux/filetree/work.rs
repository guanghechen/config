use crate::ux::treeview::storage::Map;
use crate::ux::treeview::{Error, NodeId, Outcome, Reply, Result, Ticket};
use std::sync::{Arc, Mutex, OnceLock, mpsc};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(crate) struct Demand {
    pub generation: u64,
    pub observed: bool,
}
pub(crate) type Dirty = Arc<Mutex<Map<NodeId, Demand>>>;

type Work = Box<dyn FnOnce() + Send>;

/** Four process-wide workers; a scan yields its worker between acknowledged pages. */
pub(crate) fn submit(work: Work) -> Result<()> {
    static POOL: OnceLock<std::result::Result<mpsc::SyncSender<Work>, String>> = OnceLock::new();
    let pool = POOL.get_or_init(|| {
        let (sender, receiver) = mpsc::sync_channel::<Work>(256);
        let receiver = Arc::new(Mutex::new(receiver));
        for index in 0..4 {
            let receiver = receiver.clone();
            std::thread::Builder::new()
                .name(format!("yoz-filetree-io-{index}"))
                .spawn(move || {
                    loop {
                        let work = receiver
                            .lock()
                            .unwrap_or_else(|error| error.into_inner())
                            .recv();
                        let Ok(work) = work else { break };
                        work();
                    }
                })
                .map_err(|error| error.to_string())?;
        }
        Ok(sender)
    });
    let pool = pool
        .as_ref()
        .map_err(|error| Error::limit(error.as_str()))?;
    pool.try_send(work).map_err(|_| {
        Error::new(
            crate::ux::treeview::ErrorCode::Busy,
            "Filetree IO queue is full",
        )
    })
}

pub struct Request<T>(Arc<Mutex<Option<Result<T>>>>);
impl<T> Clone for Request<T> {
    fn clone(&self) -> Self {
        Self(self.0.clone())
    }
}
impl<T: Clone> Request<T> {
    pub fn poll(&self) -> Option<Result<T>> {
        self.0
            .lock()
            .unwrap_or_else(|error| error.into_inner())
            .clone()
    }
}
impl<T: Send + 'static> Request<T> {
    pub(crate) fn ready(result: Result<T>) -> Self {
        Self(Arc::new(Mutex::new(Some(result))))
    }

    pub(crate) fn run(work: impl FnOnce() -> Result<T> + Send + 'static) -> Self {
        let request = Self(Arc::new(Mutex::new(None)));
        let pending = request.clone();
        let scheduled = submit(Box::new(move || {
            let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(work))
                .unwrap_or_else(|_| Err(Error::invalid("Filetree worker panicked")));
            *pending.0.lock().unwrap_or_else(|error| error.into_inner()) = Some(result);
        }));
        if let Err(error) = scheduled {
            *request.0.lock().unwrap_or_else(|error| error.into_inner()) = Some(Err(error));
        }
        request
    }
}

pub(crate) fn wait(ticket: Ticket) -> Result<Reply> {
    match ticket.wait() {
        Outcome::Reply(Reply::Rejected { error }) => Err(error),
        Outcome::Reply(reply) => Ok(reply),
        _ => Err(Error::invalid("expected reply outcome")),
    }
}
