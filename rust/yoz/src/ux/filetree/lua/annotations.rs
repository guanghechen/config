use super::{LuaFiletree, path};
use crate::ux::filetree::{AnnotationKind, AnnotationRows, Request};
use crate::ux::treeview::lua::{LuaFrame, output};
use crate::ux::treeview::{Error, Outcome, Result};
use mlua::prelude::*;
use std::sync::Arc;

enum Pending {
    Input(Request<()>),
    Rows(Request<Arc<AnnotationRows>>),
    Navigation(Request<Option<usize>>),
}

fn revision(value: LuaValue) -> LuaResult<u64> {
    match value {
        LuaValue::String(value) => value.to_str()?.parse::<u64>().map_err(LuaError::external),
        LuaValue::Integer(value) if value >= 0 => Ok(value as u64),
        LuaValue::Number(value)
            if value.is_finite()
                && value >= 0.0
                && value.fract() == 0.0
                && value <= 9_007_199_254_740_991.0 =>
        {
            Ok(value as u64)
        }
        _ => Err(LuaError::external(
            "expected an exact nonnegative input revision",
        )),
    }
}

fn result(lua: &Lua, value: Result<LuaValue>) -> LuaResult<(bool, LuaValue)> {
    Ok((
        true,
        match value {
            Ok(value) => value,
            Err(error) => output::outcome(lua, Outcome::Reply(error.into()))?,
        },
    ))
}

fn rows(lua: &Lua, value: &AnnotationRows) -> LuaResult<LuaValue> {
    let output = lua.create_table()?;
    output.set("revision", value.revision.to_string())?;
    output.set("frame", format!("f{:016x}", value.frame))?;
    output.set("first", value.first + 1)?;
    let rows = lua.create_table_with_capacity(value.rows.len(), 0)?;
    for value in &value.rows {
        let row = lua.create_table()?;
        row.set("diagnostics", lua.create_sequence_from(value.diagnostics)?)?;
        row.set("git", value.git)?;
        row.set("staged", value.staged)?;
        row.set("unstaged", value.unstaged)?;
        rows.raw_push(row)?;
    }
    output.set("rows", rows)?;
    Ok(LuaValue::Table(output))
}

impl LuaUserData for Pending {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("poll", |lua, this, ()| match this {
            Self::Input(request) => match request.poll() {
                None => Ok((false, LuaValue::Nil)),
                Some(value) => result(lua, value.map(|_| LuaValue::Boolean(true))),
            },
            Self::Rows(request) => match request.poll() {
                None => Ok((false, LuaValue::Nil)),
                Some(value) => result(
                    lua,
                    value.and_then(|value| {
                        rows(lua, &value).map_err(|error| Error::invalid(error.to_string()))
                    }),
                ),
            },
            Self::Navigation(request) => match request.poll() {
                None => Ok((false, LuaValue::Nil)),
                Some(value) => result(
                    lua,
                    value.map(|row| LuaValue::Integer(row.map_or(0, |row| row + 1) as i64)),
                ),
            },
        });
    }
}

pub(super) fn methods<M: LuaUserDataMethods<LuaFiletree>>(methods: &mut M) {
    methods.add_method("annotation_revision", |_, this, ()| {
        Ok(this.0.annotation_revision().to_string())
    });
    methods.add_method(
        "set_git",
        |_,
         this,
         (root, version, status, ignored): (
            LuaString,
            LuaValue,
            Option<LuaAnyUserData>,
            Option<LuaAnyUserData>,
        )| {
            Ok(Pending::Input(
                this.0.set_git(
                    path(root)?,
                    revision(version)?,
                    status
                        .as_ref()
                        .map(crate::git::status_snapshot)
                        .transpose()?,
                    ignored
                        .as_ref()
                        .map(crate::git::ignore_snapshot)
                        .transpose()?,
                ),
            ))
        },
    );
    methods.add_method(
        "set_diagnostics",
        |_,
         this,
         (namespace, bufnr, version, location, values): (
            u32,
            u32,
            LuaValue,
            Option<LuaString>,
            LuaTable,
        )| {
            if values.raw_len() != 4 {
                return Err(LuaError::external("expected four diagnostic counts"));
            }
            let mut counts = [0; 4];
            for (index, count) in counts.iter_mut().enumerate() {
                *count = u32::try_from(revision(values.raw_get(index + 1)?)?)
                    .map_err(LuaError::external)?;
            }
            Ok(Pending::Input(this.0.set_diagnostics(
                namespace,
                bufnr,
                revision(version)?,
                location.map(path).transpose()?,
                counts,
            )))
        },
    );
    methods.add_method(
        "annotations",
        |_, this, (frame, first, last): (LuaAnyUserData, usize, usize)| {
            let frame = frame.borrow::<LuaFrame>()?.0.clone();
            let first = first
                .checked_sub(1)
                .ok_or_else(|| LuaError::external("row indices start at one"))?;
            Ok(Pending::Rows(this.0.annotations(frame, first, last)))
        },
    );
    methods.add_method(
        "next_annotation",
        |_, this, (frame, from, kind, forward): (LuaAnyUserData, usize, String, bool)| {
            let frame = frame.borrow::<LuaFrame>()?.0.clone();
            let kind = match kind.as_str() {
                "git" => AnnotationKind::Git,
                "diagnostic" => AnnotationKind::Diagnostic,
                "error" => AnnotationKind::Error,
                "warning" => AnnotationKind::Warning,
                _ => return Err(LuaError::external("invalid annotation navigation kind")),
            };
            Ok(Pending::Navigation(this.0.next_annotation(
                frame,
                from.checked_sub(1),
                kind,
                forward,
            )))
        },
    );
}
