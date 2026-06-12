use crate::error::AppResult;
use crate::model::RenderEvent;
use crate::runtime::StatusRuntime;

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

    pub fn render_status02_stdout(&self) -> AppResult<()> {
        self.runtime.render_status02_stdout()
    }

    pub fn dump_state(&self) -> AppResult<()> {
        self.runtime.dump_state()
    }
}
