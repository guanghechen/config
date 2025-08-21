@src/view/filetype/text/

Text transform mode implementation with three-section pipeline: Split → Transformers → Identifiers.

## Features

1. [x] **Transform Pipeline**: Split text → Apply transformers → Generate identifiers → Render nodes
2. [x] **UI Controls**: Input fields for regex/functions, drag & drop reordering, skip toggles
3. [x] **State Persistence**: Transform config saved in viewmodel with mode state
4. [x] **Run Button**: Execute pipeline and display results in View pane (left of Import button)
5. [x] **Error Handling**: Validation for regex patterns, function syntax, return types
6. [x] **Import/Export**: Share transform configs via clipboard JSON

## Sections

1. **Split**: Regex `/\\n/` or function `(text) => text.split('\\n')` to create string array
2. **Transformers**: Chain of filter/map functions with skip support and reordering
   - Filter: `(element, index, elements) => boolean`
   - Map: `(element, index, elements) => any`
3. **Identifiers**: UUID and Parent UUID functions for final node structure
   - UUID: `(item, index, items) => string`
   - Parent UUID: `(item, index, items) => string|null`

## Data Structure

```typescript
interface INode {
  readonly uuid: string
  readonly parent_uuid: string | null
  readonly data: any
}
```

## Export Format

```json
{
  "split": "/\\n/",
  "uuid": "(item, index, items) => `item-${index}`",
  "parent_uuid": "(item, index, items) => null",
  "transformers": [
    { "type": "filter", "code": "(element) => element.trim().length > 0", "skip": false },
    { "type": "map", "code": "(element) => element.trim()", "skip": false }
  ]
}
```
