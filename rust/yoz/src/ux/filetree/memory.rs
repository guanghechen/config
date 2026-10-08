use crate::ux::treeview::memory::Budget;
use crate::ux::treeview::{Error, Result};
use std::sync::Arc;
use std::sync::atomic::{AtomicUsize, Ordering};

pub(crate) const LIMIT: usize = 32 * 1024 * 1024;

/** Task reservations follow shared paths and records, including results retained by a caller. */
pub(crate) struct Memory {
    budget: Arc<Budget>,
    bytes: AtomicUsize,
}

impl Memory {
    pub fn new(budget: Arc<Budget>) -> Arc<Self> {
        Arc::new(Self {
            budget,
            bytes: AtomicUsize::new(0),
        })
    }

    pub fn used(&self) -> usize {
        self.bytes.load(Ordering::Relaxed)
    }

    pub fn reserve(self: &Arc<Self>, bytes: usize) -> Result<Reservation> {
        self.bytes
            .try_update(Ordering::AcqRel, Ordering::Acquire, |used| {
                used.checked_add(bytes).filter(|sum| *sum <= LIMIT)
            })
            .map_err(|_| Error::limit("file operation capacity exceeded"))?;
        self.budget.add(bytes);
        let reservation = Reservation {
            memory: self.clone(),
            bytes,
        };
        self.budget.check()?;
        Ok(reservation)
    }
}

pub(crate) struct Reservation {
    memory: Arc<Memory>,
    bytes: usize,
}

impl Reservation {
    pub(crate) fn bytes(&self) -> usize {
        self.bytes
    }

    pub(crate) fn grow(&mut self, bytes: usize) -> Result<()> {
        let mut added = self.memory.reserve(bytes)?;
        self.bytes += bytes;
        added.bytes = 0;
        Ok(())
    }

    pub(crate) fn split(&mut self, bytes: usize) -> Self {
        assert!(bytes <= self.bytes, "result reservation cannot grow");
        self.bytes -= bytes;
        Self {
            memory: self.memory.clone(),
            bytes,
        }
    }

    pub(crate) fn shrink(&mut self, bytes: usize) {
        assert!(bytes <= self.bytes, "result reservation cannot grow");
        let released = self.bytes - bytes;
        self.memory.bytes.fetch_sub(released, Ordering::Relaxed);
        self.memory.budget.remove(released);
        self.bytes = bytes;
    }
}

impl Drop for Reservation {
    fn drop(&mut self) {
        self.memory.bytes.fetch_sub(self.bytes, Ordering::Relaxed);
        self.memory.budget.remove(self.bytes);
    }
}
