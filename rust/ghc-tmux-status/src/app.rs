use crate::error::AppResult;
use crate::model::RenderEvent;
use crate::runtime::StatusRuntime;
use crate::session::{FocusTarget, MoveDirection};

pub struct StatusApp {
    runtime: StatusRuntime,
}

impl StatusApp {
    pub fn live() -> Self {
        Self {
            runtime: StatusRuntime::live(),
        }
    }

    pub fn apply(&self, event: RenderEvent) -> AppResult<()> {
        self.runtime.apply(event)
    }

    pub fn heartbeat(&self, expected_generation: &str) -> AppResult<()> {
        self.runtime.heartbeat(expected_generation)
    }

    pub fn cpu_sample(&self, expected_generation: &str) -> AppResult<()> {
        self.runtime.cpu_sample(expected_generation)
    }

    pub fn render_status02_stdout(&self) -> AppResult<()> {
        self.runtime.render_status02_stdout()
    }

    pub fn dump_state(&self) -> AppResult<()> {
        self.runtime.dump_state()
    }

    pub fn focus_session(&self, target: FocusTarget) -> AppResult<()> {
        self.runtime.focus_session(target)
    }

    pub fn swap_session(&self, direction: MoveDirection) -> AppResult<()> {
        self.runtime.swap_session(direction)
    }
}
