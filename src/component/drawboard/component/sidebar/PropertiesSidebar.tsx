import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useDrawboardContext } from '../../context'
import { Field, Section } from '../ui/Section'
import { Sidebar } from '../ui/Sidebar'

const COLOR_PRESETS = [
  '#000000',
  '#ffffff',
  '#e03131',
  '#fd7e14',
  '#fab005',
  '#82c91e',
  '#40c057',
  '#15aabf',
  '#339af0',
  '#7950f2',
  '#f783ac',
  '#868e96',
]

export const PropertiesSidebar: React.FC = () => {
  const { viewmodel } = useDrawboardContext()
  const appState = useStateValue(viewmodel.appState$)
  const viewData = useStateValue(viewmodel.viewData$)

  const handleStrokeColorChange = (color: string): void => {
    viewmodel.setStrokeColor(color)
  }

  const handleFillColorChange = (color: string): void => {
    viewmodel.setFillColor(color)
  }

  const handleStrokeWidthChange = (width: number): void => {
    viewmodel.setStrokeWidth(width)
  }

  const handleOpacityChange = (opacity: number): void => {
    viewmodel.setOpacity(opacity)
  }

  return (
    <Sidebar side="right" title="Properties" defaultOpen={false} width={320}>
      {/* Stroke Properties */}
      <Section title="Stroke">
        <Field label="Color">
          <div className="space-y-2">
            <input
              type="color"
              value={appState.currentItemStrokeColor}
              onChange={e => handleStrokeColorChange(e.target.value)}
              className="h-8 w-full rounded border border-gray-300"
            />
            <div className="grid grid-cols-6 gap-1">
              {COLOR_PRESETS.map(color => (
                <button
                  key={color}
                  onClick={() => handleStrokeColorChange(color)}
                  className={`h-6 w-6 rounded border-2 ${
                    appState.currentItemStrokeColor === color
                      ? 'border-blue-500'
                      : 'border-gray-300'
                  }`}
                  style={{ backgroundColor: color }}
                />
              ))}
            </div>
          </div>
        </Field>

        <Field label="Width">
          <div className="space-y-2">
            <input
              type="range"
              min="1"
              max="20"
              value={appState.currentItemStrokeWidth}
              onChange={e => handleStrokeWidthChange(parseInt(e.target.value))}
              className="w-full"
            />
            <div className="text-xs text-gray-500 text-center">
              {appState.currentItemStrokeWidth}px
            </div>
          </div>
        </Field>
      </Section>

      {/* Fill Properties */}
      <Section title="Fill">
        <Field label="Color">
          <div className="space-y-2">
            <input
              type="color"
              value={appState.currentItemBackgroundColor}
              onChange={e => handleFillColorChange(e.target.value)}
              className="h-8 w-full rounded border border-gray-300"
            />
            <div className="grid grid-cols-6 gap-1">
              {COLOR_PRESETS.map(color => (
                <button
                  key={color}
                  onClick={() => handleFillColorChange(color)}
                  className={`h-6 w-6 rounded border-2 ${
                    appState.currentItemBackgroundColor === color
                      ? 'border-blue-500'
                      : 'border-gray-300'
                  }`}
                  style={{ backgroundColor: color }}
                />
              ))}
            </div>
            <button
              onClick={() => handleFillColorChange('transparent')}
              className={`w-full h-6 rounded border-2 bg-gradient-to-br from-red-500 to-transparent ${
                appState.currentItemBackgroundColor === 'transparent'
                  ? 'border-blue-500'
                  : 'border-gray-300'
              }`}
            >
              <span className="text-xs text-red-600 font-medium">None</span>
            </button>
          </div>
        </Field>
      </Section>

      {/* General Properties */}
      <Section title="General">
        <Field label="Opacity">
          <div className="space-y-2">
            <input
              type="range"
              min="0"
              max="100"
              value={appState.currentItemOpacity}
              onChange={e => handleOpacityChange(parseInt(e.target.value) / 100)}
              className="w-full"
            />
            <div className="text-xs text-gray-500 text-center">
              {Math.round(appState.currentItemOpacity)}%
            </div>
          </div>
        </Field>
      </Section>

      {/* View Properties */}
      <Section title="View" collapsible={true} defaultOpen={false}>
        <Field label="Grid Size">
          <div className="space-y-2">
            <input
              type="range"
              min="10"
              max="100"
              value={viewData.gridSize}
              onChange={e => viewmodel.setGridSize(parseInt(e.target.value))}
              className="w-full"
            />
            <div className="text-xs text-gray-500 text-center">{viewData.gridSize}px</div>
          </div>
        </Field>

        <Field label="Background">
          <select
            value={appState.viewBackgroundColor}
            onChange={e => viewmodel.setBackgroundColor(e.target.value)}
            className="w-full rounded border border-gray-300 px-2 py-1 text-sm"
          >
            <option value="#ffffff">White</option>
            <option value="#f8f9fa">Light Gray</option>
            <option value="#1a1a1a">Dark</option>
            <option value="#000000">Black</option>
          </select>
        </Field>
      </Section>
    </Sidebar>
  )
}
