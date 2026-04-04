 high-performance, IDE-like Global Search plugin for Vim 8.2+ using the Popup API.

## Features
- **Fast**: Uses Ripgrep (`rg`) if available, falls back to `grep`.
- **Interactive**: Move the cursor inside the search pattern to edit with comfort.
- **Visual**: Dark-tinted transparent block cursor and live highlighting.
- **Informative**: Real-time match counter and pretty help menu.
- **Persistent**: Remembers your last search pattern.

## Installation
Using [vim-plug](https://github.com/junegunn/vim-plug):
```vim
Plug 'bpivaty/vim-popup-search'


Usage
Press <leader>g to open the search window.
Arrows / Ctrl-n / Ctrl-p: Navigate results.
Left / Right: Move cursor inside search text.
Enter: Open file at the specific line.
Ctrl-s: Toggle case sensitivity.
?: Show the beautiful help menu.