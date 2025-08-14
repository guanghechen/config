@src/view/filetype/text/

I wish to add a transform mode for the text filetype view, below is the details of what the transform mode looks like.

1. Since the text view is a simple string, so the transform mode should exist three section:

    1. **Split**: to split the text into a string list. It should be a single js function or regex to split the string.
    2. **Filter|Map**: to filter or map the string to reasonable objects. They should be zero or more js functions to filter or map the string, the input is the previous map returned, the first input is the **Split** step returned.
    3. **Identifier**: to given uuid|null, parent_uuid: string|null of each object returned from the **Filter|Map** step.

2. For each section, let's create reasonable ui for user to typing.
    1. **SPlit**: an inputbox for regex or arrow function, the regex is for the `text.split(regex)`, and the function accept the original text as input and produce string[]
    2. **Filter|Map**: a list of inputboxes for js functions, the input is the previous step returned, the first input is the **Split** step returned.
    3. **Identifier**: two inputboxes for uuid, parent_uuid, the uuid is the identifier of each object returned from the **Filter|Map** step, the parent_uuid is the parent identifier of each object returned from the **Filter|Map** step. each input boxes accept a js arrow function string, which the input is the object returned from the **Filter|Map** step, and the output is the uuid or parent_uuid string.

3. Persistent: we need to persist the user typed content into the sections or the transform mode, let's keep the state into the viewmodel and persistent with the `mode$` state together.
