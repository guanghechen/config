# Drawboard - Personal Canvas Drawer Implementation Plan

## Executive Summary

This document outlines a comprehensive plan to build Drawboard, a personal canvas drawing tool inspired by Excalidraw's hand-drawn aesthetic and sophisticated UI design. The implementation uses React, TypeScript, and Tailwind CSS, with a context-based state management pattern similar to your existing Excalidraw context structure.

**2024 Update**: This spec has been enhanced to include Excalidraw-inspired toolbar improvements for a more professional and polished user experience.

## Project Architecture Overview

```
Drawboard/
├── components/
│   ├── Drawboard.tsx              # Main canvas wrapper component
│   ├── StaticCanvas.tsx         # Renders drawing elements
│   ├── InteractiveCanvas.tsx    # Handles UI overlays
│   ├── GridCanvas.tsx           # Grid/ruler background layer
│   ├── icons/
│   │   └── MaterialIcons.tsx    # Custom Material Design SVG icons
│   ├── ui/                       # Enhanced UI components (Excalidraw-inspired)
│   │   ├── Island.tsx           # Professional container with shadows/blur
│   │   ├── ToolButton.tsx       # Sophisticated button with animations
│   │   ├── ToolSeparator.tsx    # Enhanced visual separators
│   │   ├── Dropdown.tsx         # Advanced tool dropdown component
│   │   ├── HintViewer.tsx       # Contextual help display
│   │   └── ButtonGroup.tsx      # Tool grouping component
│   ├── tools/                    # Enhanced toolbar system
│   │   ├── MainToolbar.tsx      # Redesigned Excalidraw-style toolbar
│   │   ├── ActionToolbar.tsx    # Enhanced action controls
│   │   ├── MobileToolbar.tsx    # Mobile-optimized toolbar
│   │   ├── ToolGroup.tsx        # Tool grouping logic
│   │   ├── ExtraToolsDropdown.tsx # Advanced tools dropdown
│   │   └── PropertiesPanel.tsx  # Element properties panel
│   ├── sidebar/                  # Advanced sidebar system
│   │   ├── PropertiesSidebar.tsx # Advanced properties controls
│   │   └── index.ts             # Sidebar exports
│   └── context-menu/            # Context menu system
│       ├── DrawboardContextMenu.tsx
│       └── index.ts
├── context/
│   ├── Provider.tsx             # Context provider with side effects
│   ├── context.ts               # Context definition
│   ├── types.ts                 # Type definitions
│   ├── viewmodel.ts             # ViewModel with observable state
│   └── index.ts                 # Exports
├── renderer/
│   ├── RoughRenderer.ts         # Hand-drawn style rendering
│   ├── elements/
│   │   ├── line.ts              # Line rendering
│   │   ├── rectangle.ts         # Rectangle rendering
│   │   ├── circle.ts            # Circle/ellipse rendering
│   │   └── arrow.ts             # Arrow rendering
│   └── grid.ts                  # Grid rendering utilities
├── utils/
│   ├── geometry.ts              # Geometric calculations
│   ├── roughjs.ts               # RoughJS wrapper utilities
│   ├── canvas.ts                # Canvas helper functions
│   └── export.ts                # Export utilities (PNG, SVG, JSON)
├── hooks/
│   ├── useCanvas.ts             # Canvas ref and context management
│   ├── usePointerEvents.ts      # Mouse/touch event handling
│   ├── useKeyboardShortcuts.ts  # Keyboard shortcuts
│   ├── useContextMenu.ts        # Context menu handling
│   └── useIsMobile.ts           # Mobile detection
└── types/
    └── elements.ts              # Element type definitions
```

## Phase 1: Core Infrastructure (Week 1)

### 1.1 Type Definitions

**File: `types/elements.ts`**

```typescript
// Base element properties
export interface IDrawboardElementBase {
  id: string;
  type: HElementType;
  x: number;
  y: number;
  width: number;
  height: number;
  angle: number;
  strokeColor: string;
  backgroundColor: string;
  fillStyle: FillStyle;
  strokeWidth: number;
  strokeStyle: StrokeStyle;
  roughness: number;
  opacity: number;
  strokeSharpness?: StrokeSharpness;
  seed: number;
  versionNonce: number;
  isDeleted: boolean;
  boundElements?: IBoundElement[] | null;
  updated: number;
}

export type HElementType = "line" | "rectangle" | "circle" | "arrow";
export type FillStyle = "solid" | "hachure" | "cross-hatch";
export type StrokeStyle = "solid" | "dashed" | "dotted";
export type StrokeSharpness = "sharp" | "round";

export interface IDrawboardLineElement extends IDrawboardElementBase {
  type: "line";
  points: [number, number][];
  lastCommittedPoint?: [number, number];
}

export interface IDrawboardRectangleElement extends IDrawboardElementBase {
  type: "rectangle";
}

export interface IDrawboardCircleElement extends IDrawboardElementBase {
  type: "circle";
}

export interface IDrawboardArrowElement extends IDrawboardLineElement {
  type: "arrow";
  startArrowhead?: "arrow" | "dot" | "bar";
  endArrowhead?: "arrow" | "dot" | "bar";
}

export type DrawboardElement = 
  | IDrawboardLineElement 
  | IDrawboardRectangleElement 
  | IDrawboardCircleElement 
  | IDrawboardArrowElement;
```

### 1.2 Context Structure

**File: `context/types.ts`**

```typescript
import type { DrawboardElement, HElementType } from "../types/elements";

export enum ToolMode {
  SELECT = 1 << 0,
  LINE = 1 << 1,
  RECTANGLE = 1 << 2,
  CIRCLE = 1 << 3,
  ARROW = 1 << 4,
  PAN = 1 << 5,
}

export interface IDrawboardViewData {
  mode: ToolMode;
  zoom: number;
  offsetX: number;
  offsetY: number;
  gridSize: number;
  showGrid: boolean;
  showRulers: boolean;
  snapToGrid: boolean;
}

export interface IDrawboardAppState {
  selectedElementIds: Record<string, boolean>;
  selectedTool: ToolMode;
  viewBackgroundColor: string;
  currentItemStrokeColor: string;
  currentItemBackgroundColor: string;
  currentItemFillStyle: string;
  currentItemStrokeWidth: number;
  currentItemStrokeStyle: string;
  currentItemRoughness: number;
  currentItemOpacity: number;
  currentItemFont: string;
  cursorButton: "up" | "down";
  scrolledOutside: boolean;
  zoom: {
    value: number;
  };
  openMenu: string | null;
  lastPointerDownWith: "mouse" | "touch" | "pen";
}
```

**File: `context/viewmodel.ts`**

```typescript
import { State, ViewModel } from "@guanghechen/react-viewmodel";
import type { IState } from "@guanghechen/react-viewmodel";
import type { DrawboardElement } from "../types/elements";
import type { IDrawboardViewData, IDrawboardAppState, ToolMode } from "./types";

interface IProps {
  mode?: ToolMode;
  onSave?: (elements: DrawboardElement[]) => void;
}

const DEFAULT_VIEW_DATA: IDrawboardViewData = {
  mode: ToolMode.SELECT,
  zoom: 1,
  offsetX: 0,
  offsetY: 0,
  gridSize: 20,
  showGrid: true,
  showRulers: false,
  snapToGrid: false,
};

const DEFAULT_APP_STATE: Partial<IDrawboardAppState> = {
  selectedElementIds: {},
  selectedTool: ToolMode.SELECT,
  viewBackgroundColor: "#ffffff",
  currentItemStrokeColor: "#000000",
  currentItemBackgroundColor: "transparent",
  currentItemFillStyle: "solid",
  currentItemStrokeWidth: 2,
  currentItemStrokeStyle: "solid",
  currentItemRoughness: 1,
  currentItemOpacity: 100,
  zoom: { value: 1 },
};

export class DrawboardViewModel extends ViewModel {
  // Observable states
  public readonly mode$: IState<ToolMode>;
  public readonly elements$: IState<DrawboardElement[]>;
  public readonly appState$: IState<IDrawboardAppState>;
  public readonly viewData$: IState<IDrawboardViewData>;
  
  // Callbacks
  public readonly onSave?: (elements: DrawboardElement[]) => void;

  constructor(props: IProps) {
    super();
    
    const { mode = DEFAULT_VIEW_DATA.mode, onSave } = props;
    
    this.mode$ = new State<ToolMode>(mode);
    this.elements$ = new State<DrawboardElement[]>([]);
    this.appState$ = new State<IDrawboardAppState>(DEFAULT_APP_STATE as IDrawboardAppState);
    this.viewData$ = new State<IDrawboardViewData>(DEFAULT_VIEW_DATA);
    this.onSave = onSave;
  }

  // Element management
  public addElement = (element: DrawboardElement): void => {
    const elements = [...this.elements$.getSnapshot(), element];
    this.elements$.next(elements);
  };

  public updateElement = (id: string, updates: Partial<DrawboardElement>): void => {
    const elements = this.elements$.getSnapshot().map((el) =>
      el.id === id ? { ...el, ...updates, updated: Date.now() } : el
    );
    this.elements$.next(elements);
  };

  public deleteElements = (ids: string[]): void => {
    const idSet = new Set(ids);
    const elements = this.elements$.getSnapshot().filter((el) => !idSet.has(el.id));
    this.elements$.next(elements);
  };

  // View management
  public setZoom = (zoom: number): void => {
    const viewData = this.viewData$.getSnapshot();
    this.viewData$.next({ ...viewData, zoom });
    
    const appState = this.appState$.getSnapshot();
    this.appState$.next({ ...appState, zoom: { value: zoom } });
  };

  public pan = (deltaX: number, deltaY: number): void => {
    const viewData = this.viewData$.getSnapshot();
    this.viewData$.next({
      ...viewData,
      offsetX: viewData.offsetX + deltaX,
      offsetY: viewData.offsetY + deltaY,
    });
  };

  public setTool = (tool: ToolMode): void => {
    this.mode$.next(tool);
    const appState = this.appState$.getSnapshot();
    this.appState$.next({ ...appState, selectedTool: tool });
  };

  public toggleGrid = (): void => {
    const viewData = this.viewData$.getSnapshot();
    this.viewData$.next({ ...viewData, showGrid: !viewData.showGrid });
  };

  public toggleRulers = (): void => {
    const viewData = this.viewData$.getSnapshot();
    this.viewData$.next({ ...viewData, showRulers: !viewData.showRulers });
  };
}
```

**File: `context/Provider.tsx`**

```typescript
import { useViewModel } from "@guanghechen/react-viewmodel";
import React from "react";
import type { IDrawboardContext } from "./context";
import { DrawboardContextType } from "./context";
import type { ToolMode } from "./types";
import { DrawboardViewModel } from "./viewmodel";

interface IProps {
  mode?: ToolMode;
  onSave?: (elements: DrawboardElement[]) => void;
  children: React.ReactNode;
}

export const DrawboardProvider: React.FC<IProps> = ({ mode, onSave, children }) => {
  const viewmodel = useViewModel<DrawboardViewModel>(() => {
    return new DrawboardViewModel({ mode, onSave });
  });

  const context = React.useMemo<IDrawboardContext | null>(
    () => (viewmodel ? { viewmodel } : null),
    [viewmodel]
  );

  if (!viewmodel || !context) return null;

  return (
    <DrawboardContextType.Provider value={context}>
      {children}
    </DrawboardContextType.Provider>
  );
};
```

### 1.3 Main Canvas Component

**File: `components/Drawboard.tsx`**

```typescript
import React, { useRef, useEffect } from "react";
import { DrawboardProvider } from "../context/Provider";
import { GridCanvas } from "./GridCanvas";
import { StaticCanvas } from "./StaticCanvas";
import { InteractiveCanvas } from "./InteractiveCanvas";
import { ToolPanel } from "./tools/ToolPanel";
import { PropertiesPanel } from "./tools/PropertiesPanel";
import { useDrawboardContext } from "../context";
import { usePointerEvents } from "../hooks/usePointerEvents";
import { useKeyboardShortcuts } from "../hooks/useKeyboardShortcuts";

interface IDrawboardProps {
  className?: string;
  onSave?: (elements: DrawboardElement[]) => void;
}

const DrawboardInner: React.FC = () => {
  const containerRef = useRef<HTMLDivElement>(null);
  const { viewmodel } = useDrawboardContext();
  
  usePointerEvents(containerRef, viewmodel);
  useKeyboardShortcuts(viewmodel);

  return (
    <div className="relative h-full w-full overflow-hidden bg-gray-50">
      {/* Tool Panel */}
      <div className="absolute left-4 top-4 z-20">
        <ToolPanel />
      </div>

      {/* Properties Panel */}
      <div className="absolute right-4 top-4 z-20">
        <PropertiesPanel />
      </div>

      {/* Canvas Container */}
      <div ref={containerRef} className="relative h-full w-full">
        {/* Grid Layer */}
        <GridCanvas />
        
        {/* Static Canvas - Drawing Elements */}
        <StaticCanvas />
        
        {/* Interactive Canvas - UI Overlays */}
        <InteractiveCanvas />
      </div>
    </div>
  );
};

export const Drawboard: React.FC<IDrawboardProps> = ({ className, onSave }) => {
  return (
    <DrawboardProvider onSave={onSave}>
      <div className={className}>
        <DrawboardInner />
      </div>
    </DrawboardProvider>
  );
};
```

## Phase 2: Rendering System (Week 1-2)

### 2.1 RoughJS Integration

**File: `renderer/RoughRenderer.ts`**

```typescript
import rough from "roughjs/bundled/rough.esm";
import type { RoughCanvas, Options } from "roughjs/bin/core";
import type { DrawboardElement } from "../types/elements";

export class RoughRenderer {
  private rc: RoughCanvas;
  private canvas: HTMLCanvasElement;
  private context: CanvasRenderingContext2D;

  constructor(canvas: HTMLCanvasElement) {
    this.canvas = canvas;
    this.context = canvas.getContext("2d")!;
    this.rc = rough.canvas(canvas);
  }

  public renderElement(element: DrawboardElement): void {
    const options = this.getRoughOptions(element);

    switch (element.type) {
      case "rectangle":
        this.renderRectangle(element, options);
        break;
      case "circle":
        this.renderCircle(element, options);
        break;
      case "line":
        this.renderLine(element, options);
        break;
      case "arrow":
        this.renderArrow(element, options);
        break;
    }
  }

  private getRoughOptions(element: DrawboardElement): Options {
    return {
      stroke: element.strokeColor,
      strokeWidth: element.strokeWidth,
      fill: element.backgroundColor,
      fillStyle: element.fillStyle,
      strokeLineDash: this.getStrokeDashArray(element.strokeStyle, element.strokeWidth),
      roughness: element.roughness,
      seed: element.seed,
    };
  }

  private getStrokeDashArray(style: string, width: number): number[] | undefined {
    switch (style) {
      case "dashed":
        return [width * 4, width * 2];
      case "dotted":
        return [width, width];
      default:
        return undefined;
    }
  }

  private renderRectangle(element: IDrawboardRectangleElement, options: Options): void {
    this.rc.rectangle(
      element.x,
      element.y,
      element.width,
      element.height,
      options
    );
  }

  private renderCircle(element: IDrawboardCircleElement, options: Options): void {
    const centerX = element.x + element.width / 2;
    const centerY = element.y + element.height / 2;
    this.rc.ellipse(
      centerX,
      centerY,
      element.width,
      element.height,
      options
    );
  }

  private renderLine(element: IDrawboardLineElement, options: Options): void {
    if (element.points.length < 2) return;
    
    const points = element.points.map(([x, y]) => [
      element.x + x,
      element.y + y
    ] as [number, number]);
    
    this.rc.linearPath(points, options);
  }

  private renderArrow(element: IDrawboardArrowElement, options: Options): void {
    // Render the line part
    this.renderLine(element, options);
    
    // Render arrowheads
    if (element.points.length >= 2) {
      const lastPoint = element.points[element.points.length - 1];
      const secondLastPoint = element.points[element.points.length - 2];
      
      if (element.endArrowhead === "arrow") {
        this.renderArrowhead(
          element.x + secondLastPoint[0],
          element.y + secondLastPoint[1],
          element.x + lastPoint[0],
          element.y + lastPoint[1],
          element
        );
      }
    }
  }

  private renderArrowhead(
    x1: number,
    y1: number,
    x2: number,
    y2: number,
    element: DrawboardElement
  ): void {
    const angle = Math.atan2(y2 - y1, x2 - x1);
    const arrowLength = 20;
    const arrowAngle = Math.PI / 6; // 30 degrees

    this.context.save();
    this.context.strokeStyle = element.strokeColor;
    this.context.lineWidth = element.strokeWidth;

    this.context.beginPath();
    this.context.moveTo(x2, y2);
    this.context.lineTo(
      x2 - arrowLength * Math.cos(angle - arrowAngle),
      y2 - arrowLength * Math.sin(angle - arrowAngle)
    );
    this.context.moveTo(x2, y2);
    this.context.lineTo(
      x2 - arrowLength * Math.cos(angle + arrowAngle),
      y2 - arrowLength * Math.sin(angle + arrowAngle)
    );
    this.context.stroke();

    this.context.restore();
  }
}
```

### 2.2 Grid Rendering

**File: `components/GridCanvas.tsx`**

```typescript
import React, { useRef, useEffect } from "react";
import { useStateValue } from "@guanghechen/react-viewmodel";
import { useDrawboardContext } from "../context";

export const GridCanvas: React.FC = () => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const { viewmodel } = useDrawboardContext();
  const viewData = useStateValue(viewmodel.viewData$);
  
  useEffect(() => {
    if (!canvasRef.current || !viewData.showGrid) return;
    
    const canvas = canvasRef.current;
    const ctx = canvas.getContext("2d")!;
    const { width, height } = canvas.getBoundingClientRect();
    
    canvas.width = width * window.devicePixelRatio;
    canvas.height = height * window.devicePixelRatio;
    ctx.scale(window.devicePixelRatio, window.devicePixelRatio);
    
    drawGrid(ctx, viewData.gridSize, viewData.offsetX, viewData.offsetY, width, height);
  }, [viewData.showGrid, viewData.gridSize, viewData.offsetX, viewData.offsetY]);

  if (!viewData.showGrid) return null;

  return (
    <canvas
      ref={canvasRef}
      className="absolute inset-0 pointer-events-none"
      style={{ opacity: 0.5 }}
    />
  );
};

function drawGrid(
  ctx: CanvasRenderingContext2D,
  gridSize: number,
  offsetX: number,
  offsetY: number,
  width: number,
  height: number
): void {
  ctx.strokeStyle = "#e5e7eb"; // gray-200
  ctx.lineWidth = 1;

  // Draw vertical lines
  for (let x = offsetX % gridSize; x < width; x += gridSize) {
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x, height);
    ctx.stroke();
  }

  // Draw horizontal lines
  for (let y = offsetY % gridSize; y < height; y += gridSize) {
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(width, y);
    ctx.stroke();
  }

  // Draw stronger lines every 5 grid units
  ctx.strokeStyle = "#d1d5db"; // gray-300
  ctx.lineWidth = 2;

  const majorGridSize = gridSize * 5;
  
  for (let x = offsetX % majorGridSize; x < width; x += majorGridSize) {
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x, height);
    ctx.stroke();
  }

  for (let y = offsetY % majorGridSize; y < height; y += majorGridSize) {
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(width, y);
    ctx.stroke();
  }
}
```

## Phase 3: Interaction System (Week 2)

### 3.1 Pointer Event Handling

**File: `hooks/usePointerEvents.ts`**

```typescript
import { useEffect, useRef } from "react";
import type { DrawboardViewModel } from "../context/viewmodel";
import { ToolMode } from "../context/types";
import { v4 as uuidv4 } from "uuid";
import type { DrawboardElement } from "../types/elements";

export function usePointerEvents(
  containerRef: React.RefObject<HTMLDivElement>,
  viewmodel: DrawboardViewModel
): void {
  const isDrawingRef = useRef(false);
  const currentElementRef = useRef<DrawboardElement | null>(null);
  const lastPointerRef = useRef({ x: 0, y: 0 });

  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    const getPointerPosition = (event: PointerEvent): { x: number; y: number } => {
      const rect = container.getBoundingClientRect();
      const viewData = viewmodel.viewData$.getSnapshot();
      return {
        x: (event.clientX - rect.left - viewData.offsetX) / viewData.zoom,
        y: (event.clientY - rect.top - viewData.offsetY) / viewData.zoom,
      };
    };

    const handlePointerDown = (event: PointerEvent): void => {
      isDrawingRef.current = true;
      lastPointerRef.current = getPointerPosition(event);
      
      const appState = viewmodel.appState$.getSnapshot();
      const tool = appState.selectedTool;

      if (tool === ToolMode.PAN) {
        container.style.cursor = "grabbing";
        return;
      }

      // Create new element based on tool
      const baseElement = {
        id: uuidv4(),
        x: lastPointerRef.current.x,
        y: lastPointerRef.current.y,
        width: 0,
        height: 0,
        angle: 0,
        strokeColor: appState.currentItemStrokeColor,
        backgroundColor: appState.currentItemBackgroundColor,
        fillStyle: appState.currentItemFillStyle as any,
        strokeWidth: appState.currentItemStrokeWidth,
        strokeStyle: appState.currentItemStrokeStyle as any,
        roughness: appState.currentItemRoughness,
        opacity: appState.currentItemOpacity,
        seed: Math.random() * 2 ** 31,
        versionNonce: 0,
        isDeleted: false,
        updated: Date.now(),
      };

      switch (tool) {
        case ToolMode.RECTANGLE:
          currentElementRef.current = { ...baseElement, type: "rectangle" };
          break;
        case ToolMode.CIRCLE:
          currentElementRef.current = { ...baseElement, type: "circle" };
          break;
        case ToolMode.LINE:
          currentElementRef.current = {
            ...baseElement,
            type: "line",
            points: [[0, 0]],
          };
          break;
        case ToolMode.ARROW:
          currentElementRef.current = {
            ...baseElement,
            type: "arrow",
            points: [[0, 0]],
          };
          break;
      }

      if (currentElementRef.current) {
        viewmodel.addElement(currentElementRef.current);
      }
    };

    const handlePointerMove = (event: PointerEvent): void => {
      const current = getPointerPosition(event);
      const appState = viewmodel.appState$.getSnapshot();

      if (!isDrawingRef.current) return;

      if (appState.selectedTool === ToolMode.PAN) {
        const deltaX = current.x - lastPointerRef.current.x;
        const deltaY = current.y - lastPointerRef.current.y;
        viewmodel.pan(deltaX * viewmodel.viewData$.getSnapshot().zoom, deltaY * viewmodel.viewData$.getSnapshot().zoom);
        lastPointerRef.current = current;
        return;
      }

      if (!currentElementRef.current) return;

      const element = currentElementRef.current;
      const deltaX = current.x - element.x;
      const deltaY = current.y - element.y;

      switch (element.type) {
        case "rectangle":
        case "circle":
          viewmodel.updateElement(element.id, {
            width: deltaX,
            height: deltaY,
          });
          break;
        case "line":
        case "arrow":
          const newPoints = [...(element as any).points, [deltaX, deltaY]];
          viewmodel.updateElement(element.id, {
            points: newPoints,
          });
          break;
      }
    };

    const handlePointerUp = (): void => {
      isDrawingRef.current = false;
      currentElementRef.current = null;
      container.style.cursor = "default";
    };

    container.addEventListener("pointerdown", handlePointerDown);
    container.addEventListener("pointermove", handlePointerMove);
    container.addEventListener("pointerup", handlePointerUp);
    container.addEventListener("pointerleave", handlePointerUp);

    return () => {
      container.removeEventListener("pointerdown", handlePointerDown);
      container.removeEventListener("pointermove", handlePointerMove);
      container.removeEventListener("pointerup", handlePointerUp);
      container.removeEventListener("pointerleave", handlePointerUp);
    };
  }, [containerRef, viewmodel]);
}
```

### 3.2 Tool Panel

**File: `components/icons/MaterialIcons.tsx`**

```typescript
import React from "react";

interface IIconProps {
  className?: string;
  size?: number;
}

export const SelectIcon: React.FC<IIconProps> = ({ className = "", size = 24 }) => (
  <svg 
    className={className} 
    width={size} 
    height={size} 
    viewBox="0 0 24 24" 
    fill="currentColor"
  >
    <path d="M7.33 24l-2.83-2.829 9.339-9.175-9.339-9.167 2.83-2.829 12.17 11.996z"/>
  </svg>
);

export const LineIcon: React.FC<IIconProps> = ({ className = "", size = 24 }) => (
  <svg 
    className={className} 
    width={size} 
    height={size} 
    viewBox="0 0 24 24" 
    fill="none" 
    stroke="currentColor" 
    strokeWidth="2"
  >
    <path d="M3 3l18 18"/>
  </svg>
);

export const RectangleIcon: React.FC<IIconProps> = ({ className = "", size = 24 }) => (
  <svg 
    className={className} 
    width={size} 
    height={size} 
    viewBox="0 0 24 24" 
    fill="none" 
    stroke="currentColor" 
    strokeWidth="2"
  >
    <rect x="3" y="3" width="18" height="18" rx="2" ry="2"/>
  </svg>
);

export const CircleIcon: React.FC<IIconProps> = ({ className = "", size = 24 }) => (
  <svg 
    className={className} 
    width={size} 
    height={size} 
    viewBox="0 0 24 24" 
    fill="none" 
    stroke="currentColor" 
    strokeWidth="2"
  >
    <circle cx="12" cy="12" r="9"/>
  </svg>
);

export const ArrowIcon: React.FC<IIconProps> = ({ className = "", size = 24 }) => (
  <svg 
    className={className} 
    width={size} 
    height={size} 
    viewBox="0 0 24 24" 
    fill="none" 
    stroke="currentColor" 
    strokeWidth="2"
  >
    <path d="M5 12h14M12 5l7 7-7 7"/>
  </svg>
);

export const PanIcon: React.FC<IIconProps> = ({ className = "", size = 24 }) => (
  <svg 
    className={className} 
    width={size} 
    height={size} 
    viewBox="0 0 24 24" 
    fill="none" 
    stroke="currentColor" 
    strokeWidth="2"
  >
    <path d="M9 12l2 2 4-4"/>
    <path d="M21 12c0 4.97-4.03 9-9 9s-9-4.03-9-9 4.03-9 9-9 9 4.03 9 9z"/>
    <path d="M8 8l4 4-4 4"/>
  </svg>
);

export const GridIcon: React.FC<IIconProps> = ({ className = "", size = 24 }) => (
  <svg 
    className={className} 
    width={size} 
    height={size} 
    viewBox="0 0 24 24" 
    fill="none" 
    stroke="currentColor" 
    strokeWidth="2"
  >
    <rect x="3" y="3" width="7" height="7"/>
    <rect x="14" y="3" width="7" height="7"/>
    <rect x="14" y="14" width="7" height="7"/>
    <rect x="3" y="14" width="7" height="7"/>
  </svg>
);
```

**File: `components/tools/ToolPanel.tsx`**

```typescript
import React from "react";
import { useStateValue } from "@guanghechen/react-viewmodel";
import { useDrawboardContext } from "../../context";
import { ToolMode } from "../../context/types";
import {
  SelectIcon,
  LineIcon,
  RectangleIcon,
  CircleIcon,
  ArrowIcon,
  PanIcon,
  GridIcon,
} from "../icons/MaterialIcons";

const tools = [
  { mode: ToolMode.SELECT, icon: SelectIcon, label: "Select" },
  { mode: ToolMode.LINE, icon: LineIcon, label: "Line" },
  { mode: ToolMode.RECTANGLE, icon: RectangleIcon, label: "Rectangle" },
  { mode: ToolMode.CIRCLE, icon: CircleIcon, label: "Circle" },
  { mode: ToolMode.ARROW, icon: ArrowIcon, label: "Arrow" },
  { mode: ToolMode.PAN, icon: PanIcon, label: "Pan" },
];

export const ToolPanel: React.FC = () => {
  const { viewmodel } = useDrawboardContext();
  const appState = useStateValue(viewmodel.appState$);

  return (
    <div className="flex flex-col gap-1 rounded-lg bg-white p-2 shadow-lg">
      {tools.map(({ mode, icon: Icon, label }) => (
        <button
          key={mode}
          onClick={() => viewmodel.setTool(mode)}
          className={`
            group relative flex h-10 w-10 items-center justify-center rounded-lg
            transition-colors hover:bg-gray-100
            ${appState.selectedTool === mode ? "bg-blue-100 text-blue-600" : "text-gray-700"}
          `}
          title={label}
        >
          <Icon className="h-5 w-5" />
          <span className="absolute left-12 hidden whitespace-nowrap rounded bg-gray-800 px-2 py-1 text-xs text-white group-hover:block">
            {label}
          </span>
        </button>
      ))}
      
      <div className="my-2 border-t border-gray-200" />
      
      <button
        onClick={() => viewmodel.toggleGrid()}
        className="flex h-10 w-10 items-center justify-center rounded-lg text-gray-700 transition-colors hover:bg-gray-100"
        title="Toggle Grid"
      >
        <GridIcon className="h-5 w-5" />
      </button>
    </div>
  );
};
```

## Phase 4: Canvas Components (Week 2-3)

### 4.1 Static Canvas

**File: `components/StaticCanvas.tsx`**

```typescript
import React, { useRef, useEffect } from "react";
import { useStateValue } from "@guanghechen/react-viewmodel";
import { useDrawboardContext } from "../context";
import { RoughRenderer } from "../renderer/RoughRenderer";

export const StaticCanvas: React.FC = () => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const { viewmodel } = useDrawboardContext();
  const elements = useStateValue(viewmodel.elements$);
  const viewData = useStateValue(viewmodel.viewData$);

  useEffect(() => {
    if (!canvasRef.current) return;

    const canvas = canvasRef.current;
    const ctx = canvas.getContext("2d")!;
    const { width, height } = canvas.getBoundingClientRect();

    // Set canvas resolution
    canvas.width = width * window.devicePixelRatio;
    canvas.height = height * window.devicePixelRatio;
    ctx.scale(window.devicePixelRatio, window.devicePixelRatio);

    // Clear canvas
    ctx.clearRect(0, 0, width, height);

    // Apply transformations
    ctx.save();
    ctx.translate(viewData.offsetX, viewData.offsetY);
    ctx.scale(viewData.zoom, viewData.zoom);

    // Render elements
    const renderer = new RoughRenderer(canvas);
    elements.forEach((element) => {
      if (!element.isDeleted) {
        renderer.renderElement(element);
      }
    });

    ctx.restore();
  }, [elements, viewData.offsetX, viewData.offsetY, viewData.zoom]);

  return (
    <canvas
      ref={canvasRef}
      className="absolute inset-0"
      style={{ cursor: "crosshair" }}
    />
  );
};
```

## Phase 5: Export and Persistence (Week 3)

### 5.1 Export Utilities

**File: `utils/export.ts`**

```typescript
import type { DrawboardElement } from "../types/elements";

export interface IExportOptions {
  backgroundColor?: string;
  padding?: number;
  scale?: number;
}

export async function exportToPNG(
  elements: DrawboardElement[],
  options: IExportOptions = {}
): Promise<Blob> {
  const {
    backgroundColor = "#ffffff",
    padding = 20,
    scale = 2,
  } = options;

  // Calculate bounds
  const bounds = calculateBounds(elements);
  const width = (bounds.maxX - bounds.minX + padding * 2) * scale;
  const height = (bounds.maxY - bounds.minY + padding * 2) * scale;

  // Create offscreen canvas
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d")!;

  // Set background
  ctx.fillStyle = backgroundColor;
  ctx.fillRect(0, 0, width, height);

  // Apply transformations
  ctx.scale(scale, scale);
  ctx.translate(
    -bounds.minX + padding,
    -bounds.minY + padding
  );

  // Render elements
  const { RoughRenderer } = await import("../renderer/RoughRenderer");
  const renderer = new RoughRenderer(canvas);
  elements.forEach((element) => {
    if (!element.isDeleted) {
      renderer.renderElement(element);
    }
  });

  // Convert to blob
  return new Promise((resolve) => {
    canvas.toBlob((blob) => {
      resolve(blob!);
    }, "image/png");
  });
}

export function exportToJSON(elements: DrawboardElement[]): string {
  return JSON.stringify({
    type: "drawboard",
    version: 1,
    elements: elements.filter((el) => !el.isDeleted),
  }, null, 2);
}

function calculateBounds(elements: DrawboardElement[]) {
  let minX = Infinity;
  let minY = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;

  elements.forEach((element) => {
    if (element.isDeleted) return;

    minX = Math.min(minX, element.x);
    minY = Math.min(minY, element.y);
    maxX = Math.max(maxX, element.x + element.width);
    maxY = Math.max(maxY, element.y + element.height);
  });

  return { minX, minY, maxX, maxY };
}
```

## Usage Example

```typescript
import React from "react";
import { Drawboard } from "./Drawboard";

function App() {
  const handleSave = (elements: DrawboardElement[]) => {
    console.log("Saving elements:", elements);
    // Save to backend or local storage
  };

  return (
    <div className="h-screen w-screen">
      <Drawboard 
        className="h-full w-full"
        onSave={handleSave}
      />
    </div>
  );
}
```

## Key Features Implemented

1. **Hand-drawn Style**: RoughJS integration for sketchy aesthetics
2. **Grid System**: Toggle-able grid with major/minor lines
3. **Multi-layer Architecture**: Separate canvases for grid, elements, and UI
4. **Observable State Management**: ViewModels with reactive state
5. **Tool System**: Select, draw, and pan tools
6. **Element Support**: Lines, rectangles, circles, and arrows
7. **Export Capabilities**: PNG and JSON export
8. **Responsive Design**: Tailwind CSS for styling
9. **TypeScript**: Full type safety throughout
10. **Professional Toolbar**: Excalidraw-inspired UI with sophisticated interactions
11. **Smart Tool Organization**: Grouped tools with dropdown for advanced features
12. **Enhanced Mobile Experience**: Optimized toolbar layout for touch devices

## Phase 6: Enhanced Toolbar System (Excalidraw-Inspired)

### 6.1 Enhanced UI Components

**File: `components/ui/Island.tsx`**

```typescript
import cn from 'clsx'
import React from 'react'

interface IIslandProps {
  children: React.ReactNode
  className?: string
  padding?: 'none' | 'sm' | 'md' | 'lg'
}

export const Island: React.FC<IIslandProps> = ({
  children,
  className,
  padding = 'md',
}) => {
  const paddingClasses = {
    none: '',
    sm: 'p-2',
    md: 'p-3',
    lg: 'p-4',
  }

  return (
    <div
      className={cn(
        'rounded-lg bg-white/90 backdrop-blur-sm',
        'border border-gray-200/50',
        'shadow-lg shadow-gray-900/10',
        'ring-1 ring-black/5',
        paddingClasses[padding],
        className,
      )}
    >
      {children}
    </div>
  )
}
```

**File: `components/ui/ToolButton.tsx`** (Enhanced version)

```typescript
import cn from 'clsx'
import React from 'react'

interface IToolButtonProps {
  icon: React.ComponentType<{ className?: string }>
  label: string
  isActive?: boolean
  onClick: () => void
  shortcut?: string
  disabled?: boolean
  variant?: 'primary' | 'secondary' | 'danger'
  size?: 'small' | 'medium' | 'large'
  isLoading?: boolean
  showKeyBinding?: boolean
  'aria-label'?: string
  'aria-keyshortcuts'?: string
}

export const ToolButton: React.FC<IToolButtonProps> = ({
  icon: Icon,
  label,
  isActive = false,
  onClick,
  shortcut,
  disabled = false,
  variant = 'primary',
  size = 'medium',
  isLoading = false,
  showKeyBinding = true,
  'aria-label': ariaLabel,
  'aria-keyshortcuts': ariaKeyshortcuts,
}) => {
  const sizeClasses = {
    small: 'h-8 w-8',
    medium: 'h-10 w-10',
    large: 'h-12 w-12',
  }

  const iconSizes = {
    small: 'h-4 w-4',
    medium: 'h-5 w-5',
    large: 'h-6 w-6',
  }

  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled || isLoading}
      aria-label={ariaLabel || label}
      aria-keyshortcuts={ariaKeyshortcuts || shortcut}
      aria-pressed={isActive}
      className={cn(
        'group relative flex items-center justify-center rounded-lg',
        'transition-all duration-200 ease-out',
        'focus:outline-none focus:ring-2 focus:ring-blue-500/40 focus:ring-offset-2',
        'active:scale-95',
        sizeClasses[size],
        {
          // Active states with enhanced styling
          'bg-blue-500 text-white shadow-md shadow-blue-500/25 ring-1 ring-blue-500/50': 
            isActive && variant === 'primary',
          'bg-gray-800 text-white shadow-md shadow-gray-800/25 ring-1 ring-gray-800/50': 
            isActive && variant === 'secondary',
          'bg-red-500 text-white shadow-md shadow-red-500/25 ring-1 ring-red-500/50': 
            isActive && variant === 'danger',

          // Inactive states with better hover effects
          'text-gray-700 hover:bg-gray-100 hover:shadow-sm hover:ring-1 hover:ring-gray-200': 
            !isActive && !disabled && variant === 'primary',
          'text-gray-600 hover:bg-gray-50 hover:shadow-sm': 
            !isActive && !disabled && variant === 'secondary',
          'text-red-600 hover:bg-red-50 hover:shadow-sm hover:ring-1 hover:ring-red-200': 
            !isActive && !disabled && variant === 'danger',

          // Disabled state
          'text-gray-400 cursor-not-allowed opacity-50': disabled,
          'opacity-75': isLoading,
        },
      )}
      title={shortcut ? `${label} (${shortcut})` : label}
    >
      {isLoading ? (
        <div
          className={cn(
            'animate-spin rounded-full border-2 border-gray-300 border-t-blue-500',
            iconSizes[size],
          )}
        />
      ) : (
        <Icon className={iconSizes[size]} />
      )}

      {/* Enhanced Tooltip with keyboard shortcut */}
      <div className="absolute left-12 z-50 hidden group-hover:block">
        <div className="rounded-md bg-gray-900/95 backdrop-blur-sm px-3 py-2 text-sm text-white whitespace-nowrap shadow-xl border border-gray-700/50">
          <div className="font-medium">{label}</div>
          {shortcut && showKeyBinding && (
            <div className="text-xs text-gray-300 mt-1 font-mono">
              {shortcut}
            </div>
          )}
        </div>
        <div className="absolute left-0 top-1/2 -translate-y-1/2 -translate-x-1 border-4 border-transparent border-r-gray-900/95" />
      </div>

      {/* Keyboard shortcut badge */}
      {shortcut && showKeyBinding && isActive && (
        <span className="absolute -bottom-1 -right-1 bg-white text-gray-700 text-xs px-1 rounded border border-gray-200 shadow-sm font-mono">
          {shortcut.split('+').pop()}
        </span>
      )}
    </button>
  )
}
```

**File: `components/ui/Dropdown.tsx`** (New component)

```typescript
import cn from 'clsx'
import React, { useState, useRef, useEffect } from 'react'

interface IDropdownItem {
  id: string
  label: string
  icon?: React.ComponentType<{ className?: string }>
  shortcut?: string
  onClick: () => void
  disabled?: boolean
}

interface IDropdownProps {
  trigger: React.ReactNode
  items: IDropdownItem[]
  placement?: 'bottom' | 'top' | 'left' | 'right'
  align?: 'start' | 'center' | 'end'
}

export const Dropdown: React.FC<IDropdownProps> = ({
  trigger,
  items,
  placement = 'bottom',
  align = 'center',
}) => {
  const [isOpen, setIsOpen] = useState(false)
  const dropdownRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsOpen(false)
      }
    }

    if (isOpen) {
      document.addEventListener('mousedown', handleClickOutside)
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [isOpen])

  const placementClasses = {
    bottom: 'top-full mt-2',
    top: 'bottom-full mb-2',
    left: 'right-full mr-2',
    right: 'left-full ml-2',
  }

  const alignClasses = {
    start: placement === 'bottom' || placement === 'top' ? 'left-0' : 'top-0',
    center: placement === 'bottom' || placement === 'top' ? 'left-1/2 -translate-x-1/2' : 'top-1/2 -translate-y-1/2',
    end: placement === 'bottom' || placement === 'top' ? 'right-0' : 'bottom-0',
  }

  return (
    <div ref={dropdownRef} className="relative">
      <div onClick={() => setIsOpen(!isOpen)}>
        {trigger}
      </div>

      {isOpen && (
        <div
          className={cn(
            'absolute z-50 min-w-48',
            'rounded-lg bg-white/95 backdrop-blur-sm',
            'border border-gray-200/50 shadow-xl',
            'ring-1 ring-black/5',
            'py-1',
            placementClasses[placement],
            alignClasses[align],
          )}
        >
          {items.map((item) => (
            <button
              key={item.id}
              onClick={() => {
                item.onClick()
                setIsOpen(false)
              }}
              disabled={item.disabled}
              className={cn(
                'w-full flex items-center gap-3 px-3 py-2 text-left',
                'text-sm text-gray-700',
                'hover:bg-gray-100 hover:text-gray-900',
                'disabled:text-gray-400 disabled:cursor-not-allowed',
                'transition-colors duration-150',
              )}
            >
              {item.icon && <item.icon className="h-4 w-4" />}
              <span className="flex-1">{item.label}</span>
              {item.shortcut && (
                <span className="text-xs text-gray-500 font-mono">
                  {item.shortcut}
                </span>
              )}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
```

### 6.2 Enhanced MainToolbar

**File: `components/tools/MainToolbar.tsx`** (Enhanced version)

```typescript
import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useDrawboardContext } from '../../context'
import { ToolMode } from '../../context/types'
import { getToolNumericShortcut, getToolShortcut } from '../../hooks/useKeyboardShortcuts'
import {
  ArrowIcon,
  CircleIcon,
  DiamondIcon,
  EraserIcon,
  FrameIcon,
  FreedrawIcon,
  ImageIcon,
  LaserIcon,
  LassoIcon,
  LineIcon,
  LockIcon,
  PanIcon,
  RectangleIcon,
  SelectIcon,
  TextIcon,
  UnlockIcon,
  MoreHorizontalIcon,
} from '../icons/MaterialIcons'
import { HintViewer, Island, ToolButton, ToolSeparator } from '../ui'
import { Dropdown } from '../ui/Dropdown'

interface IToolDefinition {
  mode: ToolMode
  icon: React.ComponentType<{ className?: string }>
  label: string
  shortcut?: string
  numericKey?: string
}

interface IToolGroup {
  id: string
  label: string
  tools: IToolDefinition[]
  priority: 'primary' | 'secondary'
}

const createToolDefinition = (
  mode: ToolMode,
  icon: React.ComponentType<{ className?: string }>,
  label: string,
): IToolDefinition => ({
  mode,
  icon,
  label,
  shortcut: getToolShortcut(mode),
  numericKey: getToolNumericShortcut(mode),
})

// Primary tools - always visible
const PRIMARY_TOOL_GROUPS: IToolGroup[] = [
  {
    id: 'selection',
    label: 'Selection',
    priority: 'primary',
    tools: [
      createToolDefinition(ToolMode.SELECT, SelectIcon, 'Select'),
      createToolDefinition(ToolMode.PAN, PanIcon, 'Hand'),
    ],
  },
  {
    id: 'shapes',
    label: 'Shapes',
    priority: 'primary',
    tools: [
      createToolDefinition(ToolMode.RECTANGLE, RectangleIcon, 'Rectangle'),
      createToolDefinition(ToolMode.DIAMOND, DiamondIcon, 'Diamond'),
      createToolDefinition(ToolMode.CIRCLE, CircleIcon, 'Ellipse'),
    ],
  },
  {
    id: 'drawing',
    label: 'Drawing',
    priority: 'primary',
    tools: [
      createToolDefinition(ToolMode.ARROW, ArrowIcon, 'Arrow'),
      createToolDefinition(ToolMode.LINE, LineIcon, 'Line'),
      createToolDefinition(ToolMode.FREEDRAW, FreedrawIcon, 'Draw'),
    ],
  },
  {
    id: 'content',
    label: 'Content',
    priority: 'primary',
    tools: [
      createToolDefinition(ToolMode.TEXT, TextIcon, 'Text'),
    ],
  },
]

// Secondary tools - in dropdown
const SECONDARY_TOOLS: IToolDefinition[] = [
  createToolDefinition(ToolMode.ERASER, EraserIcon, 'Eraser'),
  createToolDefinition(ToolMode.FRAME, FrameIcon, 'Frame'),
  createToolDefinition(ToolMode.LASER, LaserIcon, 'Laser Pointer'),
  createToolDefinition(ToolMode.LASSO, LassoIcon, 'Lasso Select'),
  createToolDefinition(ToolMode.IMAGE, ImageIcon, 'Image'),
]

const formatShortcut = (tool: IToolDefinition): string => {
  if (tool.numericKey && tool.shortcut) {
    return `${tool.shortcut.toUpperCase()} or ${tool.numericKey}`
  }
  return tool.shortcut?.toUpperCase() || ''
}

export const MainToolbar: React.FC = () => {
  const { viewmodel } = useDrawboardContext()
  const appState = useStateValue(viewmodel.appState$)

  const secondaryToolItems = SECONDARY_TOOLS.map(tool => ({
    id: tool.mode.toString(),
    label: tool.label,
    icon: tool.icon,
    shortcut: formatShortcut(tool),
    onClick: () => viewmodel.setTool(tool.mode),
  }))

  const hasActiveSecondaryTool = SECONDARY_TOOLS.some(
    tool => appState.selectedTool === tool.mode
  )

  return (
    <Island className="flex flex-row items-center gap-1" padding="sm">
      {/* Hint Viewer */}
      <HintViewer variant="compact" className="mr-2" />

      {/* Tool Lock Button */}
      <ToolButton
        icon={appState.toolLocked ? LockIcon : UnlockIcon}
        label={appState.toolLocked ? 'Unlock Tools' : 'Lock Tools'}
        shortcut="Shift+L"
        isActive={appState.toolLocked}
        onClick={() => viewmodel.toggleToolLock()}
        variant="secondary"
        size="small"
        aria-label={appState.toolLocked ? 'Unlock tool selection' : 'Lock tool selection'}
      />

      <ToolSeparator orientation="vertical" />

      {/* Primary Tool Groups */}
      {PRIMARY_TOOL_GROUPS.map((group, groupIndex) => (
        <React.Fragment key={group.id}>
          {groupIndex > 0 && <ToolSeparator orientation="vertical" />}

          <div className="flex gap-1" role="group" aria-label={group.label}>
            {group.tools.map(tool => (
              <ToolButton
                key={tool.mode}
                icon={tool.icon}
                label={tool.label}
                shortcut={formatShortcut(tool)}
                isActive={appState.selectedTool === tool.mode}
                onClick={() => viewmodel.setTool(tool.mode)}
                aria-label={`${tool.label} tool`}
                aria-keyshortcuts={formatShortcut(tool)}
              />
            ))}
          </div>
        </React.Fragment>
      ))}

      {/* Secondary Tools Dropdown */}
      <ToolSeparator orientation="vertical" />
      
      <Dropdown
        trigger={
          <ToolButton
            icon={MoreHorizontalIcon}
            label="More Tools"
            isActive={hasActiveSecondaryTool}
            onClick={() => {}} // Dropdown handles the click
            variant="secondary"
            aria-label="Open more tools menu"
          />
        }
        items={secondaryToolItems}
        placement="bottom"
        align="center"
      />
    </Island>
  )
}
```

## Dependencies

```json
{
  "dependencies": {
    "react": "^18.2.0",
    "roughjs": "^4.6.4",
    "@guanghechen/react-viewmodel": "^5.1.0",
    "tailwindcss": "^3.3.0",
    "uuid": "^9.0.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.0",
    "@types/roughjs": "^4.6.0",
    "@types/uuid": "^9.0.0",
    "typescript": "^5.0.0"
  }
}
```

## Future Enhancements

1. **Selection Tool**: Multi-select with bounding box
2. **Text Elements**: Add text support with font options
3. **Undo/Redo**: Command pattern for history management
4. **Collaboration**: Real-time collaborative editing
5. **More Shapes**: Polygons, freehand drawing
6. **Import/Export**: SVG export, image import
7. **Keyboard Shortcuts**: Comprehensive shortcuts
8. **Touch Support**: Mobile-friendly interactions
9. **Rulers**: Measurement rulers along edges
10. **Snap to Grid**: Optional grid snapping

This implementation provides a solid foundation for a personal canvas drawing tool with the hand-drawn aesthetic of Excalidraw while maintaining clean architecture and extensibility.
