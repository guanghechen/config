use super::model::*;
use super::projection::{Row, Snapshot};
use std::collections::{BTreeSet, HashMap};
use std::sync::Arc;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct RenderContext {
    pub version: u64,
    pub indent: usize,
    pub slots: usize,
    pub separator: Arc<str>,
}

impl Default for RenderContext {
    fn default() -> Self {
        Self {
            version: 1,
            indent: 2,
            slots: 4,
            separator: "/".into(),
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum PlanMode {
    Swap,
    Delta,
    Reset,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct Splice {
    pub old_start: usize,
    pub old_end: usize,
    pub target_start: usize,
    pub target_end: usize,
}

#[derive(Clone, Debug, Default)]
pub struct RenderWork {
    pub compared_rows: usize,
    pub shared_rows: usize,
    pub written_rows: usize,
    pub text_bytes: usize,
}

pub struct RenderPlan {
    pub base: Option<Arc<Snapshot>>,
    pub target: Arc<Snapshot>,
    pub context: RenderContext,
    pub mode: PlanMode,
    pub splices: Arc<[Splice]>,
    pub reason: &'static str,
    pub work: RenderWork,
}

fn equal_text(base: &Snapshot, old: &Row, target: &Snapshot, new: &Row) -> bool {
    if old.chain.is_none() && new.chain.is_none() {
        return old.depth == new.depth && old.label == new.label;
    }
    if base.source.nodes.same_version(&target.source.nodes) && old.folded_ids() == new.folded_ids()
    {
        return old.depth == new.depth;
    }
    old.depth == new.depth
        && old.folded_ids().len() == new.folded_ids().len()
        && old.folded_ids().iter().zip(new.folded_ids()).all(|(a, b)| {
            base.source()
                .node(*a)
                .zip(target.source().node(*b))
                .is_some_and(|(a, b)| a.data.label == b.data.label)
        })
}

fn increasing(points: &[(usize, usize, usize)]) -> Vec<(usize, usize, usize)> {
    let mut tails = Vec::<usize>::new();
    let mut links = vec![None; points.len()];
    for (index, point) in points.iter().enumerate() {
        let at = tails.partition_point(|&tail| points[tail].0 < point.0);
        links[index] = at.checked_sub(1).map(|previous| tails[previous]);
        if at == tails.len() {
            tails.push(index);
        } else {
            tails[at] = index;
        }
    }
    let mut chain = Vec::new();
    let mut next = tails.last().copied();
    while let Some(index) = next {
        chain.push(points[index]);
        next = links[index];
    }
    chain.reverse();
    chain
}

fn gap(
    base: &Snapshot,
    target: &Snapshot,
    span: Splice,
    edits: &mut Vec<Splice>,
    work: &mut RenderWork,
) {
    if span.old_start == span.old_end && span.target_start == span.target_end {
        return;
    }
    if span.old_start == span.old_end || span.target_start == span.target_end {
        edits.push(span);
        return;
    }
    let mut anchors = Vec::new();
    let positions: Option<HashMap<_, _>> = (span.old_end - span.old_start > 1024
        && span.target_end - span.target_start > 1024)
        .then(|| {
            base.rows
                .iter_from(span.old_start)
                .take(span.old_end - span.old_start)
                .enumerate()
                .map(|(offset, row)| (row.id, (span.old_start + offset, row)))
                .collect()
        });
    for (offset, row) in target
        .rows
        .iter_from(span.target_start)
        .take(span.target_end - span.target_start)
        .enumerate()
    {
        work.compared_rows += 1;
        let previous = match &positions {
            Some(positions) => positions.get(&row.id).copied(),
            None => base
                .position(row.id)
                .and_then(|at| base.row(at).map(|row| (at, row))),
        };
        if let Some((at, old)) = previous
            && at >= span.old_start
            && at < span.old_end
            && equal_text(base, old, target, row)
        {
            anchors.push((at, span.target_start + offset, 1));
        }
    }
    let mut old = span.old_start;
    let mut new = span.target_start;
    for (a, b, len) in
        increasing(&anchors)
            .into_iter()
            .chain(std::iter::once((span.old_end, span.target_end, 0)))
    {
        if old != a || new != b {
            edits.push(Splice {
                old_start: old,
                old_end: a,
                target_start: new,
                target_end: b,
            });
        }
        old = a + len;
        new = b + len;
    }
}

fn row_bytes(frame: &Snapshot, row: &Row, context: &RenderContext) -> Result<usize> {
    let mut bytes = (row.depth + usize::from(frame.mode() == Mode::Tree))
        .checked_mul(context.indent)
        .and_then(|bytes| bytes.checked_add(context.slots))
        .ok_or_else(|| Error::limit("render indentation overflow"))?;
    if row.chain.is_none() {
        return bytes
            .checked_add(row.label.len())
            .ok_or_else(|| Error::limit("render text size overflow"));
    }
    for (index, id) in row.folded_ids().iter().enumerate() {
        let node = frame
            .source()
            .node(*id)
            .ok_or_else(|| Error::missing(*id))?;
        bytes = bytes
            .checked_add(node.data.label.len())
            .and_then(|bytes| {
                bytes.checked_add(if index == 0 {
                    0
                } else {
                    context.separator.len()
                })
            })
            .ok_or_else(|| Error::limit("render text size overflow"))?;
    }
    Ok(bytes)
}

impl RenderPlan {
    pub(crate) fn retarget(&self, target: Arc<Snapshot>) -> Option<Self> {
        if self.target.state_id() != target.state_id()
            || self.target.layout_revision != target.layout_revision
            || self.target.text_revision != target.text_revision
        {
            return None;
        }
        Some(Self {
            base: self.base.clone(),
            target,
            context: self.context.clone(),
            mode: self.mode,
            splices: self.splices.clone(),
            reason: self.reason,
            work: self.work.clone(),
        })
    }
    pub fn new(
        base: Option<Arc<Snapshot>>,
        target: Arc<Snapshot>,
        old_context: Option<&RenderContext>,
        context: RenderContext,
        reset: bool,
    ) -> Result<Self> {
        if context.indent > 8
            || context.slots > 16
            || context.separator.len() > 32
            || context
                .separator
                .bytes()
                .any(|byte| matches!(byte, b'\n' | b'\r' | 0))
        {
            return Err(Error::invalid("invalid render context"));
        }
        if base
            .as_ref()
            .is_some_and(|base| base.state_id() != target.state_id())
        {
            return Err(Error::stale("render frames belong to different states"));
        }
        let mut work = RenderWork::default();
        let mut edits = Vec::new();
        let mut mode = PlanMode::Reset;
        let mut reason = "initial, format change or explicit resync";
        if let Some(base) = base.as_ref().filter(|base| {
            !reset
                && old_context == Some(&context)
                && base.mode() == target.mode()
                && base.is_empty() == target.is_empty()
        }) {
            let flat_replacement = target.len() > 1024
                && target.previous == Some(base.id)
                && target.root() == base.root()
                && base.source.nodes.same_version(&target.source.nodes)
                && target.source.len() == target.len() + 1
                && matches!(target.root(), Root::ChildrenOf(root) if target.source.node(*root).is_some_and(|node| node.child_count() == target.len()))
                && target.replaced_rows.saturating_sub(2) * 10 > target.len() * 7;
            /* Flat unchanged source differs only in row order/membership and two end connectors.
            The projection already proved the normal 70% Reset threshold for this exact base. */
            if flat_replacement {
                reason = "projection proved broad flat replacement";
            } else {
                mode = PlanMode::Delta;
                reason = "shared blocks and ordered row anchors";
                let spans = base.rows.shared_spans(&target.rows);
                let same_layout = base.layout_revision == target.layout_revision;
                let shared = if same_layout {
                    work.shared_rows = spans.iter().map(|(_, _, len)| len).sum();
                    Vec::new()
                } else {
                    increasing(&spans)
                };
                let mut old = 0;
                let mut new = 0;
                for (a, b, len) in
                    shared
                        .into_iter()
                        .chain(std::iter::once((base.len(), target.len(), 0)))
                {
                    if !same_layout {
                        gap(
                            base,
                            &target,
                            Splice {
                                old_start: old,
                                old_end: a,
                                target_start: new,
                                target_end: b,
                            },
                            &mut edits,
                            &mut work,
                        );
                    }
                    work.shared_rows += len;
                    old = a + len;
                    new = b + len;
                }
                let changed = if target.previous == Some(base.id) {
                    target.text_nodes.to_vec()
                } else {
                    base.source.nodes.changed_keys(&target.source.nodes)
                };
                let mut text_rows = BTreeSet::new();
                for id in changed {
                    if let Some(at) = target.position(id) {
                        text_rows.insert(at);
                    }
                }
                for at in text_rows {
                    if edits
                        .iter()
                        .any(|edit| at >= edit.target_start && at < edit.target_end)
                    {
                        continue;
                    }
                    let row = target.row(at).expect("changed target row");
                    if let Some(old_at) = base.position(row.id) {
                        work.compared_rows += 1;
                        if !equal_text(base, base.row(old_at).expect("base row"), &target, row) {
                            edits.push(Splice {
                                old_start: old_at,
                                old_end: old_at + 1,
                                target_start: at,
                                target_end: at + 1,
                            });
                        }
                    }
                }
                edits.sort_unstable_by_key(|edit| (edit.old_start, edit.target_start));
                let mut merged = Vec::<Splice>::new();
                for edit in edits {
                    if let Some(previous) = merged.last_mut()
                        && previous.old_end <= edit.old_start
                        && previous.target_end <= edit.target_start
                        && edit.old_start - previous.old_end
                            == edit.target_start - previous.target_end
                        && edit.old_start - previous.old_end <= 2
                    {
                        previous.old_end = edit.old_end;
                        previous.target_end = edit.target_end;
                        continue;
                    }
                    merged.push(edit);
                }
                edits = merged;
                let written: usize = edits
                    .iter()
                    .map(|edit| edit.target_end - edit.target_start)
                    .sum();
                if edits.len() > 128 || (target.len() > 1024 && written * 10 > target.len() * 7) {
                    mode = PlanMode::Reset;
                    reason = "delta call count or replacement coverage";
                } else if edits.is_empty() {
                    mode = PlanMode::Swap;
                    reason = "frame and decorations only";
                }
            }
        }

        if mode == PlanMode::Reset {
            edits = vec![Splice {
                old_start: 0,
                old_end: base.as_ref().map_or(0, |base| base.len()),
                target_start: 0,
                target_end: target.len(),
            }];
        }
        for edit in &edits {
            work.written_rows += edit.target_end - edit.target_start;
            for row in target
                .rows
                .iter_from(edit.target_start)
                .take(edit.target_end - edit.target_start)
            {
                work.text_bytes = work
                    .text_bytes
                    .checked_add(row_bytes(&target, row, &context)?.saturating_add(1))
                    .ok_or_else(|| Error::limit("render staging size overflow"))?;
                if work.text_bytes > 64 * 1024 * 1024 {
                    return Err(Error::limit("render staging exceeds 64 MiB"));
                }
            }
        }
        Ok(Self {
            base,
            target,
            context,
            mode,
            splices: edits.into(),
            reason,
            work,
        })
    }

    pub fn lines(
        &self,
        start: usize,
        end: usize,
        byte_limit: usize,
    ) -> Result<(Vec<String>, usize)> {
        let mut lines = Vec::with_capacity(end.saturating_sub(start).min(512));
        let next = self.write_lines(start, end, byte_limit, |text| {
            lines.push(text.to_owned());
            Ok(())
        })?;
        Ok((lines, next))
    }

    pub(crate) fn write_lines(
        &self,
        start: usize,
        end: usize,
        byte_limit: usize,
        mut write: impl FnMut(&str) -> Result<()>,
    ) -> Result<usize> {
        if start > end || end > self.target.len() || end - start > 512 || byte_limit > 1024 * 1024 {
            return Err(Error::invalid(
                "text reads require at most 512 rows and 1 MiB",
            ));
        }
        let mut text = String::new();
        let mut next = start;
        let mut bytes = 0;
        for row in self.target.rows.iter_from(start).take(end - start) {
            let depth = row.depth + usize::from(self.target.mode() == Mode::Tree);
            let label = if row.chain.is_none() {
                Some(row.label.as_ref())
            } else {
                None
            };
            let size = match label {
                Some(label) => depth
                    .checked_mul(self.context.indent)
                    .and_then(|bytes| bytes.checked_add(self.context.slots))
                    .and_then(|bytes| bytes.checked_add(label.len()))
                    .ok_or_else(|| Error::limit("render text size overflow"))?,
                None => row_bytes(&self.target, row, &self.context)?,
            };
            if size > byte_limit {
                return Err(Error::limit(
                    "one rendered line exceeds the transfer budget",
                ));
            }
            if bytes + size > byte_limit {
                break;
            }
            text.clear();
            text.reserve(size);
            text.extend(std::iter::repeat_n(
                ' ',
                depth * self.context.indent + self.context.slots,
            ));
            if let Some(label) = label {
                text.push_str(label);
            } else {
                for (index, id) in row.folded_ids().iter().enumerate() {
                    if index != 0 {
                        text.push_str(&self.context.separator);
                    }
                    text.push_str(
                        &self
                            .target
                            .source()
                            .node(*id)
                            .expect("frame node")
                            .data
                            .label,
                    );
                }
            }
            bytes += size;
            write(&text)?;
            next += 1;
        }
        Ok(next)
    }
}
