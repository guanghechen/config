# Advanced Playwright CLI Tasks

## Element Inspection

Snapshots may omit DOM attributes. Use `eval` when you need `id`, classes, `data-*`, ARIA labels, computed styles, or text not shown in the snapshot.

```bash
playwright-cli snapshot
playwright-cli eval "el => el.id" e7
playwright-cli eval "el => el.className" e7
playwright-cli eval "el => el.getAttribute('data-testid')" e7
playwright-cli eval "el => getComputedStyle(el).display" e7
```

Generate a robust Playwright locator when converting exploration into tests:

```bash
playwright-cli generate-locator e7 --raw
```

## Custom Playwright Code

Use `run-code` for actions not covered by first-class commands. The code must be a single function expression. `import`, `export`, and `require` are not supported inside the snippet.

```bash
playwright-cli run-code "async page => await page.title()"
playwright-cli run-code --filename=./script.js
```

Useful patterns:

```bash
playwright-cli run-code "async page => {
  await page.context().grantPermissions(['geolocation']);
  await page.context().setGeolocation({ latitude: 37.7749, longitude: -122.4194 });
}"

playwright-cli run-code "async page => await page.waitForLoadState('networkidle')"

playwright-cli run-code "async page => {
  const [download] = await Promise.all([
    page.waitForEvent('download'),
    page.click('a.download-link')
  ]);
  await download.saveAs('./downloaded-file.pdf');
  return download.suggestedFilename();
}"
```

## Attach To Existing Browsers

Attach when the user needs a real browser session, an extension, or an external Chrome/Edge instance. Detach leaves the external browser running.

```bash
playwright-cli attach --extension=chrome
playwright-cli attach --cdp=chrome
playwright-cli attach --cdp=msedge
playwright-cli attach --cdp=http://localhost:9222
playwright-cli detach
```

## Storage

Only save or load auth state when explicitly requested.

```bash
playwright-cli state-save auth.json
playwright-cli state-load auth.json
playwright-cli cookie-list --domain=example.com
playwright-cli cookie-get <cookie-name>
playwright-cli localstorage-list
playwright-cli localstorage-get theme
playwright-cli sessionstorage-list
```

## Request Mocking

Use `route` for simple mocks and `run-code` for conditional behavior.

```bash
playwright-cli route "**/*.jpg" --status=404
playwright-cli route "**/api/users" --body='[{"id":1,"name":"Alice"}]' --content-type=application/json
playwright-cli route-list
playwright-cli unroute "**/*.jpg"
playwright-cli unroute
```

Conditional mock:

```bash
playwright-cli run-code "async page => {
  await page.route('**/api/login', route => {
    const body = route.request().postDataJSON();
    if (body.username === 'admin') {
      route.fulfill({ body: JSON.stringify({ status: 'ok' }) });
    } else {
      route.fulfill({ status: 401, body: JSON.stringify({ error: 'Invalid' }) });
    }
  });
}"
```

## Tracing, Video, And Review

Tracing is best for debugging. Video is best for demos or evidence. Screenshots are best for a single visual state.

```bash
playwright-cli tracing-start
playwright-cli tracing-stop

playwright-cli video-start demo.webm
playwright-cli video-chapter "Checkout" --description="Submitting the form" --duration=2000
playwright-cli video-stop

playwright-cli show
playwright-cli show --annotate
```

For UI review, `show --annotate` can let the user annotate the page; use it only when a human-in-the-loop visual review is useful.
