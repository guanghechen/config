@src/view/filetype/eventstream in the Provider SideEffect, let's call api to fetch the filepath data to fill the


✅ 1. Add a `content$` state into the viewmodel represent the literal content of the eventstream file.
✅ 2. Add a `events$` state into the viewmodel represent the parsed eventstream data line by line (should be a list of json).
✅ 3. In the provider SideEffect, fetch the file content and parse it into json data. 
     ✅ You can use the `useFileResult` to fetch the eventstream file content.
     ✅ Remove the api call on the eventstreamView, we should use single data source, that should be the viewmodel.
