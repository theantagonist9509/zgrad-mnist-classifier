const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
    @cInclude("raygui.h"); // See deps/src/raygui_implementation.c
});

const IdxUbyte = @import("idxubyte.zig");
const zgrad = @import("zgrad");

const upsample_factor = 4;

const pixel_size = 5;
const window_height = upsample_factor * 28 * pixel_size;
const window_width: comptime_int = @intFromFloat(window_height * 16.0 / 9.0);

const bar_width = (window_width - window_height) / 2;
const bar_height = window_height / @as(f32, @floatFromInt(2 * 10));

const button_width = 2 * bar_height;
const button_height = bar_height;

const Margin = struct {
    top: usize,
    bottom: usize,
    left: usize,
    right: usize,
};

const largest_invalid_margin = Margin{
    .top = upsample_factor * 28 - 1,
    .bottom = 0,
    .left = upsample_factor * 28 - 1,
    .right = 0,
};

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
    @memset(classifier.input.value.entries, 0);
    classifier.operate();

    c.InitWindow(window_width, window_height, "Interact");
    defer c.CloseWindow();
    c.SetTargetFPS(60);

    const input_image = try allocator.alloc(f32, upsample_factor * upsample_factor * 28 * 28);
    @memset(input_image, 0);

    var margin = largest_invalid_margin;

    while (!c.WindowShouldClose()) {
        c.BeginDrawing();
        defer c.EndDrawing();
        c.ClearBackground(c.GetColor(@bitCast(c.GuiGetStyle(c.DEFAULT, c.BACKGROUND_COLOR)))); // Need @bitCast() here as raylib function GetColor() accepts unsigned int but raygui function GuiGetStyle() returns int

        if (updateInputImage(input_image)) {
            @memset(classifier.input.value.entries, 0);

            margin = getImageMargin(input_image);
            if (margin.top < margin.bottom) // Check if margin is valid (i.e., image isn't blank)
                cropAndResizeInputImage(input_image, margin, classifier.input.value.entries);

            classifier.operate();
        }

        drawInputImage(input_image, margin);
        drawDownsampledImage(classifier.input.value.entries);

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
        const i = @divFloor(mouse_position.y, pixel_size);
        const j = @divFloor(mouse_position.x, pixel_size);

        const radius = 5;

        const offsets = comptime blk: {
            var ret: [2 * radius - 1]f32 = undefined;

            for (&ret, 0..) |*item, k|
                item.* = @as(f32, @floatFromInt(k)) - (radius - 1);

            break :blk ret;
        };

        for (offsets) |i_offset| {
            for (offsets) |j_offset| {
                const squared_distance = i_offset * i_offset + j_offset * j_offset;
                const squared_radius = radius * radius;

                if (!(i + i_offset >= 0 and i + i_offset < upsample_factor * 28 and j + j_offset >= 0 and j + j_offset < upsample_factor * 28) or squared_distance > squared_radius)
                    continue;

                const new_brightness = 1 - squared_distance / squared_radius;

                const data_index: usize = @intFromFloat(upsample_factor * 28 * (i + i_offset) + j + j_offset);

                if (new_brightness > data[data_index])
                    data[data_index] = new_brightness;
            }
        }

        return true;
    }

    return false;
}

fn getImageMargin(data: []const f32) Margin {
    var ret = largest_invalid_margin;

    for (0..upsample_factor * 28) |i| {
        for (0..upsample_factor * 28) |j| {
            if (data[upsample_factor * 28 * i + j] == 0)
                continue;

            if (i < ret.top)
                ret.top = i;

            if (i > ret.bottom)
                ret.bottom = i;

            if (j < ret.left)
                ret.left = j;

            if (j > ret.right)
                ret.right = j;
        }
    }

    return ret;
}

fn cropAndResizeInputImage(input_data: []const f32, margin: Margin, output_data: []f32) void {
    const input_height = margin.bottom - margin.top;
    const input_width = margin.right - margin.left;

    const scale_ratio = 20 / @as(f32, @floatFromInt(@max(input_height, input_width)));

    const output_height: usize = @intFromFloat(@as(f32, @floatFromInt(input_height)) * scale_ratio);
    const output_width: usize = @intFromFloat(@as(f32, @floatFromInt(input_width)) * scale_ratio);

    for (14 - output_height / 2..14 + output_height / 2, 0..) |output_i, output_i_offset| {
        for (14 - output_width / 2..14 + output_width / 2, 0..) |output_j, output_j_offset| {
            const input_i = margin.top + @as(usize, @intFromFloat((@as(f32, @floatFromInt(output_i_offset)) + 0.5) / scale_ratio));
            const input_j = margin.left + @as(usize, @intFromFloat((@as(f32, @floatFromInt(output_j_offset)) + 0.5) / scale_ratio));

            output_data[28 * output_i + output_j] += input_data[upsample_factor * 28 * input_i + input_j];
        }
    }
}

fn drawInputImage(data: []const f32, margin: Margin) void {
    c.DrawRectangle(0, 0, window_height, window_height, c.BLACK);

    for (0..upsample_factor * 28) |i| {
        for (0..upsample_factor * 28) |j| {
            const pixel_brightness: u8 = @intFromFloat(data[upsample_factor * 28 * i + j] * 255);

            if (i >= margin.top and i <= margin.bottom and j >= margin.left and j <= margin.right)
                c.DrawRectangle(@intCast(pixel_size * j), @intCast(pixel_size * i), pixel_size, pixel_size, c.LIME);

            c.DrawRectangle(@intCast(pixel_size * j), @intCast(pixel_size * i), pixel_size, pixel_size, .{
                .r = 255,
                .g = 255,
                .b = 255,
                .a = pixel_brightness,
            });
        }
    }
}

fn drawDownsampledImage(data: []const f32) void {
    for (0..28) |i| {
        for (0..28) |j| {
            const pixel_brightness: u8 = @intFromFloat(data[28 * i + j] * 255);

            c.DrawRectangle(@intCast(window_height + 2 * pixel_size * (j + 1) / 3), @intCast(pixel_size * 2 * (i + 1) / 3), pixel_size, pixel_size, .{
                .r = pixel_brightness,
                .g = pixel_brightness,
                .b = pixel_brightness,
                .a = 255,
            });
        }
    }
}
