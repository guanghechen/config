
## Architecture

* `lua/eve/builtin/buf.lua`: Maintains the buffer states and provide common helpful methods.
  - `close`: Force close the target buffer.
  - `loadfile`: Load the given filepath into a buffer, if there is already exist such buffer with the given filepath, it will return that buffer directly
  - `resolve`: Calculate or retrieve the metadata (state) for the given buffer.

