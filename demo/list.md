# List Demonstrations in Markdown

## Basic Task Lists


- [x] Simple bullet item 1
- [ ] Simple bullet item 2
- [-] Simple bullet item 2
- [X] Simple bullet item 3

## Basic Unordered Lists

* Simple bullet item 1
* Simple bullet item 2
* Simple bullet item 3

- Alternative bullet style 1
- Alternative bullet style 2
- Alternative bullet style 3

+ Another bullet style 1
+ Another bullet style 2
+ Another bullet style 3

## Basic Ordered Lists

1. First numbered item
2. Second numbered item
3. Third numbered item

## Custom Starting Number

7. This list starts at 7
8. Continues automatically
9. And keeps incrementing

## Nested Lists

* Main bullet item
  * Nested bullet item
    * Deeply nested bullet item
      * Very deeply nested bullet item
  * Another nested item
* Second main bullet

1. Ordered parent
   * Unordered child
     1. Ordered grandchild
        - Unordered great-grandchild
   * Another unordered child
2. Second ordered parent

## Mixed List Types

- Bullet point with **bold text**
- Bullet with [hyperlink](https://example.com)
- Bullet with `inline code`
- Bullet with *italics*

## Lists with Paragraphs

* First item
  
  This is a paragraph within the first item.
  
* Second item
  
  This is a paragraph within the second item.
  
  This is another paragraph in the same item.

## Task Lists

- [ ] Uncompleted task
- [x] Completed task
- [ ] Task with **formatted text**
- [x] Task with `code inside`
- [ ] Task with [link](https://example.com)

## Complex Nested Task Lists

- [ ] Main project
  - [ ] Sub-task 1
    - [x] Sub-sub-task A
    - [ ] Sub-sub-task B
  - [x] Sub-task 2
    - [x] Sub-sub-task C
    - [x] Sub-sub-task D
- [x] Second project
  - [ ] Sub-task 3

## Lists with Code Blocks

* Item with code block:
  ```js
  function example() {
    return "This is a code block in a list";
  }
  ```
* Next item after code block

## Lists with Blockquotes

* Item with blockquote:
  > This is a blockquote inside a list item.
  > It continues for multiple lines.
* Next item after blockquote

## Edge Cases

* Item with an empty line below

* Item after empty line
*Not an item because of missing space after asterisk*

- Item with intentionally
  broken indentation
    that uses irregular spacing

1. Ordered item
2. With a line break  
   within the same item (two spaces at end of previous line)

## List Interruption and Continuation

* First section
* of the list

Some text in between.

* This is technically a new list
* In most renderers

## List with HTML

* Item with <strong>HTML</strong> tags
* Item with <span style="color:red">colored text</span> using HTML
* Item with <br>line break

## Corner Cases

-    List item with extra spacing after marker
*     Another unusual spacing

999999999999999. Extremely large number
0. Zero start
-1. Negative start (may not work in all parsers)

## Loose vs Tight Lists

Tight list (no paragraph breaks):
* Item 1
* Item 2
* Item 3

Loose list (with paragraph breaks):
* Item 1

* Item 2

* Item 3

## Lists with Images

* Item with an image ![alt text](https://example.com/image.jpg)
* Another item

## Empty List Items

* 
* Item after empty item
* 

## List with Reference Links

* Item with [reference link][ref]
* Another item

[ref]: https://example.com

## List with Definition List (HTML-style)

<dl>
  <dt>Term 1</dt>
  <dd>Definition 1</dd>
  <dt>Term 2</dt>
  <dd>Definition 2</dd>
</dl>

## Non-standard List Syntax (may work in some parsers)

*)  Parenthesis after asterisk
-)  Parenthesis after dash
+)  Parenthesis after plus
a)  Letter instead of number
i.  Roman numeral style
