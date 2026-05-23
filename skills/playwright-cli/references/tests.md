# Playwright Tests With playwright-cli

## Running Tests

Use the project's existing package scripts when present. Avoid opening the HTML report in agent runs. Prefer `npx --no-install` for direct Playwright CLI calls so missing dependencies fail instead of downloading packages implicitly.

```bash
PLAYWRIGHT_HTML_OPEN=never npm run test:e2e
PLAYWRIGHT_HTML_OPEN=never npx --no-install playwright test
```

## Debugging Failing Tests

Use Playwright's CLI debug mode, then attach `playwright-cli` to the paused browser session.

Run the test in the background or in a long-running command session and wait until it prints debugging instructions with a `tw-...` session name:

```bash
PLAYWRIGHT_HTML_OPEN=never npx --no-install playwright test tests/example.spec.ts --debug=cli
```

Attach to the paused page:

```bash
playwright-cli attach tw-abcdef
playwright-cli snapshot
```

Keep the test process running while inspecting the page. After you identify and fix the issue, stop the debug process and rerun the test normally.

## Generating Test Code

Every `playwright-cli` action prints corresponding Playwright TypeScript when possible. Use generated code as a draft, then replace fragile selectors with semantic locators and add assertions manually.

```bash
playwright-cli open https://example.com/login
playwright-cli snapshot
playwright-cli fill e1 "user@example.com"
playwright-cli fill e2 "example-pass"
playwright-cli click e3
```

Prefer robust locators:

```typescript
await page.getByRole('textbox', { name: 'Email' }).fill('user@example.com');
await page.getByRole('button', { name: 'Sign In' }).click();
```

Add assertions with Playwright matchers:

```typescript
await expect(page).toHaveURL(/dashboard/);
await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
```

## Planning New E2E Coverage

For a non-trivial feature, first create or identify a seed state: navigation, login, feature flags, and any setup required before scenarios begin. Then explore with `playwright-cli`, write a short spec plan, and generate tests from that plan.

Do not bootstrap Playwright with `npm init playwright@latest` without user approval.
