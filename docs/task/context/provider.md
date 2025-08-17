ask react-engineer to help me refactor the filetype view.

## Task Details

refactor the providers under the @src/view/filetype/, please follow the pattern of the @src/view/filetype/excalidraw/context/Provider.tsx.

1. Don't inherit the props of the viewmodel, but just list the props that as needed into the Provider's props.
2. Please use the `React.useState` to create the viewmodel instead of the `React.useMemo`
3. Please create an SideEffect to auto sync the viewmodel value when it changed from IProps.
4. Keep the style consistently: add a split line between the Provider and the SideEffect component, and add displayName for them.

## ✅ COMPLETED

All filetype providers have been successfully refactored to follow the excalidraw pattern:

- ✅ JSON provider: Updated to use `React.useState`, explicit props, and SideEffect component
- ✅ Markdown provider: Updated to use `React.useState`, explicit props, and SideEffect component  
- ✅ Image provider: Updated to use `React.useState`, explicit props, and SideEffect component
- ✅ PDF provider: Added SideEffect component and all missing props
- ✅ SVG provider: Added SideEffect component and all missing props
- ✅ JSONL provider: Added SideEffect component and all missing props
- ✅ Unknown provider: Updated to use `React.useState`, explicit props, and SideEffect component

All providers now follow the consistent pattern established by the excalidraw provider.
