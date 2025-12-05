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

; Short reference style: ![ref][]
((image
  (image_description) @image.ref))

; Full reference style: ![alt][ref]
((image
  (link_label) @image.ref) @image)
