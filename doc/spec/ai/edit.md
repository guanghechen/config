@lua/fml/action/ai.lua

* [x] Please use the `eve.buf.retrieve_visual_range()` (@lua/eve/builtin/buf.lua#L236) to retrieve the visual range.
* [x] Use eve.ai.edit_inline to run the edit_inline command. (@lua/eve/builtin/ai.lua)
* [x] When ai edit completed, let's show a notification with the cli output and then trigger a checktime to reload buffers.
* [x] When ai edit failed, show the error message from the cli.

