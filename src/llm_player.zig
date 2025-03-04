const std = @import("std");
const writer = std.io.getStdOut().writer();
const json = std.json;

const open_ai_api_key = "";

pub fn get_move(board: []const u8, computer_symbol: u8) !u8 {
    const prompt = try create_tictactoe_prompt(board, computer_symbol);
    const move = try chat_completion(prompt);
    return move;
}

pub fn create_tictactoe_prompt(board: []const u8, computer_symbol: u8) ![]const u8 {

    const allocator = std.heap.page_allocator;
    var prompt = std.ArrayList(u8).init(allocator);
    errdefer prompt.deinit();

    // Create a JSON string
    const json_string = try json.stringifyAlloc(allocator, board, .{});
    defer allocator.free(json_string);


    try prompt.appendSlice("You are playing tic-tac-toe. The board is represented as a 3x3 grid. ");
    try prompt.appendSlice("The board is: ");
    try prompt.appendSlice(json_string);
    try prompt.appendSlice("You are: ");
    try prompt.append(computer_symbol);
    try prompt.appendSlice(" Only respond with a single number between 1 and 9 that is the position you want to play. You CANNOT play in a position that is already taken. The only available moves are the numbers in the board.");


    return prompt.toOwnedSlice();
}

pub fn chat_completion(prompt: []const u8) !u8 {
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
                std.debug.print("AI chose move: {c}\n", .{char});
                return char - '0';
            }
        }

        // If no valid digit found
        return error.NoValidMove;
    }

    return error.EmptyResponse;
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
