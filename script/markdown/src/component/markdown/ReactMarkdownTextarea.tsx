'use client';

import { css } from '@emotion/css';
import cn from 'clsx';
import React from 'react';
import { useEventCallback } from '@guanghechen/react-hooks';

interface IProps {
  content: string;
  setContent: (nextContent: string) => void;
  autoFocus?: boolean;
  placeholder?: string;
  className?: string;
  textareaClassName?: string;
}

export const ReactMarkdownTextarea: React.FC<IProps> = (props) => {
  const {
    content,
    setContent,
    autoFocus,
    placeholder,
    className,
    textareaClassName,
  } = props;

  const [visible, setVisible] = React.useState<boolean>(false);
  const textareaRef = React.useRef<HTMLTextAreaElement>(null);

  const onResize = useEventCallback(() => {
    const textarea: HTMLTextAreaElement | null = textareaRef.current;
    if (textarea) {
      textarea.style.height = '0px';
      const height: number = textarea.scrollHeight + 4;
      textarea.style.height = height + 'px';
      setVisible(true);
    }
  });

  const onContentChange = React.useCallback(
    (e: React.ChangeEvent<HTMLTextAreaElement>) => {
      const nextContent: string = e.target.value;
      setContent(nextContent);
    },
    [setContent],
  );

  React.useEffect(() => {
    onResize();
  }, [content, onResize]);

  React.useEffect(() => {
    let timeout: ReturnType<typeof setTimeout> | null = setTimeout(() => {
      timeout = null;
      onResize();

      if (visible && autoFocus) {
        const textarea = textareaRef.current;
        if (textarea) {
          textarea.focus();
        }
      }
    }, 50);

    return () => {
      if (timeout !== null) {
        clearTimeout(timeout);
        timeout = null;
      }
    };
  }, [onResize, autoFocus, visible]);

  return (
    <div className={className}>
      <textarea
        ref={textareaRef}
        className={cn(
          classes.textarea,
          'm-0 box-border font-mono w-full resize-none border border-transparent p-2 outline-none focus:border-slate-500 focus:outline-none',
          textareaClassName,
          { invisible: !visible },
        )}
        placeholder={placeholder}
        autoFocus={autoFocus}
        value={content}
        onChange={onContentChange}
      />
    </div>
  );
};

const classes = {
  textarea: css({
    backgroundColor: 'unset',
  }),
};
