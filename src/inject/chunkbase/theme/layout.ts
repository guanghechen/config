export const layoutTheme: string = `
  .adthrive-sticky.adthrive-footer,
  [id^="AdThrive_Footer_"] {
    display: none !important;
  }

  html body,
  html #content {
    min-width: 0;
  }

  html .main-wrapper {
    margin: 0;
  }

  html #content {
    width: 100%;
    max-width: none;
    margin-top: 0;
  }

  html #pageheader {
    height: 100px;
    top: 0;
    overflow: hidden;
  }

  html #logoanchor {
    top: 8px;
  }

  html #logo {
    width: auto;
    height: 32px;
  }

  html #navbanner,
  html #socialnav,
  html [id^="navdeco"] {
    display: none;
  }

  html #navwrap {
    top: 48px;
  }

  html:not(.theater-map) #main-content {
    margin-inline: 12px;
  }

  html #main.wide > article > .box {
    box-sizing: border-box;
    width: 100%;
    max-width: none;
  }

  html #main.wide > article > .box > .boxcontent {
    margin: 12px;
  }

  html #main.wide > article > .box > .boxheader {
    border-width: 0;
    margin: 0 0 0 -1px;
  }

  html:not(.theater-map) astro-island[component-export="FinderApp"] > div {
    display: flex;
    flex-direction: column;
    min-height: max(36rem, calc(100dvh - 13rem));
  }

  html:not(.theater-map) astro-island[component-export="FinderApp"] > div > div {
    flex-shrink: 0;
  }

  html:not(.theater-map) astro-island[component-export="FinderApp"] > div > div:has(> div > div > .ol-viewport) {
    flex: 1 1 0;
    min-height: 20rem;
    margin-block: 12px;
  }

  /* Match the layer of Chunkbase's important height utility. */
  @layer utilities {
    html:not(.theater-map) astro-island[component-export="FinderApp"] div:has(> div > .ol-viewport) {
      height: 100% !important;
      min-height: 0 !important;
      max-height: none !important;
      margin-top: 0 !important;
    }
  }

  html.theater-map astro-island[component-export="FinderApp"] > div > div:has(> div > div > .ol-viewport) {
    margin-inline: -12px;
    width: calc(100% + 24px);
  }

  @media (max-width: 640px) {
    html:not(.theater-map) #main-content {
      margin-inline: 4px;
    }

    html #main.wide > article > .box > .boxcontent {
      margin-inline: 8px;
    }

    html:not(.theater-map) astro-island[component-export="FinderApp"] > div {
      height: auto;
      min-height: 0;
    }

    html:not(.theater-map) astro-island[component-export="FinderApp"] > div > div:has(> div > div > .ol-viewport) {
      flex: none;
      height: 70dvh;
      min-height: 20rem;
    }

    html.theater-map astro-island[component-export="FinderApp"] > div > div:has(> div > div > .ol-viewport) {
      margin-inline: -8px;
      width: calc(100% + 16px);
    }
  }

  @media (min-width: 1100px) {
    html #pageheader {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 24px;
      height: 64px;
    }

    html #logoanchor,
    html #navwrap {
      position: static;
      margin: 0;
    }

    html #navwrap {
      position: relative;
      top: 0;
      left: 0;
    }

    html:not(.theater-map) astro-island[component-export="FinderApp"] > div {
      min-height: max(36rem, calc(100dvh - 11rem));
    }

    html astro-island[component-export="FinderApp"] > div > div > .fancy-box:has(> .fancy-row) {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 8px 20px;
    }

    html astro-island[component-export="FinderApp"] > div > div > .fancy-box > .fancy-row {
      margin: 0;
    }

    html astro-island[component-export="FinderApp"] > div > div > .fancy-box > .fancy-row:first-child {
      flex: 1 1 34rem;
    }
  }
`.trim()
