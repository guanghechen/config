export const darkTheme: string = `
  /* Reddit Dark Theme */
  body, .theme-beta {
    background-color: #1a1a1b !important;
    color: #d7dadc !important;
  }

  /* Header */
  header, .header {
    background-color: #1a1a1b !important;
    border-bottom: 1px solid #343536 !important;
  }

  /* Posts */
  .Post, [data-testid="post-container"], .thing {
    background-color: #1a1a1b !important;
    border: 1px solid #343536 !important;
    color: #d7dadc !important;
  }

  /* Sidebar */
  .side, .sidebar, aside {
    background-color: #1a1a1b !important;
    color: #d7dadc !important;
  }

  /* Comments */
  .Comment, .comment, .commentarea {
    background-color: #1a1a1b !important;
    color: #d7dadc !important;
  }

  /* Links */
  a {
    color: #4fbcff !important;
  }

  a:visited {
    color: #cc7ddb !important;
  }

  /* Buttons */
  button, .button {
    background-color: #0079d3 !important;
    color: #ffffff !important;
    border: none !important;
  }

  /* Input fields */
  input, textarea, select {
    background-color: #272729 !important;
    color: #d7dadc !important;
    border: 1px solid #343536 !important;
  }

  /* Navigation */
  nav, .nav {
    background-color: #1a1a1b !important;
  }

  /* Voting arrows */
  .arrow {
    filter: brightness(0.8) !important;
  }

  /* Search */
  .search-input, [data-testid="search-input"] {
    background-color: #272729 !important;
    color: #d7dadc !important;
  }

  /* Modal/Dropdown backgrounds */
  .modal, .dropdown-content {
    background-color: #1a1a1b !important;
    color: #d7dadc !important;
    border: 1px solid #343536 !important;
  }
`.trim()

