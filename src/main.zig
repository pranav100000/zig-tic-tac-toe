const std = @import("std");
const stdin = std.io.getStdIn().reader();
const stdout_file = std.io.getStdOut().writer();
var bw = std.io.bufferedWriter(stdout_file);
const stdout = bw.writer();
const get_move = @import("llm_player.zig").get_move;
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

    var board: [9]u8 = [_]u8{ '1', '2', '3', '4', '5', '6', '7', '8', '9' };
    var board_string = try board_to_string(allocator, board);
    defer allocator.free(board_string); // Free initial board string

    var is_x_turn: bool = true;
    const playing_against_ai = buffer[0] == 'y';
    const computer_symbol: u8 = 'O';
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
        const go_first = buffer[0] == 'y';
        try stdout.print("You are X\n", .{});
        if (!go_first) {
            const move = try get_move(playing_against_claude, board_string, computer_symbol);
            board[move - 1] = computer_symbol;
            board_string = try board_to_string(allocator, board);
        }
    }
    try stdout.print("Board:\n{s}", .{board_string});

    while (true) {
        if (playing_against_ai and !is_x_turn) {
            const move = try get_move(playing_against_claude, board_string, computer_symbol);
            board[move - 1] = computer_symbol;

            // Free old board string before assigning new one
            allocator.free(board_string);
            board_string = try board_to_string(allocator, board);

            if (try check_win(board, board_string)) {
                try stdout.print("Game over! {s} wins!\n", .{if (is_x_turn) "X" else "O"});
                break;
            }
            try stdout.print("Board:\n{s}", .{board_string});
            if (check_draw(board)) {
                try stdout.print("Game over! It's a draw!\n", .{});
                break;
            }
            is_x_turn = !is_x_turn;
            continue;
        }

        // Human player's turn
        try stdout.print("It is {s}'s turn. Enter a position (1-9): ", .{if (is_x_turn) "X" else "O"});
        try bw.flush();

        const position = try stdin.readUntilDelimiterOrEof(&buffer, '\n'); // Pass buffer and newline delimiter
        if (position == null) {
            break;
        }

        const position_int = std.fmt.parseInt(usize, position.?, 10) catch {
            try stdout.print("Invalid input. Please enter a number between 1 and 9.\n", .{});
            continue;
        };

        if (position_int < 1 or position_int > 9) {
            try stdout.print("Invalid position. Please enter a number between 1 and 9.\n", .{});
            continue;
        }

        if (board[position_int - 1] == 'X' or board[position_int - 1] == 'O') {
            try stdout.print("Position already taken. Please enter a different position.\n", .{});
            continue;
        }

        board[position_int - 1] = if (is_x_turn) 'X' else 'O';
        // Free old board string before assigning new one
        allocator.free(board_string);
        board_string = try board_to_string(allocator, board);

        if (try check_win(board, board_string)) {
            try stdout.print("Game over! {s} wins!\n", .{if (is_x_turn) "X" else "O"});
            break;
        }
        try stdout.print("Board:\n{s}", .{board_string});
        if (check_draw(board)) {
            try stdout.print("Game over! It's a draw!\n", .{});
            break;
        }

        is_x_turn = !is_x_turn;
    }

    try bw.flush();
}

fn board_to_string(allocator: std.mem.Allocator, board: [9]u8) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    defer result.deinit();

    try std.fmt.format(result.writer(), " {c} | {c} | {c} \n", .{ board[0], board[1], board[2] });
    try std.fmt.format(result.writer(), "---|---|---\n", .{});
    try std.fmt.format(result.writer(), " {c} | {c} | {c} \n", .{ board[3], board[4], board[5] });
    try std.fmt.format(result.writer(), "---|---|---\n", .{});
    try std.fmt.format(result.writer(), " {c} | {c} | {c} \n", .{ board[6], board[7], board[8] });

    return result.toOwnedSlice();
}

fn check_draw(board: [9]u8) bool {
    var is_draw = true;
    for (board) |cell| {
        if (cell != 'X' and cell != 'O') {
            is_draw = false;
            break;
        }
    }
    return is_draw;
}

fn check_win(board: [9]u8, board_string: []u8) !bool {
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
        const c1 = board[pattern.cells[0]];
        const c2 = board[pattern.cells[1]];
        const c3 = board[pattern.cells[2]];

        // If all three cells match and aren't empty
        if (c1 == c2 and c2 == c3 and (c1 == 'X' or c1 == 'O')) {
            // Apply highlighting for this win pattern
            for (pattern.highlight_indices) |index| {
                board_string[index] = pattern.highlight_char;
            }
            is_win = true;
        }
    }

    if (is_win) {
        try stdout.print("Board:\n{s}", .{board_string});
    }

    return is_win;
}
