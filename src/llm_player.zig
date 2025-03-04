const std = @import("std");
const writer = std.io.getStdOut().writer();
const json = std.json;

const open_ai_api_key = "";
const claude_api_key = "";

pub fn get_move(is_playing_claude: bool, board: []const u8, computer_symbol: u8) !u8 {
    if (is_playing_claude) {
        return get_claude_move(board, computer_symbol);
    }
    return get_chat_gpt_move(board, computer_symbol);
}

pub fn get_chat_gpt_move(board: []const u8, computer_symbol: u8) !u8 {
    const prompt = try create_tictactoe_prompt(board, computer_symbol);
    const move = try chat_gpt_chat_completion(prompt);
    return move;
}

pub fn get_claude_move(board: []const u8, computer_symbol: u8) !u8 {
    const prompt = try create_tictactoe_prompt(board, computer_symbol);
    const move = try claude_chat_completion(prompt);
    return move;
}

fn create_tictactoe_prompt(board: []const u8, computer_symbol: u8) ![]const u8 {
    const allocator = std.heap.page_allocator;
    var prompt = std.ArrayList(u8).init(allocator);
    errdefer prompt.deinit();

    // Create a JSON string
    const json_string = try json.stringifyAlloc(allocator, board, .{});
    defer allocator.free(json_string);

    const available_moves = try get_available_moves(allocator, board);
    defer allocator.free(available_moves);

    try prompt.appendSlice("You are playing tic-tac-toe. The board is represented as a 3x3 grid. ");
    try prompt.appendSlice("The board is: ");
    try prompt.appendSlice(json_string);
    try prompt.appendSlice("The number you select MUST be a number that is on the board.");
    try prompt.appendSlice("You are playing as: ");
    try prompt.append(computer_symbol);
    try prompt.appendSlice("RULES:");
    try prompt.appendSlice("1. You can ONLY select a position that contains a number (1-9) on the current board.");
    try prompt.appendSlice("2. You CANNOT select any position that already contains an 'X' or an 'O'.");
    try prompt.appendSlice("3. Valid moves are ONLY the numerical values (1-9) that you can see on the current board.");
    try prompt.appendSlice("4. Any position that shows a number is available; any position showing 'X' or 'O' is already taken.");
    try prompt.appendSlice("Respond with ONLY a single digit (1-9) representing your move. Do not include any explanation or additional text.");
    try prompt.appendSlice("Choose ONLY from the numbers that are visible on the current board.");
    try prompt.appendSlice("These are your available moves: ");

    // Convert available moves to a string and append
    for (available_moves) |move| {
        try prompt.appendSlice(&[_]u8{move});
        try prompt.appendSlice(" ");
    }
    try prompt.appendSlice("The number you select MUST be in the above available moves.");

    return prompt.toOwnedSlice();
}

fn get_available_moves(allocator: std.mem.Allocator, board: []const u8) ![]u8 {
    var available_moves = std.ArrayList(u8).init(allocator);
    errdefer available_moves.deinit();

    // Iterate through each character in the board string
    for (board) |char| {
        // Check if the character is a digit between 1 and 9
        if (char >= '1' and char <= '9') {
            try available_moves.append(char - '0'); // Convert from ASCII to numeric value
        }
    }

    return available_moves.toOwnedSlice();
}

fn chat_gpt_chat_completion(prompt: []const u8) !u8 {
    const alloc = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    const allocator = arena.allocator();

    defer arena.deinit();

    var client = std.http.Client{
        .allocator = allocator,
    };

    const api_key = "Bearer " ++ open_ai_api_key;

    const headers = &[_]std.http.Header{
        .{ .name = "Content-Type", .value = "application/json" },
        .{ .name = "Authorization", .value = api_key },
    };

    var json_string = std.ArrayList(u8).init(allocator);
    defer json_string.deinit();

    const request = .{
        .model = "o1-preview",
        .messages = [_]struct {
            role: []const u8,
            content: []const u8,
        }{
            .{
                .role = "user",
                .content = prompt,
            },
        },
        .temperature = 1,
    };

    try std.json.stringify(request, .{}, json_string.writer());

    const response = try post("https://api.openai.com/v1/chat/completions", headers, json_string.items, &client, allocator);
    const result = try std.json.parseFromSlice(OpenAIResponse, allocator, response.items, .{ .ignore_unknown_fields = true });

    if (result.value.choices.len > 0) {
        const content = result.value.choices[0].message.content;

        // Find the first digit in the response
        for (content) |char| {
            if (char >= '1' and char <= '9') {
                // Return just the digit
                std.debug.print("ChatGPT chose move: {c}\n", .{char});
                return char - '0';
            }
        }

        // If no valid digit found
        return error.NoValidMove;
    }

    return error.EmptyResponse;
}

fn claude_chat_completion(prompt: []const u8) !u8 {
    const alloc = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    const allocator = arena.allocator();

    defer arena.deinit();

    var client = std.http.Client{
        .allocator = allocator,
    };

    const api_key = claude_api_key;

    const headers = &[_]std.http.Header{
        .{ .name = "x-api-key", .value = api_key },
        .{ .name = "anthropic-version", .value = "2023-06-01" },
        .{ .name = "content-type", .value = "application/json" },
    };

    var json_string = std.ArrayList(u8).init(allocator);
    defer json_string.deinit();

    const request = .{
        .model = "claude-3-7-sonnet-20250219",
        .max_tokens = 1024,
        .messages = [_]struct {
            role: []const u8,
            content: []const u8,
        }{
            .{
                .role = "user",
                .content = prompt,
            },
        },
    };

    try std.json.stringify(request, .{}, json_string.writer());

    const response = try post("https://api.anthropic.com/v1/messages", headers, json_string.items, &client, allocator);
    const result = try std.json.parseFromSlice(AnthropicResponse, allocator, response.items, .{ .ignore_unknown_fields = true });

    // Extract the content from the first message in the response
    if (result.value.content.len > 0) {
        const content = result.value.content[0].text;

        // Find the first digit in the response
        for (content) |char| {
            if (char >= '1' and char <= '9') {
                // Return just the digit
                std.debug.print("Claude AI chose move: {c}\n", .{char});
                return char - '0';
            }
        }

        // If no valid digit found
        return error.NoValidMove;
    }

    return error.EmptyResponse;
}

fn post(
    url: []const u8,
    headers: []const std.http.Header,
    payload: []const u8,
    client: *std.http.Client,
    allocator: std.mem.Allocator,
) !std.ArrayList(u8) {
    var response_body = std.ArrayList(u8).init(allocator);
    try writer.print("AI is thinking...\n", .{});
    _ = try client.fetch(.{
        .method = .POST,
        .location = .{ .url = url },
        .extra_headers = headers,
        .response_storage = .{ .dynamic = &response_body },
        .payload = payload,
    });
    return response_body;
}

// Struct for the OpenAI API response
const OpenAIMessage = struct {
    role: []const u8,
    content: []const u8,
};

const OpenAIChoice = struct {
    message: OpenAIMessage,
    index: i32,
    finish_reason: []const u8,
};

const OpenAIResponse = struct {
    id: []const u8,
    object: []const u8,
    created: i64,
    model: []const u8,
    choices: []OpenAIChoice,
    usage: struct {
        prompt_tokens: i32,
        completion_tokens: i32,
        total_tokens: i32,
    },
};

// Struct for the Anthropic API response
const AnthropicContentBlock = struct {
    type: []const u8,
    text: []const u8,
};

const AnthropicResponse = struct {
    id: []const u8,
    type: []const u8,
    role: []const u8,
    content: []AnthropicContentBlock,
    model: []const u8,
    stop_reason: []const u8,
    usage: struct {
        input_tokens: i32,
        output_tokens: i32,
    },
};
