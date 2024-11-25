
## Widgets

```typescript
interface IWidget {
  readonly uuid: string
  readonly status: 'closed' | 'hidden' | 'visible'
  readonly hide: () => void
  readonly show: () => void
  readonly close: () => void
}
```


* Call `.close()` when the widget is out of the scope of the widget history.
* Call `.hide()` when press `q` or change to other widget.

* Search

  - Support to keep the data to implemented the `hide` / `show` / `close` methods.


## Color scheme

1. catppuccin
