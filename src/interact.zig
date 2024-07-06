const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
    @cInclude("raygui.h"); // See deps/src/raygui_implementation.c
});

const IdxUbyte = @import("idxubyte.zig");
const zgrad = @import("zgrad");

const pixel_size = 20;
const window_height = 28 * pixel_size;
const window_width: comptime_int = @intFromFloat(window_height * 16.0 / 9.0);

const bar_width = (window_width - window_height) / 2;
const bar_height = window_height / @as(f32, @floatFromInt(2 * 10));

const button_width = 2 * bar_height;
const button_height = bar_height;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    const T = struct {
        zgrad.AffineTransformation,
        zgrad.LeakyRelu(0.1),
        zgrad.AffineTransformation,
        zgrad.LeakyRelu(0.1),
        zgrad.AffineTransformation,
        zgrad.Softmax,
    };

    const classifier = try zgrad.deserialize(zgrad.Sequence(T), allocator, "classifier");

    c.InitWindow(window_width, window_height, "Interact");
    defer c.CloseWindow();
    c.SetTargetFPS(60);

    while (!c.WindowShouldClose()) {
        c.BeginDrawing();
        defer c.EndDrawing();
        c.ClearBackground(c.GetColor(@bitCast(c.GuiGetStyle(c.DEFAULT, c.BACKGROUND_COLOR)))); // Need @bitCast() here as raylib function GetColor() accepts unsigned int but raygui function GuiGetStyle() returns int

        if (updateInputImage(classifier.input.value.entries))
            classifier.operate();

        drawImage(classifier.input.value.entries);

        for (classifier.output.value.entries, 0..) |*entry, i| {
            _ = c.GuiProgressBar(.{
                .x = (window_width + window_height - bar_width) / 2,
                .y = (0.5 + @as(f32, @floatFromInt(2 * i))) * bar_height,
                .width = bar_width,
                .height = bar_height,
            }, "", &[_]u8{ std.fmt.digitToChar(@intCast(i), .lower), 0 }, entry, 0, 1);
        }
    }
}

fn updateInputImage(data: []f32) bool {
    if (c.GuiButton(.{
        .x = window_height + button_width / 2,
        .y = window_height - 3 * button_height / 2,
        .width = button_width,
        .height = button_height,
    }, "Clear") > 0) {
        @memset(data, 0);
        return true;
    }

    const mouse_position = c.GetMousePosition();
    if (c.IsMouseButtonDown(c.MOUSE_BUTTON_LEFT) and mouse_position.x > 0 and mouse_position.x < window_height and mouse_position.y > 0 and mouse_position.y < window_height) {
        const i = @as(isize, @intFromFloat(mouse_position.y / pixel_size));
        const j = @as(isize, @intFromFloat(mouse_position.x / pixel_size));

        const modifiers = [_]isize{ -1, 0, 1 };

        for (modifiers) |i_modifier| {
            for (modifiers) |j_modifier| {
                if (!(i + i_modifier > 0 and i + i_modifier < 28 and j + j_modifier > 0 and j + j_modifier < 28))
                    continue;

                if (data[@intCast(28 * (i + i_modifier) + j + j_modifier)] < 0.25)
                    data[@intCast(28 * (i + i_modifier) + j + j_modifier)] = 0.25;
            }
        }

        data[@intCast(28 * i + j)] = 1;

        return true;
    }

    return false;
}

fn drawImage(data: []const f32) void {
    for (0..28) |i| {
        for (0..28) |j| {
            const pixel_brightness: u8 = @intFromFloat(data[28 * i + j] * 255);
            c.DrawRectangle(@intCast(pixel_size * j), @intCast(pixel_size * i), pixel_size, pixel_size, .{
                .r = pixel_brightness,
                .g = pixel_brightness,
                .b = pixel_brightness,
                .a = 255,
            });
        }
    }
}
