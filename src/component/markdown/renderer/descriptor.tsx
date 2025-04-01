import React from 'react'
import {
  AdmonitionCautionIcon,
  AdmonitionDangerIcon,
  AdmonitionHintIcon,
  AdmonitionInfoIcon,
  AdmonitionNoteIcon,
  AdmonitionTipIcon,
} from './icons'

export interface AdmonitionDescriptor {
  type: string
  title: string
  icon: React.ReactElement
  bgClass: string
  borderClass: string
  textClass: string
}

/**
 * Get the appropriate descriptor for an admonition based on its keyword
 */
export function getAdmonitionDescriptor(keyword = 'note'): AdmonitionDescriptor {
  const type = keyword.trim().toLowerCase()

  switch (type) {
    case 'hint':
      return {
        type: 'hint',
        title: 'HINT',
        icon: <AdmonitionHintIcon />,
        bgClass: 'bg-purple-50',
        borderClass: 'border-purple-400',
        textClass: 'text-purple-700',
      }
    case 'note':
    case 'default':
    case '':
      return {
        type: 'note',
        title: 'NOTE',
        icon: <AdmonitionNoteIcon />,
        bgClass: 'bg-gray-50',
        borderClass: 'border-gray-400',
        textClass: 'text-gray-700',
      }
    case 'info':
    case 'important':
      return {
        type: 'info',
        title: 'INFO',
        icon: <AdmonitionInfoIcon />,
        bgClass: 'bg-blue-50',
        borderClass: 'border-blue-400',
        textClass: 'text-blue-700',
      }
    case 'tip':
    case 'success':
      return {
        type: 'tip',
        title: 'TIP',
        icon: <AdmonitionTipIcon />,
        bgClass: 'bg-green-50',
        borderClass: 'border-green-400',
        textClass: 'text-green-700',
      }
    case 'caution':
    case 'warning':
      return {
        type: 'caution',
        title: 'CAUTION',
        icon: <AdmonitionCautionIcon />,
        bgClass: 'bg-amber-50',
        borderClass: 'border-amber-400',
        textClass: 'text-amber-700',
      }
    case 'danger':
    case 'error':
      return {
        type: 'danger',
        title: 'DANGER',
        icon: <AdmonitionDangerIcon />,
        bgClass: 'bg-red-50',
        borderClass: 'border-red-400',
        textClass: 'text-red-700',
      }
    default:
      // For custom keywords, use a basic style with the keyword as title
      return {
        type,
        title: type.toUpperCase(),
        icon: <React.Fragment />,
        bgClass: 'bg-gray-50',
        borderClass: 'border-gray-400',
        textClass: 'text-gray-700',
      }
  }
}

