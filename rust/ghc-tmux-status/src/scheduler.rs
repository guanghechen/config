use std::time::Duration;

use crate::config::{
    HEARTBEAT_EXECUTION_BUDGET_SECONDS, HEARTBEAT_EXECUTION_LEASE_SECONDS,
    HEARTBEAT_INTERVAL_SECONDS, HEARTBEAT_LAST_ATTEMPT_OPTION, HEARTBEAT_LAST_COMPLETE_OPTION,
    HEARTBEAT_LAST_EXEC_OUTCOME_OPTION, HEARTBEAT_SCHEDULER_STATE_OPTION,
    METRIC_EXECUTION_BUDGET_SECONDS, METRIC_EXECUTION_LEASE_SECONDS, METRIC_LAST_ATTEMPT_OPTION,
    METRIC_LAST_COMPLETE_OPTION, METRIC_LAST_EXEC_OUTCOME_OPTION, METRIC_RESAMPLE_INTERVAL_SECONDS,
    METRIC_SCHEDULER_STATE_OPTION,
};
use crate::process::OperationDeadline;

pub const SCHEDULER_SNAPSHOT_ENV: &str = "GHC_TMUX_STATUS_SCHEDULER_SNAPSHOT";

// load-theme is the single writer for renderer lifecycle (active + generation).
// The same fence gates standard renders and scheduler work. This module owns each
// task state and advances it one way: observed -> claimed -> completed. A
// claim/publish timeout is intentionally not retried because tmux may already have
// committed it; the lease is the only recovery writer after ambiguity.

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum SchedulerTask {
    Metrics,
    Heartbeat,
}

impl SchedulerTask {
    pub const ALL: [Self; 2] = [Self::Metrics, Self::Heartbeat];

    pub fn as_str(self) -> &'static str {
        match self {
            Self::Metrics => "metrics",
            Self::Heartbeat => "heartbeat",
        }
    }

    pub fn state_option(self) -> &'static str {
        match self {
            Self::Metrics => METRIC_SCHEDULER_STATE_OPTION,
            Self::Heartbeat => HEARTBEAT_SCHEDULER_STATE_OPTION,
        }
    }

    pub fn last_attempt_option(self) -> &'static str {
        match self {
            Self::Metrics => METRIC_LAST_ATTEMPT_OPTION,
            Self::Heartbeat => HEARTBEAT_LAST_ATTEMPT_OPTION,
        }
    }

    pub fn last_complete_option(self) -> &'static str {
        match self {
            Self::Metrics => METRIC_LAST_COMPLETE_OPTION,
            Self::Heartbeat => HEARTBEAT_LAST_COMPLETE_OPTION,
        }
    }

    pub fn last_outcome_option(self) -> &'static str {
        match self {
            Self::Metrics => METRIC_LAST_EXEC_OUTCOME_OPTION,
            Self::Heartbeat => HEARTBEAT_LAST_EXEC_OUTCOME_OPTION,
        }
    }

    pub fn interval_seconds(self) -> u64 {
        match self {
            Self::Metrics => METRIC_RESAMPLE_INTERVAL_SECONDS,
            Self::Heartbeat => HEARTBEAT_INTERVAL_SECONDS,
        }
    }

    pub fn lease_seconds(self) -> u64 {
        match self {
            Self::Metrics => METRIC_EXECUTION_LEASE_SECONDS,
            Self::Heartbeat => HEARTBEAT_EXECUTION_LEASE_SECONDS,
        }
    }

    fn execution_budget(self) -> Duration {
        Duration::from_secs(match self {
            Self::Metrics => METRIC_EXECUTION_BUDGET_SECONDS,
            Self::Heartbeat => HEARTBEAT_EXECUTION_BUDGET_SECONDS,
        })
    }
}

/// Read-only scheduler input captured by the driver before it launches Rust.
/// tmux remains the state owner and single writer: task mutations still compare
/// the exact transported strings before committing.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct SchedulerSnapshot {
    pub generation: u64,
    metric_state: String,
    heartbeat_state: String,
}

impl SchedulerSnapshot {
    pub fn from_observed(
        generation: u64,
        metric_state: impl Into<String>,
        heartbeat_state: impl Into<String>,
    ) -> Self {
        Self {
            generation,
            metric_state: metric_state.into(),
            heartbeat_state: heartbeat_state.into(),
        }
    }

    pub fn from_transport(value: &str) -> Option<Self> {
        let mut fields = value.split('\t');
        if fields.next()? != "1" {
            return None;
        }
        let generation = fields.next()?;
        let metric_state = fields.next()?;
        let heartbeat_state = fields.next()?;
        if fields.next().is_some() {
            return None;
        }
        let generation = generation.parse().ok()?;
        if !has_transport_shape(metric_state) || !has_transport_shape(heartbeat_state) {
            return None;
        }
        Some(Self::from_observed(
            generation,
            metric_state,
            heartbeat_state,
        ))
    }

    pub fn state_for(&self, task: SchedulerTask) -> &str {
        match task {
            SchedulerTask::Metrics => &self.metric_state,
            SchedulerTask::Heartbeat => &self.heartbeat_state,
        }
    }
}

fn has_transport_shape(value: &str) -> bool {
    let mut fields = value.split(':');
    let valid = (0..4).all(|_| {
        fields.next().is_some_and(|field| {
            !field.is_empty() && field.bytes().all(|byte| byte.is_ascii_digit())
        })
    });
    valid && fields.next().is_none()
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ScheduleState {
    pub generation: u64,
    pub sequence: u64,
    pub next_due_seconds: u64,
    pub lease_until_seconds: u64,
}

impl ScheduleState {
    pub fn parse(value: &str) -> Option<Self> {
        let mut fields = value.split(':');
        let state = Self {
            generation: fields.next()?.parse().ok()?,
            sequence: fields.next()?.parse().ok()?,
            next_due_seconds: fields.next()?.parse().ok()?,
            lease_until_seconds: fields.next()?.parse().ok()?,
        };
        fields.next().is_none().then_some(state)
    }

    pub fn encode(&self) -> String {
        format!(
            "{}:{}:{}:{}",
            self.generation, self.sequence, self.next_due_seconds, self.lease_until_seconds
        )
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ClaimPlan {
    pub task: SchedulerTask,
    pub generation: u64,
    pub sequence: u64,
    pub observed_state: String,
    pub claimed_state: String,
    pub completed_state: String,
    pub started_at_seconds: u64,
}

impl ClaimPlan {
    pub fn deadline(&self) -> OperationDeadline {
        OperationDeadline::new(
            format!("scheduler {}", self.task.as_str()),
            self.task.execution_budget(),
        )
    }
}

pub fn plan_claim(
    task: SchedulerTask,
    generation: u64,
    observed_state: &str,
    now_seconds: u64,
) -> Option<ClaimPlan> {
    let parsed = ScheduleState::parse(observed_state);
    if !is_due(task, generation, parsed.as_ref(), now_seconds) {
        return None;
    }

    let sequence = parsed
        .filter(|state| state.generation == generation)
        .map(|state| state.sequence.saturating_add(1))
        .unwrap_or(1);
    let next_due_seconds = now_seconds.saturating_add(task.interval_seconds());
    let claimed = ScheduleState {
        generation,
        sequence,
        next_due_seconds,
        lease_until_seconds: now_seconds.saturating_add(task.lease_seconds()),
    };
    let completed = ScheduleState {
        lease_until_seconds: 0,
        ..claimed.clone()
    };

    Some(ClaimPlan {
        task,
        generation,
        sequence,
        observed_state: observed_state.to_string(),
        claimed_state: claimed.encode(),
        completed_state: completed.encode(),
        started_at_seconds: now_seconds,
    })
}

fn is_due(
    task: SchedulerTask,
    generation: u64,
    state: Option<&ScheduleState>,
    now_seconds: u64,
) -> bool {
    let Some(state) = state else {
        return true;
    };
    if state.generation != generation {
        return true;
    }

    let future_limit = now_seconds.saturating_add(
        task.interval_seconds()
            .saturating_add(task.lease_seconds())
            .saturating_mul(2),
    );
    if state.next_due_seconds > future_limit || state.lease_until_seconds > future_limit {
        return true;
    }

    now_seconds >= state.next_due_seconds && now_seconds >= state.lease_until_seconds
}

#[cfg(test)]
mod tests {
    use super::{ScheduleState, SchedulerSnapshot, SchedulerTask, plan_claim};

    #[test]
    fn transported_snapshot_preserves_exact_cas_witnesses() {
        let snapshot =
            SchedulerSnapshot::from_transport("1\t42\t042:01:18446744073709551616:0\t42:2:100:0")
                .unwrap();

        assert_eq!(snapshot.generation, 42);
        assert_eq!(
            snapshot.state_for(SchedulerTask::Metrics),
            "042:01:18446744073709551616:0"
        );
        assert_eq!(snapshot.state_for(SchedulerTask::Heartbeat), "42:2:100:0");
    }

    #[test]
    fn transported_snapshot_rejects_ambiguous_framing() {
        for value in [
            "",
            "2\t42\t42:1:100:0\t42:2:100:0",
            "1\tinvalid\t42:1:100:0\t42:2:100:0",
            "1\t42\tinvalid\t42:2:100:0",
            "1\t42\t42:1:100\t42:2:100:0",
            "1\t42\t42:1:100:0\t42:2:100:0\textra",
        ] {
            assert!(SchedulerSnapshot::from_transport(value).is_none());
        }
    }

    #[test]
    fn missing_or_invalid_state_is_claimed_immediately() {
        for value in ["", "invalid"] {
            let plan = plan_claim(SchedulerTask::Metrics, 7, value, 100).unwrap();
            assert_eq!(plan.observed_state, value);
            assert_eq!(plan.claimed_state, "7:1:105:115");
            assert_eq!(plan.completed_state, "7:1:105:0");
        }
    }

    #[test]
    fn current_lease_and_future_due_block_claim() {
        assert!(plan_claim(SchedulerTask::Metrics, 7, "7:4:105:115", 100).is_none());
        assert!(plan_claim(SchedulerTask::Metrics, 7, "7:4:99:115", 100).is_none());
    }

    #[test]
    fn expired_lease_advances_sequence_without_catch_up() {
        let plan = plan_claim(SchedulerTask::Metrics, 7, "7:4:90:99", 100).unwrap();
        assert_eq!(plan.claimed_state, "7:5:105:115");
    }

    #[test]
    fn new_generation_restarts_sequence() {
        let plan = plan_claim(SchedulerTask::Heartbeat, 8, "7:99:1000:1000", 100).unwrap();
        assert_eq!(plan.claimed_state, "8:1:130:120");
    }

    #[test]
    fn clock_skewed_future_state_is_repaired() {
        let plan = plan_claim(SchedulerTask::Metrics, 7, "7:4:1000:1000", 100).unwrap();
        assert_eq!(plan.claimed_state, "7:5:105:115");
    }

    #[test]
    fn state_parser_requires_exact_unsigned_shape() {
        assert_eq!(
            ScheduleState::parse("7:4:105:0"),
            Some(ScheduleState {
                generation: 7,
                sequence: 4,
                next_due_seconds: 105,
                lease_until_seconds: 0,
            })
        );
        assert_eq!(ScheduleState::parse("7:4:105"), None);
        assert_eq!(ScheduleState::parse("7:4:105:0:extra"), None);
        assert_eq!(ScheduleState::parse("7:-1:105:0"), None);
    }
}
