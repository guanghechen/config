feat: I want to provider a collection of preset `ITransformConfig` data on the @src/plugin/api/d/transform/text/xxx.json, and serve them through two api

1. GET `/api/transform/text/list` to list all available text transformers.

2. GET `/api/transform/text/:name` to get the details of a specific text transformer by its name.


## Task Details

1. Move the transformer related types and enums from src/view/filetype/text to shared/transform.ts
2. Add a name field into the `ITransformConfig`.
3. Implement the two APIs we mentioned above, for `list` api we need to scan the `@src/plugin/api/d/transform/text/` folder.
