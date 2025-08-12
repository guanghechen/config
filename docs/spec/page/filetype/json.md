@src/view/filetype/json in the Provider SideEffect, let's call api to fetch the filepath data to fill the


✅ 1. Add a `content$` state into the viewmodel represent the literal content of the json file.
✅ 2. Add a `json$` state into the viewmodel represent the parsed json data.
✅ 3. In the provider SideEffect, fetch the file content and parse it into json data. 
   - You can use the `useFileResult` to fetch the json file content.
   - Remove the api call on the jsonView, we should use single data source, that should be the viewmodel.
