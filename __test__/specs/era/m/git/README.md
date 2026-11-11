# Git test guide

Git regression coverage lives here and in `rust/yoz/src/git/`; the contract is the
[Git design](../../../../../spec/design/feat/git.md). Job lifecycle and process cleanup are covered by
`specs/era/m/job_spec.lua` and `specs/era/m/job_exit_spec.lua`.

- Status, ignore and blame compare real Git query results with independent Lua references
  (`fixtures/era/m/git/*_lua_reference.lua`), including raw object identity, UI projections, symlinks,
  invalidation and cancellation.
- Staging covers byte/EOL normalization, histogram selection, 40k-line / 10k-hunk reference-stack limits, real
  index writes, clean filters, stale snapshots and FIFO release (`staging*_spec.lua`, `buffer/`).
- Unicode codecs use Neovim's actual file writer as the byte oracle, covering aliases, BOM, leading U+FEFF, LF/CRLF,
  NUL, BMP/astral text and EOF; invalid or unrepresentable input must preserve the index
  (`buffer/write_index_encoding_spec.lua`, `staging_encoding_spec.lua`).
- Word diff covers 2,000 seeded byte edits, the 500-byte cap, failure/empty-result contracts, and the actual popup
  text, highlight extmarks, keymap cleanup and source-buffer preservation (`word_diff_spec.lua`, `hunkview_spec.lua`).
- `fixtures/era/m/git/blame_history.lua` builds real history with 10k distinct commits to exercise the auxiliary
  reference stack; sparse labels, error recovery and arbitrary bytes are tested too.
- The job exit spec builds a tiny controlled Git-process fixture with the installed `rustc` in its temporary
  directory and skips when `rustc` is unavailable.

The Lua reference files keep the algorithms the differential tests compare against; they are not production
implementations and are not a source for new features.

Full-configuration checks of status, signs, ignore, blame and the word-highlight popup are in
`__test__/manual/era/m/git/`; each script starts with its command.
