; From blink.pairs v0.5.0 (MIT License, Copyright (c) 2025 Liam Dyer; see lua/era/keystroke/pairs/LICENSE.blink).
(type_arguments) @pair.inside

(type_identifier) @pair.inside_or_after

; incomplete function signature
; fn foo<
(ERROR
  .
  "fn") @pair.inside_or_after

"::" @pair.after
