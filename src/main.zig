const std = @import("std");
const stdin = std.io.getStdIn().reader();
const get_chat_gpt_move = @import("llm_player.zig").get_chat_gpt_move;
const get_claude_move = @import("llm_player.zig").get_claude_move;
const get_move = @import("llm_player.zig").get_move;
pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

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
    var board_string = try draw_tic_tac_toe_board(allocator, board);
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

        std.debug.print("Playing against {s}\n", .{if (playing_against_claude) "Claude" else "ChatGPT"});
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
            board_string = try draw_tic_tac_toe_board(allocator, board);
        }
        try stdout.print("Board:\n{s}", .{board_string});
    }

    while (true) {
        if (playing_against_ai and !is_x_turn) {
            const move = try get_move(playing_against_claude, board_string, computer_symbol);
            board[move - 1] = computer_symbol;

            // Free old board string before assigning new one
            allocator.free(board_string);
            board_string = try draw_tic_tac_toe_board(allocator, board);

            try stdout.print("Board:\n{s}", .{board_string});
            if (check_win(board)) {
                try stdout.print("Game over! {s} wins!\n", .{if (is_x_turn) "X" else "O"});
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

        const position_int = try std.fmt.parseInt(usize, position.?, 10);
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
        board_string = try draw_tic_tac_toe_board(allocator, board);
        try stdout.print("Board:\n{s}", .{board_string});

        if (check_win(board)) {
            try stdout.print("Game over! {s} wins!\n", .{if (is_x_turn) "X" else "O"});
            break;
        }

        // Check for a draw
        var is_draw = true;
        for (board) |cell| {
            if (cell != 'X' and cell != 'O') {
                is_draw = false;
                break;
            }
        }

        if (is_draw) {
            try stdout.print("Game over! It's a draw!\n", .{});
            break;
        }

        is_x_turn = !is_x_turn;
    }

    try bw.flush();
}

pub fn draw_tic_tac_toe_board(allocator: std.mem.Allocator, board: [9]u8) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    defer result.deinit();

    try std.fmt.format(result.writer(), " {c} | {c} | {c} \n", .{ board[0], board[1], board[2] });
    try std.fmt.format(result.writer(), "-----------\n", .{});
    try std.fmt.format(result.writer(), " {c} | {c} | {c} \n", .{ board[3], board[4], board[5] });
    try std.fmt.format(result.writer(), "-----------\n", .{});
    try std.fmt.format(result.writer(), " {c} | {c} | {c} \n", .{ board[6], board[7], board[8] });

    return result.toOwnedSlice();
}

pub fn check_win(board: [9]u8) bool {
    // check rows
    if (board[0] == board[1] and board[1] == board[2]) {
        return true;
    }
    if (board[3] == board[4] and board[4] == board[5]) {
        return true;
    }
    if (board[6] == board[7] and board[7] == board[8]) {
        return true;
    }

    // check columns
    if (board[0] == board[3] and board[3] == board[6]) {
        return true;
    }
    if (board[1] == board[4] and board[4] == board[7]) {
        return true;
    }
    if (board[2] == board[5] and board[5] == board[8]) {
        return true;
    }

    // check diagonals
    if (board[0] == board[4] and board[4] == board[8]) {
        return true;
    }
    if (board[2] == board[4] and board[4] == board[6]) {
        return true;
    }

    return false;
}
