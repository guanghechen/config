(declaration
  (call_expression
    (function_name) @fn (#eq? @fn "url")
    (arguments  [(plain_value) @image.src (string_value (string_content) @image.src)]))
  ; Fonts, style sheets and fragments (`url(#gradient)`) are no images, nor the pieces the parser splits an unquoted
  ; data URI into: only a quoted one is whole.
  (#match? @image.src "\\c\\v^['\"]?(data:image/[^,]*,|[^?#]*\\.(png|jpe?g|gif|bmp|webp|svg|tiff?|heic|avif|ico)([?#].*)?['\"]?$)")
) @image
