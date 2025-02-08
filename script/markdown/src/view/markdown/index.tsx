import { css } from '@emotion/css'
import React from 'react'
import { useFileResult } from '@/hook/useFileResult'

export const MarkdownView: React.FC = () => {
  const [filepath, setFilepath] = React.useState<string>('')
  const { loading, text, url, error } = useFileResult(filepath)
  const inputRef = React.useRef<HTMLInputElement>(null)

  const onSubmit = React.useCallback(() => {
    if (inputRef.current) {
      setFilepath(inputRef.current.value)
    }
  }, [])

  return (
    <div className={classes.container}>
      <div className={classes.inputContainer}>
        <input
          className={classes.input}
          ref={inputRef}
          type="text"
          onKeyDown={e => {
            if (e.key === 'Enter') onSubmit()
          }}
        />
        <button className={classes.button} onClick={onSubmit}>
          Load
        </button>
      </div>
      <div className={classes.preview}>
        <span>loading: {String(loading)}</span>
        <span>text: {String(text)}</span>
        <span>url: {String(url)}</span>
        <span>error: {String(error)}</span>
      </div>
    </div>
  )
}

const classes = {
  container: css({
    display: 'flex',
    flexDirection: 'column',
    width: '100%',
    height: '100%',
    padding: '20px',
    boxSizing: 'border-box',
  }),
  inputContainer: css({
    display: 'flex',
    alignItems: 'center',
    marginBottom: '20px',
  }),
  input: css({
    flex: 1,
    padding: '10px',
    borderRadius: '4px',
    border: '1px solid #ccc',
    fontSize: '16px',
    marginRight: '10px',
    outline: 'none',
    transition: 'border-color 0.3s',
    '&:focus': {
      borderColor: '#007BFF',
    },
  }),
  button: css({
    padding: '10px 20px',
    borderRadius: '4px',
    border: 'none',
    backgroundColor: '#007BFF',
    color: '#fff',
    fontSize: '16px',
    cursor: 'pointer',
    transition: 'background-color 0.3s',
    '&:hover': {
      backgroundColor: '#0056b3',
    },
  }),
  preview: css({
    display: 'flex',
    flexDirection: 'column',
  }),
}
