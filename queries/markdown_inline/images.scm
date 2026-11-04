; Standard inline image: ![alt](url)
(image
  [
    (link_destination) @image.src
    (image_description (shortcut_link ((link_text) @image.src)))
  ]
  (#gsub! @image.src "|.*" "")
  (#gsub! @image.src "^<" "")
  (#gsub! @image.src ">$" "")
) @image

; Short reference style: ![ref][] or ![ref], where the description is the last child; anchoring keeps
; images with a destination or a label out, which would otherwise each look up the link definitions
((image
  (image_description) @image.ref .) @image)

; Full reference style: ![alt][ref]
((image
  (link_label) @image.ref) @image)
