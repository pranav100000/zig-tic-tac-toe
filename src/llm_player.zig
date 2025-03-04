const std = @import("std");
const writer = std.io.getStdOut().writer();
const json = std.json;

const open_ai_api_key = "";
const claude_api_key = "";

pub fn getMove(is_playing_claude: bool, board: []const u8, computer_symbol: u8) !u8 {
    if (is_playing_claude) {
        return getClaudeMove(board, computer_symbol);
    }
    return getChatGPTMove(board, computer_symbol);
}

fn getChatGPTMove(board: []const u8, computer_symbol: u8) !u8 {
    const prompt = try createTicTacToePrompt(board, computer_symbol);
    const move = try chatGPTChatCompletion(prompt);
    return move;
}

fn getClaudeMove(board: []const u8, computer_symbol: u8) !u8 {
    const prompt = try createTicTacToePrompt(board, computer_symbol);
    const move = try claudeChatCompletion(prompt);
    return move;
}

fn createTicTacToePrompt(board: []const u8, computer_symbol: u8) ![]const u8 {
    const allocator = std.heap.page_allocator;
    var prompt = std.ArrayList(u8).init(allocator);
    errdefer prompt.deinit();

    // Create a JSON string
    const json_string = try json.stringifyAlloc(allocator, board, .{});
    defer allocator.free(json_string);

    const available_moves = try getAvailableMoves(allocator, board);
    defer allocator.free(available_moves);

    try prompt.appendSlice("You are playing tic-tac-toe. The board is represented as a 3x3 grid. ");
    try prompt.appendSlice("The board is: ");
    try prompt.appendSlice(json_string);
    try prompt.appendSlice(" The number you select MUST be a number that is on the board. ");
    try prompt.appendSlice("You are playing as: ");
    try prompt.append(computer_symbol);
    try prompt.appendSlice(" RULES:");
    try prompt.appendSlice("1. You can ONLY select a position that contains a number (1-9) on the current board. ");
    try prompt.appendSlice("2. You CANNOT select any position that already contains an 'X' or an 'O'. ");
    try prompt.appendSlice("3. Valid moves are ONLY the numerical values (1-9) that you can see on the current board. ");
    try prompt.appendSlice("4. Any position that shows a number is available; any position showing 'X' or 'O' is already taken. ");
    try prompt.appendSlice("Respond with ONLY a single digit (1-9) representing your move. Do not include any explanation or additional text. ");
    try prompt.appendSlice("Choose ONLY from the numbers that are visible on the current board. ");
    try prompt.appendSlice("These are your available moves: {");

    // Convert available moves to a string and append
    for (available_moves) |move| {
        try prompt.appendSlice(&[_]u8{move});
        try prompt.appendSlice(",");
    }
    try prompt.appendSlice("} The number you select MUST be in the above available moves. ");
    try prompt.appendSlice("Consider all available moves before you make your move. ");
    try prompt.appendSlice("The goal of the game is to get 3 of your symbols in a row, column, or diagonal. ");
    try prompt.appendSlice("If you see a winning opportunity, you MUST take it. ");
    try prompt.appendSlice("If you can make a move that will make you win in the next move, you MUST make that move. ");
    try prompt.appendSlice("If you see a move that will block the other player from winning, you MUST make that move. ");
    try prompt.appendSlice("Remember, you MUST pick a move out of the available moves. ");

    return prompt.toOwnedSlice();
}

fn getAvailableMoves(allocator: std.mem.Allocator, board: []const u8) ![]u8 {
    var available_moves = std.ArrayList(u8).init(allocator);
    errdefer available_moves.deinit();

    // Iterate through each character in the board string
    for (board) |char| {
        // Check if the character is a digit between 1 and 9
        if (char >= '1' and char <= '9') {
            try available_moves.append(char); // Convert from ASCII to numeric value
        }
    }

    return available_moves.toOwnedSlice();
}

fn chatGPTChatCompletion(prompt: []const u8) !u8 {
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
                return char - '0';
            }
        }

        // If no valid digit found
        return error.NoValidMove;
    }

    return error.EmptyResponse;
}

fn claudeChatCompletion(prompt: []const u8) !u8 {
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
        .max_tokens = 20000,
        .thinking = .{
            .type = "enabled",
            .budget_tokens = 16000,
        },
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

    // Extract the content blocks from the response
    if (result.value.content.len > 0) {
        // Look for a content block with type "text"
        for (result.value.content) |content_block| {
            if (std.mem.eql(u8, content_block.type, "text") and content_block.text != null) {
                const content = content_block.text.?;

                // Find the first digit in the response
                for (content) |char| {
                    if (char >= '1' and char <= '9') {
                        // Return just the digit
                        return char - '0';
                    }
                }
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
    text: ?[]const u8 = null,
    thinking: ?[]const u8 = null,
    signature: ?[]const u8 = null,
};

const AnthropicResponse = struct {
    id: []const u8,
    type: []const u8,
    role: []const u8,
    model: []const u8,
    content: []AnthropicContentBlock,
    stop_reason: []const u8,
    stop_sequence: ?[]const u8 = null,
    usage: struct {
        input_tokens: i32,
        output_tokens: i32,
        cache_creation_input_tokens: ?i32 = null,
        cache_read_input_tokens: ?i32 = null,
    },
};
