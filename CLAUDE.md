
## HINTS

1. Since we are not always render the config/theme/app/{app}.hbs with a specific color theme like the catppuccin theme, so if you want to use special colors for a specific color theme like the catppuccin, you should write like `{{catppuccin?.red || catppuccin.red}}`.

2. Our hbs render is a very simpler, it just support to replace the `{{statements}}`, while the `statements` is a valid javascript expression, we can access the builtin js objects and the variables inside the expression.
