use super::{LuaFiletree, LuaResource, path, paths};
use crate::ux::filetree::{
    CreatePlan, ItemStatus, Job, JobPhase, OperationKind, OperationPlan, TaskContext,
};
use crate::ux::treeview::lua::{LuaIds, LuaSource, LuaState, input, output};
use crate::ux::treeview::{CleanupToken, Error, LockToken};
use mlua::prelude::*;

pub(crate) struct LuaJob(pub(crate) Job);
fn status(value: ItemStatus) -> &'static str {
    match value {
        ItemStatus::Success => "success",
        ItemStatus::Failed => "failed",
        ItemStatus::Skipped => "skipped",
    }
}
impl LuaUserData for LuaJob {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("status", |lua, this, previous: Option<String>| {
            let previous = previous
                .map(|value| value.parse::<u64>())
                .transpose()
                .map_err(|_| LuaError::external(Error::invalid("invalid Job status revision")))?;
            let Some(status) = this.0.status_since(previous) else {
                return Ok(None);
            };
            let value = lua.create_table()?;
            value.set("revision", status.revision.to_string())?;
            value.set("terminal", status.terminal)?;
            value.set("cancelling", status.cancelling)?;
            value.set("cancelled", status.cancelled)?;
            value.set("results", status.results)?;
            value.set("processed", status.processed)?;
            value.set("bytes", status.bytes)?;
            value.set(
                "phase",
                match status.phase {
                    JobPhase::Preparing => "preparing",
                    JobPhase::Reading => "reading",
                    JobPhase::Working => "working",
                    JobPhase::Publishing => "publishing",
                    JobPhase::Cleanup => "cleanup",
                    JobPhase::Complete => "complete",
                },
            )?;
            if let Some(error) = status.error {
                value.set("error", output::error(lua, &error)?)?;
            }
            if let Some(cleanup) = status.cleanup {
                match cleanup {
                    Ok(()) => value.set("cleanup", "success")?,
                    Err(error) => value.set("cleanup", output::error(lua, &error)?)?,
                }
            }
            if let Some(request) = status.confirmation {
                let confirmation = lua.create_table()?;
                confirmation.set("token", request.token.to_string())?;
                confirmation.set("item", format!("i{}", request.item.0))?;
                confirmation.set("node", request.node.map(output::node))?;
                confirmation.set(
                    "kind",
                    if request.prepare_move {
                        "prepare_move"
                    } else {
                        "overwrite"
                    },
                )?;
                confirmation.set("source", paths::output(lua, &request.source)?)?;
                confirmation.set("target", paths::output(lua, &request.target)?)?;
                confirmation.set("source_label", paths::label(&request.source))?;
                confirmation.set("target_label", paths::label(&request.target))?;
                value.set("confirmation", confirmation)?;
            }
            Ok(Some(value))
        });
        methods.add_method("results", |lua, this, (first, last): (usize, usize)| {
            let first = first
                .checked_sub(1)
                .ok_or_else(|| LuaError::external("results use 1-based ranges"))?;
            let results = this.0.results(first, last).map_err(LuaError::external)?;
            let values = lua.create_table()?;
            for (index, result) in results.iter().enumerate() {
                let value = lua.create_table()?;
                value.set("item", format!("i{}", result.item.0))?;
                value.set("node", result.node.map(output::node))?;
                let source = result.source();
                let target = result.target();
                value.set("source", paths::output(lua, &source)?)?;
                value.set("source_label", paths::label(&source))?;
                if let Some(target) = &target {
                    value.set("target", paths::output(lua, target)?)?;
                    value.set("target_label", paths::label(&target))?;
                }
                if let Some(source) = result.source_physical() {
                    value.set("source_physical", paths::output(lua, source)?)?;
                }
                if let Some(target) = result.target_physical() {
                    value.set("target_physical", paths::output(lua, target)?)?;
                }
                value.set("status", status(result.status))?;
                if let Some(error) = result.error() {
                    value.set("error", output::error(lua, error)?)?;
                }
                if let Some(error) = result.sync_error() {
                    value.set("sync_error", output::error(lua, error)?)?;
                }
                value.set("error_kind", result.error_kind())?;
                value.set("os_code", result.os_code())?;
                values.set(index + 1, value)?;
            }
            Ok(values)
        });
        methods.add_method("confirm", |_, this, (token, overwrite): (String, bool)| {
            this.0
                .confirm(token.parse().map_err(LuaError::external)?, overwrite)
                .map_err(LuaError::external)
        });
        methods.add_method("cancel", |_, this, ()| {
            this.0.cancel();
            Ok(())
        });
    }
}

pub(crate) fn operation_plan(value: LuaTable) -> LuaResult<OperationPlan> {
    let kind: String = value.raw_get("kind")?;
    let kind = match kind.as_str() {
        "copy" => OperationKind::Copy,
        "move" => OperationKind::Move,
        "delete" => OperationKind::Delete,
        "trash" => OperationKind::Trash,
        _ => return Err(LuaError::external("unknown file operation")),
    };
    let source: LuaAnyUserData = value.raw_get("source")?;
    let source = source.borrow::<LuaSource>()?.0.clone();
    let nodes: LuaValue = value.raw_get("nodes")?;
    let nodes = if let LuaValue::UserData(value) = nodes {
        value.borrow::<LuaIds>()?.0.clone()
    } else {
        input::ids(nodes).map_err(LuaError::external)?
    };
    let target: Option<LuaAnyUserData> = value.raw_get("target")?;
    let target = target
        .map(|target| {
            target
                .borrow::<LuaResource>()
                .map(|target| target.0.clone())
        })
        .transpose()?;
    let name: Option<LuaString> = value.raw_get("name")?;
    let name = name
        .map(|name| path(name).map(|path| path.into_os_string()))
        .transpose()?;
    let task: Option<LuaTable> = value.raw_get("task")?;
    let task = task
        .map(|task| -> LuaResult<_> {
            let state: LuaAnyUserData = task.raw_get("state")?;
            Ok(TaskContext {
                state: state.borrow::<LuaState>()?.0.clone(),
                lock: LockToken(
                    input::token(task.raw_get("lock")?, 'l').map_err(LuaError::external)?,
                ),
                cleanup: CleanupToken(
                    input::token(task.raw_get("cleanup")?, 'c').map_err(LuaError::external)?,
                ),
            })
        })
        .transpose()?;
    Ok(OperationPlan {
        kind,
        source,
        nodes,
        target,
        name,
        task,
        prepare_move: value
            .raw_get::<Option<bool>>("prepare_move")?
            .unwrap_or(false),
    })
}

pub(crate) fn create_plan(value: LuaTable) -> LuaResult<CreatePlan> {
    let target: LuaAnyUserData = value.raw_get("target")?;
    let target = target.borrow::<LuaResource>()?.0.clone();
    Ok(CreatePlan {
        target,
        path: path(value.raw_get("path")?)?,
        directory: value.raw_get("directory")?,
    })
}

pub(super) fn methods<M: LuaUserDataMethods<LuaFiletree>>(methods: &mut M) {
    methods.add_method("start_operation", |_, this, value: LuaTable| {
        this.0
            .start_operation(operation_plan(value)?)
            .map(LuaJob)
            .map_err(LuaError::external)
    });
    methods.add_method("start_create", |_, this, value: LuaTable| {
        this.0
            .start_create(create_plan(value)?)
            .map(LuaJob)
            .map_err(LuaError::external)
    });
}
