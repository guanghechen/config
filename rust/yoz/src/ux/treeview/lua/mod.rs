//! Owned input decoding and bounded immutable reads. No Lua value crosses to the worker.
pub(crate) mod input;
pub(crate) mod output;
mod upload;

use super::*;
use mlua::prelude::*;
use std::sync::Arc;
use std::time::{Duration, Instant};

pub(crate) struct LuaData(pub(crate) DataHandle);
pub(crate) struct LuaState(pub(crate) StateHandle);
struct LuaProvider(ProviderHandle);
struct LuaQuery(QueryHandle);
struct LuaView(Option<ViewHandle>);
pub(crate) struct LuaFrame(pub(crate) Arc<Snapshot>);
pub(crate) struct LuaSource(pub(crate) Arc<Source>);
pub(crate) struct LuaIds(pub(crate) Arc<[NodeId]>);
struct LuaRead(ReadToken);
struct LuaQueryToken(QueryToken);
struct LuaPlan(Arc<RenderPlan>);
pub(crate) struct LuaTicket {
    pub(crate) ticket: Ticket,
    pub(crate) _data: DataHandle,
}

fn ticket(data: &DataHandle, action: Result<Action>) -> LuaTicket {
    LuaTicket {
        ticket: match action {
            Ok(action) => data.submit(action),
            Err(error) => Ticket::ready(error),
        },
        _data: data.clone(),
    }
}

fn state_ticket(state: &StateHandle, action: Result<Action>) -> LuaTicket {
    LuaTicket {
        ticket: match action {
            Ok(action) => state.submit(action),
            Err(error) => Ticket::ready(error),
        },
        _data: state.data().clone(),
    }
}

fn range(
    first: LuaValue,
    last: LuaValue,
    length: usize,
    limit: usize,
) -> LuaResult<(usize, usize)> {
    let first = input::integer(first).map_err(LuaError::external)?;
    let last = input::integer(last).map_err(LuaError::external)?;
    if first == 0 || first - 1 > last || last > length || last - (first - 1) > limit {
        return Err(LuaError::external("invalid or oversized 1-based range"));
    }
    Ok((first - 1, last))
}

impl LuaUserData for LuaTicket {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("poll", |lua, this, ()| match this.ticket.poll() {
            Some(outcome) => Ok((true, output::outcome(lua, outcome)?)),
            None => Ok((false, LuaValue::Nil)),
        });
    }
}
impl LuaUserData for LuaRead {}
impl LuaUserData for LuaQueryToken {}

impl LuaUserData for LuaIds {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("len", |_, this, ()| Ok(this.0.len()));
        methods.add_meta_method(LuaMetaMethod::Len, |_, this, ()| Ok(this.0.len()));
        methods.add_method("get", |_, this, at: LuaValue| {
            let at = input::integer(at).map_err(LuaError::external)?;
            Ok(at
                .checked_sub(1)
                .and_then(|at| this.0.get(at))
                .copied()
                .map(output::node))
        });
        methods.add_method("slice", |lua, this, (first, last): (LuaValue, LuaValue)| {
            let (first, last) = range(first, last, this.0.len(), 1024)?;
            lua.create_sequence_from(this.0[first..last].iter().copied().map(output::node))
        });
    }
}

impl LuaUserData for LuaSource {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("query_result", |lua, this, scope: LuaValue| {
            let scope = input::scope(scope).map_err(LuaError::external)?;
            this.0
                .query_results
                .get(&scope)
                .map(|origin| output::query_result(lua, scope, origin))
                .transpose()
        });
        methods.add_method("revision", |_, this, ()| {
            Ok(output::token('r', this.0.revision().value()))
        });
        methods.add_method("same_content", |_, this, other: LuaAnyUserData| {
            let other = other.borrow::<LuaSource>()?;
            Ok(this.0.same_content(&other.0))
        });
        methods.add_method("len", |_, this, ()| Ok(this.0.len()));
        methods.add_method("id", |_, this, key: LuaValue| {
            Ok(this
                .0
                .id(&input::string(key).map_err(LuaError::external)?)
                .map(output::node))
        });
        methods.add_method("node", |lua, this, id: LuaValue| {
            output::detail(lua, &this.0, input::node(id).map_err(LuaError::external)?)
        });
        methods.add_method(
            "children",
            |lua, this, (id, first, last): (LuaValue, LuaValue, LuaValue)| {
                let id = match id {
                    LuaValue::Nil => None,
                    value => Some(input::node(value).map_err(LuaError::external)?),
                };
                let children = this.0.child_sequence(id).map_err(LuaError::external)?;
                let (first, last) = range(first, last, children.len(), 1024)?;
                lua.create_sequence_from(
                    children
                        .iter_from(first)
                        .take(last - first)
                        .copied()
                        .map(output::node),
                )
            },
        );
    }
}

impl LuaUserData for LuaFrame {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("header", |lua, this, ()| output::header(lua, &this.0));
        methods.add_method("id", |_, this, ()| Ok(output::token('f', this.0.id)));
        methods.add_method("node_at", |_, this, row: LuaValue| {
            let row = input::integer(row).map_err(LuaError::external)?;
            Ok(row
                .checked_sub(1)
                .and_then(|row| this.0.row(row))
                .map(|row| output::node(row.id)))
        });
        methods.add_method("position", |_, this, id: LuaValue| {
            Ok(this
                .0
                .position(input::node(id).map_err(LuaError::external)?)
                .map(|row| row + 1))
        });
        methods.add_method(
            "navigate",
            |_, this, (row, direction): (LuaValue, LuaValue)| {
                let row = input::integer(row).map_err(LuaError::external)?;
                let direction = input::direction(direction).map_err(LuaError::external)?;
                Ok(row
                    .checked_sub(1)
                    .and_then(|row| this.0.navigate(row, direction))
                    .map(|row| row + 1))
            },
        );
        methods.add_method("rows", |lua, this, (first, last): (LuaValue, LuaValue)| {
            let (first, last) = range(first, last, this.0.len(), 1024)?;
            output::rows(lua, &this.0, first, last)
        });
        methods.add_method("node", |lua, this, id: LuaValue| {
            output::detail(
                lua,
                this.0.source(),
                input::node(id).map_err(LuaError::external)?,
            )
        });
        methods.add_method("source", |_, this, ()| Ok(LuaSource(this.0.source.clone())));
    }
}

impl LuaUserData for LuaData {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("acknowledge_publication", |_, this, revision: LuaValue| {
            this.0
                .acknowledge_publication(input::revision(revision).map_err(LuaError::external)?);
            Ok(())
        });
        methods.add_method(
            "begin_import",
            |_, this, (scope, base): (LuaValue, LuaValue)| {
                upload::Upload::new(
                    this.0.clone(),
                    None,
                    input::scope(scope).map_err(LuaError::external)?,
                    input::revision(base).map_err(LuaError::external)?,
                )
                .map_err(LuaError::external)
            },
        );
        methods.add_method("source", |_, this, ()| Ok(LuaSource(this.0.source())));
        methods.add_method("batch", |_, this, value: LuaValue| {
            Ok(ticket(&this.0, input::batch(value).map(Action::Batch)))
        });
        methods.add_method(
            "task_batch",
            |_, this, (value, token): (LuaValue, LuaValue)| {
                Ok(ticket(
                    &this.0,
                    (|| {
                        Ok(Action::TaskBatch(
                            input::batch(value)?,
                            TaskUpdateToken(input::token(token, 'u')?),
                        ))
                    })(),
                ))
            },
        );
        methods.add_method("import", |_, this, value: LuaValue| {
            Ok(ticket(
                &this.0,
                (|| {
                    let value = input::table(value)?;
                    Ok(Action::Import(Import {
                        base_revision: input::revision(input::get(&value, "base_revision")?)?,
                        scope: input::scope(input::get(&value, "scope")?)?,
                        records: input::records(input::get(&value, "records")?)?,
                    }))
                })(),
            ))
        });
        methods.add_method(
            "create_state",
            |_, this, (root, display): (LuaValue, LuaValue)| {
                Ok(ticket(
                    &this.0,
                    (|| {
                        Ok(Action::CreateState(
                            input::root(root)?,
                            input::display(display)?,
                        ))
                    })(),
                ))
            },
        );
        methods.add_method("create_provider", |_, this, scope: LuaValue| {
            Ok(ticket(
                &this.0,
                input::scope(scope).map(Action::CreateProvider),
            ))
        });
        methods.add_method(
            "request_children",
            |_, this, (ids, retry): (LuaValue, LuaValue)| {
                Ok(ticket(
                    &this.0,
                    (|| {
                        Ok(Action::RequestChildren(
                            input::ids(ids)?.to_vec(),
                            if matches!(retry, LuaValue::Nil) {
                                false
                            } else {
                                input::boolean(retry)?
                            },
                        ))
                    })(),
                ))
            },
        );
        methods.add_method("events", |lua, this, ()| {
            let (values, pending_deadlines) = this.0.poll_events();
            let output = lua.create_table_with_capacity(values.len(), 0)?;
            for (index, value) in values.iter().enumerate() {
                output.raw_set(index + 1, output::effect(lua, value)?)?;
            }
            Ok((output, pending_deadlines))
        });
        methods.add_method(
            "children_page",
            |_, this, (read, sequence, rows, done): (LuaValue, LuaValue, LuaValue, LuaValue)| {
                let action = (|| {
                    let LuaValue::UserData(read) = read else {
                        return Err(Error::invalid("expected a children token"));
                    };
                    let read = read.borrow::<LuaRead>().map_err(input::invalid)?.0;
                    let sequence = input::token(sequence, 'r')?;
                    Ok(match (input::records(rows), input::boolean(done)) {
                        (Ok(rows), Ok(done)) => Action::ChildrenPage(read, sequence, rows, done),
                        (Err(error), _) | (_, Err(error)) => {
                            Action::ChildrenFailed(read, sequence, error)
                        }
                    })
                })();
                Ok(ticket(&this.0, action))
            },
        );
        methods.add_method(
            "children_failed",
            |_, this, (read, sequence, error): (LuaAnyUserData, LuaValue, LuaValue)| {
                Ok(ticket(
                    &this.0,
                    (|| {
                        Ok(Action::ChildrenFailed(
                            read.borrow::<LuaRead>().map_err(input::invalid)?.0,
                            input::token(sequence, 'r')?,
                            input::error(error).unwrap_or_else(|error| error),
                        ))
                    })(),
                ))
            },
        );
        methods.add_method("children_cancelled", |_, this, read: LuaAnyUserData| {
            Ok(ticket(
                &this.0,
                read.borrow::<LuaRead>()
                    .map(|token| Action::ChildrenCancelled(token.0))
                    .map_err(input::invalid),
            ))
        });
        methods.add_method(
            "query_page",
            |_, this, (query, sequence, rows, done): (LuaValue, LuaValue, LuaValue, LuaValue)| {
                Ok(ticket(
                    &this.0,
                    (|| {
                        let LuaValue::UserData(query) = query else {
                            return Err(Error::invalid("expected a query token"));
                        };
                        let query = query.borrow::<LuaQueryToken>().map_err(input::invalid)?.0;
                        let sequence = input::token(sequence, 'r')?;
                        Ok(match (input::records(rows), input::boolean(done)) {
                            (Ok(rows), Ok(done)) => Action::QueryPage(query, sequence, rows, done),
                            (Err(error), _) | (_, Err(error)) => {
                                Action::QueryFailed(query, sequence, error)
                            }
                        })
                    })(),
                ))
            },
        );
        methods.add_method(
            "query_failed",
            |_, this, (query, sequence, error): (LuaAnyUserData, LuaValue, LuaValue)| {
                Ok(ticket(
                    &this.0,
                    (|| {
                        Ok(Action::QueryFailed(
                            query.borrow::<LuaQueryToken>().map_err(input::invalid)?.0,
                            input::token(sequence, 'r')?,
                            input::error(error).unwrap_or_else(|error| error),
                        ))
                    })(),
                ))
            },
        );
        methods.add_method("query_cancelled", |_, this, query: LuaAnyUserData| {
            Ok(ticket(
                &this.0,
                query
                    .borrow::<LuaQueryToken>()
                    .map(|token| Action::QueryCancelled(token.0))
                    .map_err(input::invalid),
            ))
        });
        methods.add_method("queue_depth", |_, this, ()| Ok(this.0.queue_depth()));
        methods.add_method("is_disposed", |_, this, ()| Ok(this.0.is_disposed()));
    }
}

impl LuaUserData for LuaState {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method(
            "retarget_plan",
            |_, this, (plan, minimum): (LuaAnyUserData, LuaValue)| {
                let plan = plan.borrow::<LuaPlan>()?;
                let target = this.0.snapshot().map_err(LuaError::external)?;
                let minimum = match minimum {
                    LuaValue::Nil => None,
                    value => Some(input::revision(value).map_err(LuaError::external)?),
                };
                if !this.0.applicable(&target, minimum) {
                    return Ok(None);
                }
                Ok(plan.0.retarget(target).map(|plan| LuaPlan(Arc::new(plan))))
            },
        );
        methods.add_method("refresh", |_, this, ()| {
            Ok(state_ticket(&this.0, Ok(Action::Refresh(this.0.id()))))
        });
        methods.add_method("id", |_, this, ()| Ok(output::token('s', this.0.id())));
        methods.add_method(
            "applicable",
            |_, this, (frame, minimum): (LuaValue, LuaValue)| {
                let frame = input::frame(frame).map_err(LuaError::external)?;
                let minimum = match minimum {
                    LuaValue::Nil => None,
                    value => Some(input::revision(value).map_err(LuaError::external)?),
                };
                Ok(this.0.applicable(&frame, minimum))
            },
        );
        methods.add_method("snapshot", |_, this, ()| {
            this.0.snapshot().map(LuaFrame).map_err(LuaError::external)
        });
        methods.add_method("status", |lua, this, ()| {
            let status = this.0.status().map_err(LuaError::external)?;
            let result = lua.create_table()?;
            result.set("revisions", output::revisions(lua, status.revisions)?)?;
            result.set("locked", status.locked)?;
            result.set("selection_purpose", status.selection_purpose.as_deref())?;
            result.set(
                "projection_error",
                status
                    .projection_error
                    .as_ref()
                    .map(|error| output::error(lua, error))
                    .transpose()?,
            )?;
            Ok(result)
        });
        methods.add_method("display", |lua, this, ()| {
            let status = this.0.status().map_err(LuaError::external)?;
            Ok((
                output::display(lua, &status.display)?,
                status
                    .revisions
                    .state
                    .map(|revision| output::token('r', revision.value())),
            ))
        });
        methods.add_method(
            "dispatch",
            |_, this, (command, context): (LuaValue, LuaValue)| {
                Ok(state_ticket(
                    &this.0,
                    (|| {
                        Ok(Action::Dispatch(
                            this.0.id(),
                            input::command(command)?,
                            input::context(context)?,
                        ))
                    })(),
                ))
            },
        );
        methods.add_method(
            "lock_selection",
            |_, this, (selection, deadline): (LuaValue, LuaValue)| {
                Ok(state_ticket(
                    &this.0,
                    (|| {
                        let deadline = if matches!(deadline, LuaValue::Nil) {
                            None
                        } else {
                            Some(
                                Instant::now()
                                    .checked_add(Duration::from_millis(
                                        input::integer(deadline)? as u64
                                    ))
                                    .ok_or_else(|| Error::limit("deadline overflow"))?,
                            )
                        };
                        Ok(Action::Lock(
                            this.0.id(),
                            input::revision(selection)?,
                            deadline,
                        ))
                    })(),
                ))
            },
        );
        methods.add_method("unlock_selection", |_, this, token: LuaValue| {
            Ok(state_ticket(
                &this.0,
                input::token(token, 'l').map(|token| Action::Unlock(this.0.id(), LockToken(token))),
            ))
        });
        methods.add_method(
            "authorize_update",
            |_, this, (lock, cleanup, changes): (LuaValue, LuaValue, LuaValue)| {
                Ok(state_ticket(
                    &this.0,
                    (|| {
                        let changes = input::table(changes)?;
                        if changes.raw_len() > 200_000 {
                            return Err(Error::limit("task change capacity exceeded"));
                        }
                        let mut items = Vec::new();
                        for index in 1..=changes.raw_len() {
                            let item: LuaTable = changes.raw_get(index).map_err(input::invalid)?;
                            let node = input::node(input::get(&item, "node")?)?;
                            items.push(match input::string(input::get(&item, "kind")?)?.as_ref() {
                                "remove" => ExpectedChange::Remove { node },
                                "reparent" => ExpectedChange::Reparent {
                                    node,
                                    parent: match input::get(&item, "parent")? {
                                        LuaValue::Nil => None,
                                        value => Some(input::node(value)?),
                                    },
                                },
                                _ => return Err(Error::invalid("unknown expected task change")),
                            });
                        }
                        Ok(Action::Authorize(
                            this.0.id(),
                            LockToken(input::token(lock, 'l')?),
                            CleanupToken(input::token(cleanup, 'c')?),
                            items.into(),
                        ))
                    })(),
                ))
            },
        );
        methods.add_method("attach", |_, this, ()| {
            this.0
                .attach()
                .map(|view| LuaView(Some(view)))
                .map_err(LuaError::external)
        });
    }
}

impl LuaUserData for LuaProvider {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("begin_import", |_, this, base: LuaValue| {
            upload::Upload::new(
                this.0.data().clone(),
                Some(this.0.clone()),
                DataScope::Forest,
                input::revision(base).map_err(LuaError::external)?,
            )
            .map_err(LuaError::external)
        });
        methods.add_method("id", |_, this, ()| Ok(output::token('p', this.0.id().0)));
        methods.add_method(
            "import",
            |_, this, (revision, rows): (LuaValue, LuaValue)| {
                Ok(ticket(
                    this.0.data(),
                    (|| {
                        Ok(Action::ProviderImport(
                            this.0.id(),
                            input::revision(revision)?,
                            input::records(rows)?,
                        ))
                    })(),
                ))
            },
        );
        methods.add_method("batch", |_, this, batch: LuaValue| {
            Ok(ticket(
                this.0.data(),
                input::batch(batch).map(|batch| Action::ProviderBatch(this.0.id(), batch)),
            ))
        });
        methods.add_method("create_query", |_, this, ()| {
            Ok(ticket(
                this.0.data(),
                Ok(Action::CreateQuery(this.0.clone())),
            ))
        });
    }
}

impl LuaUserData for LuaQuery {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("id", |_, this, ()| Ok(output::token('q', this.0.id().0)));
        methods.add_method("info", |lua, this, ()| {
            output::query(lua, &this.0.info().map_err(LuaError::external)?)
        });
        methods.add_method("start", |_, this, input: LuaValue| {
            Ok(ticket(
                this.0.data(),
                input::query(input).map(|input| Action::AcceptQuery(this.0.id(), input)),
            ))
        });
        methods.add_method("cancel", |_, this, ()| {
            Ok(ticket(this.0.data(), Ok(Action::CancelQuery(this.0.id()))))
        });
    }
}

impl LuaUserData for LuaView {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("id", |_, this, ()| {
            Ok(this.0.as_ref().map(|view| output::token('v', view.id())))
        });
        methods.add_method_mut("detach", |_, this, ()| {
            this.0.take();
            Ok(())
        });
        methods.add_method("snapshot", |_, this, ()| {
            this.0
                .as_ref()
                .ok_or_else(|| LuaError::external("view detached"))?
                .snapshot()
                .map(LuaFrame)
                .map_err(LuaError::external)
        });
        methods.add_method(
            "plan",
            |_,
             this,
             (base, target, context, old_context, reset): (
                LuaValue,
                LuaValue,
                LuaValue,
                LuaValue,
                LuaValue,
            )| {
                let view = this
                    .0
                    .as_ref()
                    .ok_or_else(|| LuaError::external("view detached"))?;
                Ok(state_ticket(
                    view.state(),
                    (|| {
                        Ok(Action::Plan {
                            base: match base {
                                LuaValue::Nil => None,
                                value => Some(input::frame(value)?),
                            },
                            target: input::frame(target)?,
                            context: input::render_context(context)?,
                            old_context: match old_context {
                                LuaValue::Nil => None,
                                value => Some(input::render_context(value)?),
                            },
                            reset: input::boolean(reset)?,
                        })
                    })(),
                ))
            },
        );
    }
}

impl LuaUserData for LuaPlan {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("target", |_, this, ()| Ok(LuaFrame(this.0.target.clone())));
        methods.add_method("header", |lua, this, ()| {
            let result = lua.create_table()?;
            result.set(
                "mode",
                match this.0.mode {
                    PlanMode::Swap => "Swap",
                    PlanMode::Delta => "Delta",
                    PlanMode::Reset => "Reset",
                },
            )?;
            result.set(
                "base",
                this.0.base.as_ref().map(|base| output::token('f', base.id)),
            )?;
            result.set("target", output::token('f', this.0.target.id))?;
            result.set("row_count", this.0.target.len())?;
            result.set("reason", this.0.reason)?;
            result.set("text_bytes", this.0.work.text_bytes)?;
            result.set("written_rows", this.0.work.written_rows)?;
            result.set("compared_rows", this.0.work.compared_rows)?;
            result.set("shared_rows", this.0.work.shared_rows)?;
            let splices = lua.create_table()?;
            for (index, splice) in this.0.splices.iter().enumerate() {
                splices.raw_set(
                    index + 1,
                    lua.create_sequence_from([
                        splice.old_start,
                        splice.old_end,
                        splice.target_start,
                        splice.target_end,
                    ])?,
                )?;
            }
            result.set("splices", splices)?;
            Ok(result)
        });
        methods.add_method(
            "lines",
            |lua, this, (start, end, bytes): (LuaValue, LuaValue, LuaValue)| {
                let start = input::integer(start).map_err(LuaError::external)?;
                let end = input::integer(end).map_err(LuaError::external)?;
                let bytes = input::integer(bytes).map_err(LuaError::external)?;
                let average = this
                    .0
                    .work
                    .text_bytes
                    .checked_div(this.0.work.written_rows)
                    .unwrap_or(1)
                    .max(1);
                let lines = lua.create_table_with_capacity(
                    end.saturating_sub(start).min(512).min(bytes / average),
                    0,
                )?;
                let mut index = 0;
                let next = this
                    .0
                    .write_lines(start, end, bytes, |text| {
                        index += 1;
                        lines.raw_set(index, text).map_err(input::invalid)
                    })
                    .map_err(LuaError::external)?;
                Ok((lines, next))
            },
        );
    }
}

pub(crate) fn module(lua: &Lua) -> LuaResult<LuaTable> {
    let module = lua.create_table()?;
    module.set(
        "new_data",
        lua.create_function(|_, value: LuaValue| {
            let mut limits = Limits::default();
            if !matches!(value, LuaValue::Nil) {
                let value = input::table(value).map_err(LuaError::external)?;
                for (key, field) in [
                    ("memory_bytes", &mut limits.memory_bytes),
                    ("nodes", &mut limits.nodes),
                    ("payload_bytes", &mut limits.payload_bytes),
                    ("states", &mut limits.states),
                    ("views", &mut limits.views),
                    ("queued_actions", &mut limits.queued_actions),
                    ("concurrent_reads", &mut limits.concurrent_reads),
                    ("queued_reads", &mut limits.queued_reads),
                    ("batch_nodes", &mut limits.batch_nodes),
                    ("batch_bytes", &mut limits.batch_bytes),
                ] {
                    let option: LuaValue = value.raw_get(key)?;
                    if !matches!(option, LuaValue::Nil) {
                        *field = input::integer(option).map_err(LuaError::external)?;
                    }
                }
            }
            DataHandle::new(limits)
                .map(LuaData)
                .map_err(LuaError::external)
        })?,
    )?;
    Ok(module)
}
