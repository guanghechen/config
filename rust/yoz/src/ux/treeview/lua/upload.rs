use super::*;

pub(super) struct Upload {
    data: DataHandle,
    provider: Option<ProviderHandle>,
    scope: DataScope,
    base: Revision,
    records: Vec<Record>,
    permit: Option<super::super::runtime::UploadPermit>,
    error: Option<Error>,
    bytes: usize,
}

impl Upload {
    pub fn new(
        data: DataHandle,
        provider: Option<ProviderHandle>,
        scope: DataScope,
        base: Revision,
    ) -> Result<Self> {
        let permit = data.reserve_upload()?;
        Ok(Self {
            data,
            provider,
            scope,
            base,
            records: Vec::new(),
            permit: Some(permit),
            error: None,
            bytes: 0,
        })
    }

    fn append(&mut self, input: LuaValue) -> Result<()> {
        if let Some(error) = &self.error {
            return Err(error.clone());
        }
        if self.permit.is_none() {
            return Err(Error::new(
                ErrorCode::Disposed,
                "private import already closed",
            ));
        }
        let input = input::table(input)?;
        let count = input::get::<Option<LuaTable>>(&input, "keys")?
            .map_or(input.raw_len(), |keys| keys.raw_len());
        if count > 512 || self.records.len().saturating_add(count) > self.data.limits().batch_nodes
        {
            return Err(Error::limit(
                "private import accepts at most 512 records per chunk",
            ));
        }
        let records = input::records_bounded(LuaValue::Table(input), 1024 * 1024)?;
        let mut bytes = 0usize;
        for record in &records {
            bytes = bytes
                .saturating_add(record.data.validate()?)
                .saturating_add(record.key.len())
                .saturating_add(std::mem::size_of::<Record>());
        }
        if self.bytes.saturating_add(bytes) > self.data.limits().batch_bytes {
            return Err(Error::limit("private import byte capacity exceeded"));
        }
        self.permit.as_mut().expect("open import").charge(bytes)?;
        self.bytes += bytes;
        self.records.extend(records);
        Ok(())
    }
}

impl LuaUserData for Upload {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method_mut("append", |lua, this, input: LuaValue| {
            let result = match this.append(input) {
                Ok(()) => Reply::NoChange,
                Err(error) => {
                    this.records.clear();
                    this.permit.take();
                    this.error = Some(error.clone());
                    Reply::Rejected { error }
                }
            };
            output::reply(lua, &result)
        });
        methods.add_method_mut("commit", |_, this, ()| {
            let ticket = if let Some(error) = &this.error {
                Ticket::ready(error.clone())
            } else if let Some(permit) = this.permit.take() {
                let records = std::mem::take(&mut this.records);
                let action = match &this.provider {
                    Some(provider) => Action::ProviderImport(provider.id(), this.base, records),
                    None => Action::Import(Import {
                        base_revision: this.base,
                        scope: this.scope,
                        records,
                    }),
                };
                this.data.submit_upload(action, permit)
            } else {
                Ticket::ready(Error::new(
                    ErrorCode::Disposed,
                    "private import already closed",
                ))
            };
            Ok(LuaTicket {
                ticket,
                _data: this.data.clone(),
            })
        });
        methods.add_method_mut("dispose", |_, this, ()| {
            this.records.clear();
            this.permit.take();
            Ok(())
        });
    }
}
