@src/view/filetype/jsonl in the Provider SideEffect, let's call api to fetch the filepath data to fill the


✅ 1. Add a `content$` state into the viewmodel represent the literal content of the jsonl file.
✅ 2. Add a `jsons$` state into the viewmodel represent the parsed jsonl data (should be a list of json).
✅ 3. In the provider SideEffect, fetch the file content and parse it into json data. 
      - You can use the `useFileResult` to fetch the jsonl file content.
      - Remove the api call on the JsonlView, we should use single data source, that should be the viewmodel.
