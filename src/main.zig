const std = @import("std");
const stdin = std.io.getStdIn().reader();
const stdout_file = std.io.getStdOut().writer();
var bw = std.io.bufferedWriter(stdout_file);
const stdout = bw.writer();
const get_move = @import("llm_player.zig").getMove;

pub fn main() !void {
    try stdout.print("Welcome to Tic Tac Toe!\nWould you like to play against an AI? Press y to play against AI and n to play against a friend (y/n): ", .{});
    try bw.flush(); // Flush to ensure prompt is displayed

    var buffer: [10]u8 = undefined; // Create a buffer to read into
    var response = try stdin.readUntilDelimiterOrEof(&buffer, '\n'); // Pass buffer and newline delimiter
    if (response == null) {
        return;
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit(); // Free the GPA allocator itself
    const allocator = gpa.allocator();

    const playing_against_ai = buffer[0] == 'y';
    var playing_against_claude: bool = false;

    if (playing_against_ai) {
        try stdout.print("Do you want to play against ChatGPT or Claude? (g/c): ", .{});
        try bw.flush();

        response = try stdin.readUntilDelimiterOrEof(&buffer, '\n');
        if (response == null) {
            return;
        }

        playing_against_claude = buffer[0] == 'c';

        try stdout.print("Playing against {s}\n", .{if (playing_against_claude) "Claude" else "ChatGPT"});
        try stdout.print("Do you want to go first? (y/n): ", .{});
        try bw.flush();

        response = try stdin.readUntilDelimiterOrEof(&buffer, '\n');
        if (response == null) {
            return;
        }
    }

    // Initialize the game
    var game = try Game.init(allocator, playing_against_ai, playing_against_claude);
    defer game.deinit(); // Ensure we clean up resources

    // Handle AI going first if player chose not to
    if (playing_against_ai) {
        const go_first = buffer[0] == 'y';
        try stdout.print("You are X\n", .{});
        if (!go_first) {
            const move = try get_move(playing_against_claude, game.board_string, game.computer_symbol);
            game.board[move - 1] = game.computer_symbol;
            try game.updateBoardString();
        }
    }

    try stdout.print("Board:\n{s}", .{game.board_string});

    // Main game loop
    gameLoop: while (true) {
        if (game.playing_against_ai and !game.is_x_turn) {
            // AI's turn
            const game_over = try game.makeAIMove();
            if (game_over) break :gameLoop;
            continue :gameLoop;
        }

        // Human player's turn
        try stdout.print("It is {s}'s turn. Enter a position (1-9): ", .{if (game.is_x_turn) "X" else "O"});
        try bw.flush();

        const position = try stdin.readUntilDelimiterOrEof(&buffer, '\n');
        if (position == null) {
            break :gameLoop;
        }

        const position_int = std.fmt.parseInt(usize, position.?, 10) catch {
            try stdout.print("Invalid input. Please enter a number between 1 and 9.\n", .{});
            continue :gameLoop;
        };

        // Process the human move
        const game_over = try game.makeHumanMove(position_int);
        if (game_over) break :gameLoop;
    }

    try bw.flush();
}

// Game struct to encapsulate game state and logic
const Game = struct {
    board: [9]u8,
    board_string: []u8,
    allocator: std.mem.Allocator,
    is_x_turn: bool,
    playing_against_ai: bool,
    playing_against_claude: bool,
    computer_symbol: u8,

    // Initialize a new game
    fn init(allocator: std.mem.Allocator, playing_against_ai: bool, playing_against_claude: bool) !Game {
        const board = [_]u8{ '1', '2', '3', '4', '5', '6', '7', '8', '9' };
        const board_string = try createBoardString(allocator, board);

        return Game{
            .board = board,
            .board_string = board_string,
            .allocator = allocator,
            .is_x_turn = true,
            .playing_against_ai = playing_against_ai,
            .playing_against_claude = playing_against_claude,
            .computer_symbol = 'O',
        };
    }

    // Clean up resources
    fn deinit(self: *Game) void {
        self.allocator.free(self.board_string);
    }

    // Update the string representation of the board
    fn updateBoardString(self: *Game) !void {
        self.allocator.free(self.board_string);
        self.board_string = try createBoardString(self.allocator, self.board);
    }

    // Check if the game is a draw
    fn checkDraw(self: *const Game) bool {
        var is_draw = true;
        for (self.board) |cell| {
            if (cell != 'X' and cell != 'O') {
                is_draw = false;
                break;
            }
        }
        return is_draw;
    }

    // Check if there's a win on the board and highlight it
    fn checkWin(self: *Game) !bool {
        // Define all possible win patterns with their board indices and corresponding
        // highlight indices and characters
        const WinPattern = struct {
            cells: [3]usize, // Board cell indices for this win pattern
            highlight_indices: []const usize, // Board string indices to modify if this pattern wins
            highlight_char: u8, // Character to use for highlighting
        };

        const win_patterns = [_]WinPattern{
            // Rows
            .{
                .cells = [_]usize{ 0, 1, 2 },
                .highlight_indices = &[_]usize{ 0, 2, 4, 6, 8, 10 },
                .highlight_char = '-',
            },
            .{
                .cells = [_]usize{ 3, 4, 5 },
                .highlight_indices = &[_]usize{ 24, 26, 28, 30, 32, 34 },
                .highlight_char = '-',
            },
            .{
                .cells = [_]usize{ 6, 7, 8 },
                .highlight_indices = &[_]usize{ 48, 50, 52, 54, 56, 58 },
                .highlight_char = '-',
            },
            // Columns
            .{
                .cells = [_]usize{ 0, 3, 6 },
                .highlight_indices = &[_]usize{ 13, 37 },
                .highlight_char = '|',
            },
            .{
                .cells = [_]usize{ 1, 4, 7 },
                .highlight_indices = &[_]usize{ 17, 41 },
                .highlight_char = '|',
            },
            .{
                .cells = [_]usize{ 2, 5, 8 },
                .highlight_indices = &[_]usize{ 21, 45 },
                .highlight_char = '|',
            },
            // Diagonals
            .{
                .cells = [_]usize{ 0, 4, 8 },
                .highlight_indices = &[_]usize{ 15, 43 },
                .highlight_char = '\\',
            },
            .{
                .cells = [_]usize{ 2, 4, 6 },
                .highlight_indices = &[_]usize{ 19, 39 },
                .highlight_char = '/',
            },
        };

        var is_win = false;

        // Check each pattern for a win
        for (win_patterns) |pattern| {
            const c1 = self.board[pattern.cells[0]];
            const c2 = self.board[pattern.cells[1]];
            const c3 = self.board[pattern.cells[2]];

            // If all three cells match and aren't empty
            if (c1 == c2 and c2 == c3 and (c1 == 'X' or c1 == 'O')) {
                // Apply highlighting for this win pattern
                for (pattern.highlight_indices) |index| {
                    self.board_string[index] = pattern.highlight_char;
                }
                is_win = true;
            }
        }

        if (is_win) {
            try stdout.print("Board:\n{s}", .{self.board_string});
        }

        return is_win;
    }

    // Make an AI move
    fn makeAIMove(self: *Game) !bool {
        const move = try get_move(self.playing_against_claude, self.board_string, self.computer_symbol);
        self.board[move - 1] = self.computer_symbol;
        try stdout.print("{s} chose move: {c}\n", .{if (self.playing_against_claude) "Claude" else "ChatGPT", move});

        try self.updateBoardString();

        // Check for game end
        if (try self.checkWin()) {
            try stdout.print("Game over! {s} wins!\n", .{if (self.is_x_turn) "X" else "O"});
            return true;
        }

        try stdout.print("Board:\n{s}", .{self.board_string});

        if (self.checkDraw()) {
            try stdout.print("Game over! It's a draw!\n", .{});
            return true;
        }

        self.is_x_turn = !self.is_x_turn;
        return false;
    }

    // Process a human move
    fn makeHumanMove(self: *Game, position_int: usize) !bool {
        if (position_int < 1 or position_int > 9) {
            try stdout.print("Invalid position. Please enter a number between 1 and 9.\n", .{});
            return false;
        }

        if (self.board[position_int - 1] == 'X' or self.board[position_int - 1] == 'O') {
            try stdout.print("Position already taken. Please enter a different position.\n", .{});
            return false;
        }

        self.board[position_int - 1] = if (self.is_x_turn) 'X' else 'O';
        try self.updateBoardString();

        if (try self.checkWin()) {
            try stdout.print("Game over! {s} wins!\n", .{if (self.is_x_turn) "X" else "O"});
            return true;
        }

        try stdout.print("Board:\n{s}", .{self.board_string});

        if (self.checkDraw()) {
            try stdout.print("Game over! It's a draw!\n", .{});
            return true;
        }

        self.is_x_turn = !self.is_x_turn;
        return false;
    }
};

// Create a string representation of the board
fn createBoardString(allocator: std.mem.Allocator, board: [9]u8) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    defer result.deinit();

    try std.fmt.format(result.writer(), " {c} | {c} | {c} \n", .{ board[0], board[1], board[2] });
    try std.fmt.format(result.writer(), "---|---|---\n", .{});
    try std.fmt.format(result.writer(), " {c} | {c} | {c} \n", .{ board[3], board[4], board[5] });
    try std.fmt.format(result.writer(), "---|---|---\n", .{});
    try std.fmt.format(result.writer(), " {c} | {c} | {c} \n", .{ board[6], board[7], board[8] });

    return result.toOwnedSlice();
}
