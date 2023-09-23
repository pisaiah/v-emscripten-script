# v-emscripten-script
Script for compling V projects to WASM. (Supports Closures!)

## Usage 
Command args: ``<path to v dir> <path to project dir>``

## Features 
- Compile to ``.wasm`` with emscripten in one command.
- Working closures!
- Ability to remove unused code. (experimental)

### example

(example use for vpaint:)
The ``-remove`` argument decreases the vpaint .wasm size by 48 KB (914 -> 866)

```
v -o v2w.exe .
v2w.exe <path to v dir> <path to vpaint> -remove=iui__Textbox;iui__SplitView;iui__Tree2;iui__TreeNode;iui__HBox
```