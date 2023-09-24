## STCursorword

A minimal plugin for highlighting the word under the cursor.

- ❓ [Reason for creating](#reason)
- 👀 [Installation](#installation)
- 💻 [Configuration](#configuration)
- 😆 [Usage](#usage)
- 😁 [Contributing](#contributing)
- ✌️ [License](#license)

## Reason <a name = "reason"></a> for creating this plugin

🎉 There are many plugins that do this, but none of them support disabling for certain filetypes. So, If I accidentally open a binary file such as .png file it gives me an error

🛠️ Other plugins always reset highlighting when the cursor moves, whereas this plugin does not. It only highlights the word under the cursor when the cursor moves out of the word range.

🍕 Easily to disable and enable when needed.

🚀 And a subjective reason is that I used to use the `nvim-cursorline` plugin before, but I don't use the cursorline feature. Another plugins i found that nvim-cursorword, it works quite similar to this plugin, but its setup method is not like the plugins I usually use. So this is the reason for this plugin.

## Preview

Nvim cursorline error when accidentally open a binary file

![Nvim cursorline error](./docs/readme/compare1.png)

stcursorword does not meet this error


https://github.com/sontungexpt/stcursorword/assets/92097639/d00be822-dfcf-47e8-8e97-a2a6ae0b6abf


## Installation

```lua
    -- lazy
    {
        "sontungexpt/stcursorword",
        event = "VeryLazy",
        config = true,
    },
```

## Configuration

```lua
    -- default configuration
    require("stcursorword").setup({
        max_word_length = 100, -- if cursorword length > max_word_length then not highlight
        min_word_length = 2, -- if cursorword length < min_word_length then not highlight
        excluded = {
            filetypes = {
              "TelescopePrompt"
            },
            buftypes = {
                -- "nofile",
                -- "terminal",
            },
            file_patterns = { -- pattern to match with the path of the file
              "%.png$",
            },
        },
        highlight = {
            underline = true,
            fg = nil,
            bg = nil,
        }
    })
```

## Usage

| **Command**          | **Description**                             |
| -------------------- | ------------------------------------------- |
| `:CursorwordEnable`  | Enable highlight the word under the cursor  |
| `:CursorwordDisable` | Disable highlight the word under the cursor |

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details
