use super::command::{Effect, Reply};
use super::data::Batch;
use super::engine::Engine;
use super::model::*;
use super::provider::{ProviderId, Record, plan_import};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct QueryId(pub(crate) u64);

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct QueryToken {
    pub(crate) data: u64,
    pub(crate) work: u64,
    pub session: QueryId,
    pub generation: u64,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct QueryInput {
    pub pattern: std::sync::Arc<str>,
    pub options: Fields,
}

#[derive(Clone, Debug)]
pub struct QueryInfo {
    pub(crate) _payloads: std::sync::Arc<[std::sync::Arc<super::memory::Payload>]>,
    pub session: QueryId,
    pub provider: ProviderId,
    pub generation: u64,
    pub result_generation: Option<u64>,
    pub input: QueryInput,
    pub load_state: LoadState,
    pub completeness: Completeness,
    pub error: Option<Error>,
}

#[derive(Clone, Debug)]
pub struct QueryResult {
    pub(crate) _payloads: std::sync::Arc<[std::sync::Arc<super::memory::Payload>]>,
    pub session: QueryId,
    pub generation: u64,
    pub input: QueryInput,
    pub completeness: Completeness,
}

#[derive(Clone)]
pub(crate) struct Query {
    pub info: QueryInfo,
    pub accepting: bool,
    pub pending: bool,
    pub next_sequence: u64,
}

#[derive(Clone)]
pub(crate) struct QueryWork {
    pub token: QueryToken,
    pub cancelled: bool,
}

impl Engine {
    pub(crate) fn query_for_slot(&self, node: NodeId) -> Option<&Query> {
        self.queries.values().find(|query| {
            self.providers
                .get(&query.info.provider.0)
                .is_some_and(|provider| match provider.scope {
                    super::DataScope::Forest => self.source.contains(node),
                    super::DataScope::Descendants(root) => self.source.within(root, node),
                    super::DataScope::Children(root) => root == node,
                })
        })
    }

    pub fn create_query(&mut self, provider: ProviderId) -> Result<QueryId> {
        self.provider_scope(provider)?;
        if self
            .queries
            .values()
            .any(|query| query.info.provider == provider)
        {
            return Err(Error::invalid("provider scope already has a query session"));
        }
        let id = QueryId(identity()?);
        self.queries.insert(
            id.0,
            Query {
                info: QueryInfo {
                    _payloads: std::sync::Arc::new([]),
                    session: id,
                    provider,
                    generation: 0,
                    result_generation: None,
                    input: QueryInput::default(),
                    load_state: LoadState::Idle,
                    completeness: Completeness::Unknown,
                    error: None,
                },
                accepting: false,
                pending: false,
                next_sequence: 1,
            },
        );
        self.query_changed()?;
        Ok(id)
    }

    pub fn query_info(&self, session: QueryId) -> Result<QueryInfo> {
        self.queries
            .get(&session.0)
            .map(|query| query.info.clone())
            .ok_or_else(|| Error::new(ErrorCode::Disposed, "query session released"))
    }

    fn query_changed(&mut self) -> Result<()> {
        self.commit = self.commit.next()?;
        for entry in self.states.values_mut() {
            entry.dirty.pending = true;
        }
        Ok(())
    }

    pub fn accept_query(&mut self, session: QueryId, input: QueryInput) -> Result<Reply> {
        let _memory = self.memory.enter();
        if input.pattern.len() > self.limits.batch_bytes {
            return Err(Error::limit("query input capacity exceeded"));
        }
        let info = self.query_info(session)?;
        self.provider_scope(info.provider)?;
        NodeData {
            fields: input.options.clone(),
            ..NodeData::default()
        }
        .validate()?;
        let payloads = super::memory::Payload::input(input.pattern.clone(), input.options.clone());
        self.memory.check()?;
        let generation = info
            .generation
            .checked_add(1)
            .ok_or_else(|| Error::limit("query generation exhausted"))?;
        let commit = self.commit.next()?;
        let mut effects = Vec::new();
        for work in self.query_work.values_mut() {
            if work.token.session == session && !work.cancelled {
                work.cancelled = true;
                effects.push(Effect::CancelQuery { token: work.token });
            }
        }
        let query = self.queries.get_mut(&session.0).expect("validated session");
        query.info.generation = generation;
        query.info.input = input;
        query.info._payloads = payloads;
        query.info.error = None;
        query.info.load_state = LoadState::Loading;
        query.accepting = true;
        query.pending = true;
        query.next_sequence = 1;
        self.commit = commit;
        for entry in self.states.values_mut() {
            entry.dirty.pending = true;
        }
        effects.extend(self.schedule_queries()?);
        Ok(self.applied(None, effects))
    }

    pub(crate) fn schedule_queries(&mut self) -> Result<Vec<Effect>> {
        let mut effects = Vec::new();
        let invalid: Vec<_> = self
            .queries
            .iter()
            .filter_map(|(&id, query)| {
                if !query.accepting {
                    return None;
                }
                self.provider_scope(query.info.provider)
                    .err()
                    .map(|error| (id, error))
            })
            .collect();
        for (id, error) in invalid {
            let query = self.queries.get_mut(&id).expect("invalid query scope");
            query.accepting = false;
            query.pending = false;
            query.info.load_state = LoadState::Error;
            query.info.error = Some(error);
            for work in self
                .query_work
                .values_mut()
                .filter(|work| work.token.session.0 == id && !work.cancelled)
            {
                work.cancelled = true;
                effects.push(Effect::CancelQuery { token: work.token });
            }
            self.query_changed()?;
        }
        let pending: Vec<_> = self
            .queries
            .iter()
            .filter(|(_, query)| query.accepting && query.pending)
            .map(|(&id, _)| id)
            .collect();
        for id in pending {
            if self.work_count() >= self.limits.concurrent_reads {
                break;
            }
            let info = self.queries[&id].info.clone();
            if let Err(error) = self.provider_scope(info.provider) {
                let query = self.queries.get_mut(&id).expect("pending query");
                query.pending = false;
                query.accepting = false;
                query.info.load_state = LoadState::Error;
                query.info.error = Some(error);
                self.query_changed()?;
                continue;
            }
            let token = QueryToken {
                data: self.source.identity(),
                work: identity()?,
                session: info.session,
                generation: info.generation,
            };
            self.queries.get_mut(&id).expect("pending query").pending = false;
            self.query_work.insert(
                token.work,
                QueryWork {
                    token,
                    cancelled: false,
                },
            );
            effects.push(Effect::Query {
                token,
                input: info.input,
                sequence: 1,
            });
        }
        Ok(effects)
    }

    fn check_query(&self, token: QueryToken, sequence: u64) -> Result<()> {
        if token.data != self.source.identity() {
            return Err(Error::stale("query token belongs to another data owner"));
        }
        let query = self
            .queries
            .get(&token.session.0)
            .ok_or_else(|| Error::new(ErrorCode::Disposed, "query session released"))?;
        let active = self
            .query_work
            .get(&token.work)
            .is_some_and(|work| work.token == token && !work.cancelled);
        if !active
            || !query.accepting
            || query.info.generation != token.generation
            || query.next_sequence != sequence
        {
            return Err(Error::stale("query generation or page sequence changed"));
        }
        self.provider_scope(query.info.provider)?;
        Ok(())
    }

    fn retire_stale_query(&mut self, token: QueryToken) {
        let stale = self.query_work.get(&token.work).is_some_and(|work| {
            work.token == token
                && (work.cancelled
                    || self.queries.get(&token.session.0).is_none_or(|query| {
                        !query.accepting
                            || query.info.generation != token.generation
                            || self.provider_scope(query.info.provider).is_err()
                    }))
        });
        if stale {
            self.query_work.remove(&token.work);
        }
    }

    pub fn query_page(
        &mut self,
        token: QueryToken,
        sequence: u64,
        records: Vec<Record>,
        done: bool,
    ) -> Result<Reply> {
        if let Err(error) = self.check_query(token, sequence) {
            self.retire_stale_query(token);
            return Err(error);
        }
        let mut candidate = self.clone();
        match candidate.apply_query_page(token, sequence, &records, done) {
            Ok(effects) => {
                *self = candidate;
                Ok(self.applied(None, effects))
            }
            Err(error) => {
                if let Reply::Applied { effects, .. } =
                    self.query_failed(token, sequence, error.clone())?
                {
                    self.deferred_effects.extend(effects.iter().cloned());
                }
                Err(error)
            }
        }
    }

    fn apply_query_page(
        &mut self,
        token: QueryToken,
        sequence: u64,
        records: &[Record],
        done: bool,
    ) -> Result<Vec<Effect>> {
        let _memory = self.memory.enter();
        let info = self.query_info(token.session)?;
        let scope = self.provider_scope(info.provider)?;
        let protected: Vec<_> = self
            .providers
            .iter()
            .filter(|(id, _)| **id != info.provider.0)
            .map(|(_, provider)| provider.scope)
            .collect();
        let operations = plan_import(
            &self.source,
            scope,
            records,
            sequence == 1,
            false,
            &self.limits,
            &protected,
        )?;
        let mut effects = self
            .apply_batch(Batch {
                base_revision: self.source.revision(),
                operations,
            })?
            .into_effects();
        if done && !matches!(scope, super::DataScope::Children(_)) {
            let operations = self
                .source
                .nodes
                .iter()
                .filter(|(id, node)| {
                    scope.contains(&self.source, **id)
                        && node.data.can_expand
                        && node.completeness != Completeness::Complete
                })
                .map(|(id, _)| super::Operation::Update {
                    node: (*id).into(),
                    patch: super::NodePatch {
                        completeness: Some(Completeness::Complete),
                        ..super::NodePatch::default()
                    },
                })
                .collect();
            effects.extend(
                self.apply_batch(Batch {
                    base_revision: self.source.revision(),
                    operations,
                })?
                .into_effects(),
            );
        }
        if let Some(anchor) = scope.anchor() {
            self.set_slot(
                anchor,
                Some(if done {
                    Completeness::Complete
                } else {
                    Completeness::Partial
                }),
                if done {
                    LoadState::Idle
                } else {
                    LoadState::Loading
                },
                None,
                None,
            )?;
        }
        let next = sequence
            .checked_add(1)
            .ok_or_else(|| Error::limit("query page sequence exhausted"))?;
        let query = self
            .queries
            .get_mut(&token.session.0)
            .expect("active query");
        query.info.result_generation = Some(token.generation);
        query.info.completeness = if done {
            Completeness::Complete
        } else {
            Completeness::Partial
        };
        query.info.load_state = if done {
            LoadState::Idle
        } else {
            LoadState::Loading
        };
        query.next_sequence = next;
        query.accepting = !done;
        let mut source = (*self.source).clone();
        source.query_results.insert(
            scope,
            QueryResult {
                _payloads: query.info._payloads.clone(),
                session: token.session,
                generation: token.generation,
                input: query.info.input.clone(),
                completeness: query.info.completeness,
            },
        );
        source.revision = source.revision.next()?;
        self.memory.check()?;
        self.source = std::sync::Arc::new(source);
        if done {
            self.query_work.remove(&token.work);
        } else {
            effects.push(Effect::Query {
                token,
                input: info.input,
                sequence: next,
            });
        }
        self.query_changed()?;
        Ok(effects)
    }

    pub fn query_failed(
        &mut self,
        token: QueryToken,
        sequence: u64,
        error: Error,
    ) -> Result<Reply> {
        if let Err(stale) = self.check_query(token, sequence) {
            self.retire_stale_query(token);
            return Err(stale);
        }
        let mut candidate = self.clone();
        let provider = candidate.query_info(token.session)?.provider;
        let scope = candidate.provider_scope(provider)?;
        let commit = candidate.commit.next()?;
        let query = candidate
            .queries
            .get_mut(&token.session.0)
            .expect("active query");
        query.accepting = false;
        query.pending = false;
        query.info.load_state = LoadState::Error;
        query.info.error = Some(error.clone());
        candidate.query_work.remove(&token.work);
        candidate.commit = commit;
        if let Some(anchor) = scope.anchor() {
            candidate.set_slot(anchor, None, LoadState::Error, Some(error.clone()), None)?;
        }
        let failed: Vec<_> = candidate
            .states
            .iter()
            .filter_map(|(&id, entry)| {
                entry
                    .task
                    .as_ref()
                    .filter(|task| {
                        task.cleanup.is_none()
                            && task.needed.iter().any(|node| {
                                candidate
                                    .query_for_slot(*node)
                                    .is_some_and(|query| query.info.session == token.session)
                            })
                    })
                    .map(|task| (id, task.lock))
            })
            .collect();
        let mut effects = Vec::new();
        for (id, lock) in failed {
            effects.push(candidate.fail_task(id, lock, error.clone())?);
        }
        for entry in candidate.states.values_mut() {
            entry.dirty.pending = true;
        }
        *self = candidate;
        Ok(self.applied(None, effects))
    }

    pub fn cancel_query(&mut self, session: QueryId) -> Result<Reply> {
        let info = self.query_info(session)?;
        let anchor = self
            .providers
            .get(&info.provider.0)
            .and_then(|provider| provider.scope.anchor());
        let mut candidate = self.clone();
        if let Some(anchor) = anchor.filter(|anchor| {
            self.source
                .node(*anchor)
                .is_some_and(|node| node.load_state == LoadState::Loading)
        }) {
            candidate.set_slot(anchor, None, LoadState::Idle, None, None)?;
        }
        let result = candidate.cancel_query_input(session)?;
        *self = candidate;
        Ok(result)
    }

    fn cancel_query_input(&mut self, session: QueryId) -> Result<Reply> {
        let commit = self.commit.next()?;
        let mut effects = Vec::new();
        for work in self.query_work.values_mut() {
            if work.token.session == session && !work.cancelled {
                work.cancelled = true;
                effects.push(Effect::CancelQuery { token: work.token });
            }
        }
        let query = self.queries.get_mut(&session.0).expect("live query");
        query.accepting = false;
        query.pending = false;
        query.info.load_state = LoadState::Idle;
        self.commit = commit;
        for entry in self.states.values_mut() {
            entry.dirty.pending = true;
        }
        Ok(self.applied(None, effects))
    }

    pub fn query_cancelled(&mut self, token: QueryToken) -> Result<Reply> {
        let Some(work) = self.query_work.get(&token.work) else {
            return Err(Error::stale("query work already ended"));
        };
        if work.token != token {
            return Err(Error::stale("query work identity mismatch"));
        }
        if self
            .queries
            .get(&token.session.0)
            .is_some_and(|query| query.info.generation == token.generation && query.accepting)
        {
            self.cancel_query(token.session)?;
        }
        self.query_work.remove(&token.work);
        Ok(self.applied(None, Vec::new()))
    }

    pub fn release_query(&mut self, session: QueryId) -> Result<Vec<Effect>> {
        let reply = self.cancel_query(session)?;
        self.queries.remove(&session.0);
        match reply {
            Reply::Applied { effects, .. } => Ok(effects.to_vec()),
            _ => Ok(Vec::new()),
        }
    }
}
