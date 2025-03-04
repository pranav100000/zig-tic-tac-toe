# Zig Tic Tac Toe

A command-line implementation of the classic Tic Tac Toe game written in Zig programming language. Play against a friend or challenge an AI opponent powered by either OpenAI's GPT models or Anthropic's Claude.

## Features

- Play against a friend in 2-player mode
- Play against an AI opponent using either:
  - OpenAI's GPT models
  - Anthropic's Claude models
- Choose which AI model to play against
- Choose to go first or second when playing against AI
- Simple command line interface
- Clean memory management with Zig's allocator patterns

## Requirements

- [Zig compiler](https://ziglang.org/download/) (tested with version 0.13.0)
- OpenAI API key (for ChatGPT opponent mode)
- Anthropic API key (for Claude opponent mode)
- Internet connection (for AI opponent modes)

## Installation

1. Clone this repository:
   ```
   git clone https://github.com/yourusername/zig-tic-tac-toe.git
   cd zig-tic-tac-toe
   ```

2. Add your API keys:
   - Open `src/llm_player.zig` and replace the example API keys with your own:
     - Replace `open_ai_api_key` with your OpenAI API key
     - Replace `claude_api_key` with your Anthropic API key

3. Build and run the game:
   ```
   zig build run
   ```

   Or run directly with:
   ```
   zig run src/main.zig
   ```

## How to Play

1. When prompted, choose whether to play against AI (`y`) or against a friend (`n`)
2. If playing against AI, choose whether to play against ChatGPT (`g`) or Claude (`c`)
3. Choose whether to go first (`y`) or second (`n`)
4. The board is displayed as a 3x3 grid with positions numbered 1-9:
   ```
    1 | 2 | 3 
   -----------
    4 | 5 | 6 
   -----------
    7 | 8 | 9 
   ```
5. When it's your turn, enter a number from 1-9 to place your mark in that position
6. The game continues until someone wins by getting three in a row (horizontally, vertically, or diagonally) or the board is full (draw)

## Technical Details

### Project Structure

- `src/main.zig` - Main game logic, board rendering, and player interaction
- `src/llm_player.zig` - AI opponent implementation using OpenAI and Anthropic APIs

### AI Implementation

The AI opponents use large language models to make moves:

#### ChatGPT (OpenAI)
- Uses the `o1-preview` model
- API calls made to `https://api.openai.com/v1/chat/completions`

#### Claude (Anthropic)
- Uses the `claude-3-7-sonnet-20250219` model
- API calls made to `https://api.anthropic.com/v1/messages`

For both AI types, the game:
1. Converts the current board state to a text representation
2. Creates a prompt describing the game situation and available moves
3. Sends the prompt to the respective API
4. Parses the response to extract the AI's chosen move
5. Updates the game board accordingly

The AIs are instructed to respond with only a single digit representing their move choice. The game handles all validation and board updates.

### Memory Management

The project uses Zig's allocator patterns for proper memory management:
- General Purpose Allocator for board representation
- Arena Allocator for API requests
- Explicit resource cleanup using `defer` and freeing allocated memory

## License

This project is open source and available under the [MIT License](LICENSE).

## Credits

Developed as a learning project for the Zig programming language.

---

*Note: This game requires an active internet connection and valid API keys when playing in AI opponent mode.*
