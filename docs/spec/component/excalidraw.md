# Excalidraw Markdown Integration Specification (Implementation Guide)

## Overview

This document outlines the implementation of markdown support for Excalidraw using the existing Yoz markdown renderer. The integration allows users to create, edit, and render markdown content directly within Excalidraw canvases through a custom element system.

## Architecture

The implementation follows a custom element pattern with the following key components:

```
┌─────────────────────────────────────────────────────────────┐
│                    Excalidraw App                           │
├─────────────────────────────────────────────────────────────┤
│                  Custom Element System                      │
│  ┌─────────────────────┐    ┌──────────────────────────┐    │
│  │  Element Registry   │───▶│   Markdown Components    │    │
│  └─────────────────────┘    └──────────────────────────┘    │
│                                         │                   │
│                                         ▼                   │
│                              ┌──────────────────────────┐   │
│                              │  Yoz Markdown System     │   │
│                              │  - ReactMarkdown         │   │
│                              │  - AST Parser            │   │
│                              │  - Theme Integration     │   │
│                              └──────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Implementation Details

### 1. Custom Element Registry

**File**: `src/view/filetype/excalidraw/customElements/CustomElementRegistry.ts`

```typescript
export interface ICustomElementRenderer {
  render: (
    element: ExcalidrawElement,
    context: CanvasRenderingContext2D,
    renderConfig?: {
      maxLines?: number
      lineHeight?: number
      padding?: number
    }
  ) => void
  renderReact?: (element: ExcalidrawElement) => React.ReactElement
  getBounds: (element: ExcalidrawElement) => [number, number, number, number]
  hitTest: (element: ExcalidrawElement, x: number, y: number) => boolean
  defaultProps: Partial<ExcalidrawElement>
}

export class CustomElementRegistry {
  private renderers = new Map<string, ICustomElementRenderer>()

  public register(type: string, renderer: ICustomElementRenderer): void {
    this.renderers.set(type, renderer)
  }

  public getRenderer(type: string): ICustomElementRenderer | undefined {
    return this.renderers.get(type)
  }
}
```

### 2. Markdown Element Adapter

**File**: `src/view/filetype/excalidraw/customElements/YozMarkdownElement/MarkdownElementAdapter.tsx`

Key features:
- Integrates with existing Yoz markdown system
- Uses MarkdownTopProvider with theme support
- Responsive Tailwind CSS styling
- Proper TypeScript imports from '@excalidraw/excalidraw/element/types'

```typescript
export const MarkdownElement: React.FC<IMarkdownElementProps> = ({
  element,
  scale = 1,
  isSelected = false,
  onDoubleClick,
  isExporting = false,
}) => {
  const site = useSiteViewmodel()
  const theme = useStateValue(site.theme$)
  const themeScheme = theme === SiteTheme.DARKEN ? 'dark' : 'light'

  const content = element.customData?.content || '# Empty Markdown\n\nDouble-click to edit'
  
  const ast = useMemo<Root>(() => {
    return parseMarkdown(content, {
      shouldReservePosition: false,
      formatUrl: (url: string) => url,
    })
  }, [content])

  return (
    <MarkdownTopProvider theme={themeScheme}>
      <div 
        className={`w-full h-full p-4 cursor-default overflow-auto ${
          isSelected ? 'ring-2 ring-blue-500' : ''
        } ${isExporting ? 'overflow-hidden' : ''}`}
        style={{
          backgroundColor: element.backgroundColor || 'transparent',
          borderRadius: element.roundness ? '8px' : '0',
          fontSize: `${14 * scale}px`,
        }}
        onDoubleClick={onDoubleClick}
      >
        <ReactMarkdown
          ast={ast}
          dontShowFirstHeading={false}
          className="prose prose-sm max-w-none dark:prose-invert"
        />
      </div>
    </MarkdownTopProvider>
  )
}
```

### 3. Markdown Editor Modal

**File**: `src/view/filetype/excalidraw/customElements/YozMarkdownElement/MarkdownEditor.tsx`

Features:
- Edit/Preview toggle functionality
- Keyboard shortcuts (Ctrl+Enter to save, Esc to cancel)
- Full-screen modal with responsive design
- Tailwind CSS styling

### 4. Canvas Renderer

**File**: `src/view/filetype/excalidraw/customElements/YozMarkdownElement/MarkdownCanvasRenderer.ts`

Provides canvas-based rendering for:
- Export functionality
- Print support
- Performance optimization
- Text preview with word wrapping

### 5. UI Integration

**File**: `src/view/filetype/excalidraw/pane/content.tsx`

The main integration point uses Excalidraw's `renderTopRightUI` prop to add the markdown tool button:

```typescript
const renderTopRightUI = useEventCallback(() => {
  return (
    <MarkdownTool
      onCreateMarkdown={() => {
        if (excalidrawRef.current) {
          const api = excalidrawRef.current
          const newElement = {
            type: 'custom' as const,
            customType: 'yoz-markdown',
            x: 100,
            y: 100,
            width: 400,
            height: 300,
            customData: {
              content: '# New Markdown\n\nStart typing...',
            },
            ...yozMarkdownRenderer.defaultProps,
          }
          
          api.updateScene({
            elements: [...api.getSceneElements(), newElement],
          })
        }
      }}
    />
  )
})

return (
  <div className="relative box-border size-full">
    <$Excalidraw
      excalidrawAPI={api => {
        excalidrawRef.current = api
      }}
      initialData={excalidrawData}
      renderTopRightUI={renderTopRightUI}
      // ... other props
    />
  </div>
)
```

### 6. Markdown Tool Component

**File**: `src/view/filetype/excalidraw/tools/MarkdownToolComponent.tsx`

A simple button component that follows Excalidraw's design system:

```typescript
export const MarkdownTool: React.FC<IMarkdownToolProps> = ({ onCreateMarkdown }) => {
  return (
    <button
      type="button"
      className="excalidraw-button"
      title="Add Markdown (M)"
      onClick={onCreateMarkdown}
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        minWidth: '2rem',
        height: '2rem',
        backgroundColor: 'var(--button-gray-1)',
        border: '1px solid var(--button-gray-2)',
        color: 'var(--text-primary-color)',
      }}
    >
      <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor">
        <path d="M2 6h20v2H2V6zm0 4h20v2H2v-2zm0 4h20v2H2v-2z" />
      </svg>
      <span style={{ marginLeft: '4px', fontSize: '10px' }}>MD</span>
    </button>
  )
}
```

## Key Implementation Decisions

### 1. TypeScript Integration
- All ExcalidrawElement imports use '@excalidraw/excalidraw/element/types'
- Proper interface definitions with I-prefixed naming convention
- Type safety maintained throughout the component hierarchy

### 2. Styling Approach
- Tailwind CSS utility classes for responsive design
- Excalidraw CSS variables for design system consistency
- Theme integration with existing site theme system

### 3. Component Architecture
- Reuse of existing Yoz markdown components (ReactMarkdown, MarkdownTopProvider)
- Separation of concerns between React rendering and canvas rendering
- Modal editor pattern for complex editing workflows

### 4. Excalidraw Integration
- Uses `renderTopRightUI` prop for toolbar integration
- Follows Excalidraw's custom element patterns
- Proper event handling and API usage

## Dependencies Required

```json
{
  "@yozora/ast": "^2.3.2",
  "@yozora/parser": "^2.3.2",
  "@guanghechen/react-viewmodel": "^5.1.0",
  "@guanghechen/equal": "^5.1.0",
  "clsx": "^2.0.0"
}
```

## File Structure

```
src/view/filetype/excalidraw/
├── customElements/
│   ├── CustomElementRegistry.ts
│   └── YozMarkdownElement/
│       ├── MarkdownElementAdapter.tsx
│       ├── MarkdownEditor.tsx
│       ├── MarkdownCanvasRenderer.ts
│       └── index.ts
├── tools/
│   └── MarkdownToolComponent.tsx
└── pane/
    └── content.tsx (modified)
```

## Usage

1. **Creating Markdown Elements**: Click the "MD" button in the top-right toolbar
2. **Editing Content**: Double-click any markdown element to open the editor
3. **Theme Support**: Automatically adapts to site theme (light/dark)
4. **Export**: Markdown content is properly rendered in exports and prints

## Benefits

1. **Seamless Integration**: Leverages existing Yoz markdown infrastructure
2. **Performance**: Dual rendering system (React + Canvas) for optimal performance
3. **Consistency**: Follows Excalidraw design patterns and TypeScript conventions
4. **Maintainability**: Clean separation of concerns and modular architecture
5. **User Experience**: Intuitive editing with familiar keyboard shortcuts

## Future Enhancements

1. **Collaborative Editing**: Integration with Excalidraw's real-time collaboration
2. **Template System**: Pre-configured markdown templates
3. **Advanced Export**: Enhanced PDF export with full markdown rendering
4. **Mobile Optimization**: Touch-friendly editing interface
5. **Plugin System**: Extensible architecture for additional markdown features
