export const layoutTheme: string = `
  .adthrive-sticky.adthrive-footer,
  .adthrive-footer-message,
  [id^="AdThrive_Footer_"],
  html #main.wide > article > .adthrive {
    display: none !important;
  }

  html #pageheader,
  html #main.wide > article > .box > header,
  html #main.wide > aside,
  html #pagefooter {
    display: none;
  }

  html,
  html body {
    width: 100%;
    height: 100%;
    min-width: 0;
    margin: 0;
    overflow: clip;
  }

  html .main-wrapper {
    height: 100dvh;
    margin: 0;
    overflow: clip;
  }

  html .main-wrapper,
  html #content,
  html #main-content,
  html #main.wide,
  html #main.wide > article,
  html #main.wide > article > .box,
  html #main.wide > article > .box > .boxcontent,
  html astro-island[component-export="FinderApp"] > div {
    box-sizing: border-box;
    display: flex;
    flex-direction: column;
    flex: 1 1 0;
    min-width: 0;
    min-height: 0;
  }

  html #content {
    width: 100%;
    max-width: none;
    margin: 0;
  }

  html #main-content {
    margin: 0;
    padding: 8px;
  }

  html #main.wide,
  html #main.wide > article > .box {
    width: 100%;
    max-width: none;
    margin: 0;
  }

  html #main.wide > article > .box > .boxcontent {
    margin: 8px;
  }

  html astro-island[component-export="FinderApp"] > div > div {
    flex-shrink: 0;
  }

  html astro-island[component-export="FinderApp"] > div > div:has(> .fancy-box > .fancy-row) {
    display: flex;
    flex-direction: column;
    flex-shrink: 1;
    min-height: 0;
    overflow: hidden auto;
  }

  html astro-island[component-export="FinderApp"] > div > div > .fancy-box:has(> .fancy-row) {
    flex-shrink: 0;
  }

  html astro-island[component-export="FinderApp"] .fancy-row:has(input[name="seed"]) {
    justify-self: end;
    max-width: 100%;
  }

  html astro-island[component-export="FinderApp"] .fancy-row:has(input[name="seed"]) > .fancy-inputs {
    margin-inline-end: 0;
  }

  html astro-island[component-export="FinderApp"] .fancy-row:has(> .fancy-inputs > select) {
    position: relative;
    display: block;
    min-width: 0;
    margin: 0;
    padding: 0;
  }

  html astro-island[component-export="FinderApp"] .fancy-row:has(> .fancy-inputs > select) > .fancy-size {
    position: absolute;
    width: 1px;
    height: 1px;
    margin: -1px;
    padding: 0;
    overflow: hidden;
    clip-path: inset(50%);
    white-space: nowrap;
  }

  html astro-island[component-export="FinderApp"] .fancy-row:has(> .fancy-inputs > select) > .fancy-inputs {
    margin: 0;
  }

  html astro-island[component-export="FinderApp"] .fancy-row select {
    box-sizing: border-box;
    appearance: none;
    height: 30px;
    max-width: none;
    margin: 0;
    padding: 0 30px 0 10px;
    border: 1px solid #a8bdcf;
    border-radius: 6px;
    outline: none;
    background-color: #f8fbff;
    background-image: linear-gradient(45deg, transparent 50%, #60778c 50%),
      linear-gradient(135deg, #60778c 50%, transparent 50%);
    background-position: calc(100% - 14px) 50%, calc(100% - 10px) 50%;
    background-size: 4px 4px;
    background-repeat: no-repeat;
    color: #314b62;
    box-shadow: 0 1px 2px rgb(49 75 98 / 8%);
    cursor: pointer;
  }

  html astro-island[component-export="FinderApp"] .fancy-row select:hover {
    border-color: #789bb9;
    background-color: #fff;
  }

  html astro-island[component-export="FinderApp"] .fancy-row select:focus-visible {
    border-color: #4e89b6;
    outline: 2px solid #7aafd6;
    outline-offset: 1px;
  }

  html astro-island[component-export="FinderApp"] [data-testid="platform"] {
    width: 15rem;
  }

  html astro-island[component-export="FinderApp"] [data-testid="dimension-select"] {
    width: 10rem;
  }

  /* Let the native SimpleBar list scroll instead of displacing the map. */
  html astro-island[component-export="FinderApp"] div:has(> [data-testid="feature-toggles-expand"]) {
    flex-shrink: 1;
  }

  html astro-island[component-export="FinderApp"] div:has(> [data-testid="feature-toggles-expand"]) > .absolute {
    z-index: 1;
  }

  html astro-island[component-export="FinderApp"] > div > div:has(> div > div > .ol-viewport) {
    flex: 1 1 0;
    min-height: clamp(7rem, 20dvh, 8rem);
    margin-block: 8px 0;
  }

  html astro-island[component-export="FinderApp"] .map-controls-flex > .fancy-box {
    min-width: 0;
  }

  html astro-island[component-export="FinderApp"] .map-controls-flex {
    max-height: 40dvh;
    overflow: hidden auto;
  }

  /* Match the layer of Chunkbase's important height utility. */
  @layer utilities {
    html astro-island[component-export="FinderApp"] div:has(> div > .ol-viewport) {
      height: 100% !important;
      min-height: 0 !important;
      max-height: none !important;
      margin-top: 0 !important;
    }
  }

  html.theater-map astro-island[component-export="FinderApp"] > div > div:has(> div > div > .ol-viewport) {
    position: fixed;
    inset: 0;
    z-index: 10;
    width: 100%;
    height: 100dvh;
    margin: 0;
  }

  html.theater-map astro-island[component-export="FinderApp"] div:has(> div > .ol-viewport) {
    border-width: 0;
  }

  @media (max-width: 640px) {
    html #main-content {
      padding: 4px;
    }

    html #main.wide > article > .box > .boxcontent {
      margin: 6px;
    }

    html astro-island[component-export="FinderApp"] .fancy-box {
      padding: 3px 6px;
    }

    html astro-island[component-export="FinderApp"] > div > div > .fancy-box:has(> .fancy-row) {
      display: grid;
      grid-template-columns: minmax(0, 3fr) minmax(0, 2fr);
      align-items: center;
      gap: 6px 8px;
    }

    html astro-island[component-export="FinderApp"] .fancy-row:first-child {
      grid-column: 1 / -1;
    }

    html astro-island[component-export="FinderApp"] .fancy-row {
      display: grid;
      grid-template-columns: 72px minmax(0, 1fr);
      align-items: center;
      gap: 4px;
      padding-block: 2px;
    }

    html astro-island[component-export="FinderApp"] .fancy-row > .fancy-size,
    html astro-island[component-export="FinderApp"] .fancy-row > .fancy-inputs {
      width: auto;
      min-width: 0;
      margin: 0;
    }

    html astro-island[component-export="FinderApp"] .fancy-inputs {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }

    html astro-island[component-export="FinderApp"] .fancy-inputs > :is(select, div:has(> [role="group"])) {
      width: 100%;
      max-width: none;
      margin-inline: 0;
    }

    html astro-island[component-export="FinderApp"] .fancy-inputs-section {
      display: flex;
      justify-content: flex-end;
      gap: 4px;
    }

    html astro-island[component-export="FinderApp"] .fancy-inputs-section > .gh-button {
      margin: 0;
    }
  }

  @media (max-height: 700px) {
    html #main-content {
      padding: 2px;
    }

    html #main.wide > article > .box > .boxcontent {
      margin: 4px;
    }

    html astro-island[component-export="FinderApp"] .fancy-box {
      padding: 1px 4px;
    }

    html astro-island[component-export="FinderApp"] .fancy-row {
      padding-block: 0;
    }

    html astro-island[component-export="FinderApp"] .map-controls-flex {
      margin-top: 6px;
    }

    html astro-island[component-export="FinderApp"] div:has(> [data-testid="feature-toggles-expand"]) {
      margin-top: 8px;
    }
  }

  @media (min-width: 641px) {
    html astro-island[component-export="FinderApp"] .fancy-row:has(input[name="seed"]) .fancy-inputs > div:has(> [role="group"]) {
      width: 15rem;
    }

    html astro-island[component-export="FinderApp"] > div > div > .fancy-box:has(> .fancy-row) {
      display: grid;
      grid-template-columns: minmax(0, 1fr) 15rem 10rem;
      align-items: center;
      gap: 6px 8px;
    }

    html astro-island[component-export="FinderApp"] > div > div > .fancy-box > .fancy-row {
      min-width: 0;
      margin: 0;
    }

    html astro-island[component-export="FinderApp"] > div > div > .fancy-box > .fancy-row:has([data-testid="platform"]) {
      grid-column: 2;
    }

    html astro-island[component-export="FinderApp"] > div > div > .fancy-box > .fancy-row:has([data-testid="dimension-select"]) {
      grid-column: 3;
    }
  }

  @media (min-width: 641px) and (max-width: 1099px) {
    html astro-island[component-export="FinderApp"] > div > div > .fancy-box > .fancy-row:first-child {
      grid-column: 1 / -1;
    }
  }

  @media (forced-colors: active) {
    html astro-island[component-export="FinderApp"] .fancy-row select {
      appearance: auto;
      background-image: none;
    }
  }
`.trim()
