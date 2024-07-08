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

    const input_image = try allocator.alloc(f32, upsample_factor * upsample_factor * 28 * 28);

    var margins: Margins = undefined;

    var weighted_center: c.Vector2 = undefined;
    var weight_sum: f32 = undefined;

    while (!c.WindowShouldClose()) {
        c.BeginDrawing();
        defer c.EndDrawing();
        c.ClearBackground(c.GetColor(@bitCast(c.GuiGetStyle(c.DEFAULT, c.BACKGROUND_COLOR)))); // Need @bitCast() here as raylib function GetColor() accepts unsigned int but raygui function GuiGetStyle() returns int

        if (updateInputImage(input_image)) blk: {
            margins.top = upsample_factor * 28;
            margins.bottom = 0;
            margins.left = upsample_factor * 28;
            margins.right = 0;

            weighted_center = .{ .y = 0, .x = 0 };
            weight_sum = 0;

            var is_image_empty = true;

            for (input_image, 0..) |pixel_brightness, i| {
                if (pixel_brightness == 0)
                    continue;

                is_image_empty = false;

                const y = i / (upsample_factor * 28);
                const x = i % (upsample_factor * 28);

                if (y < margins.top)
                    margins.top = y;

                if (y > margins.bottom)
                    margins.bottom = y;

                if (x < margins.left)
                    margins.left = x;

                if (x > margins.right)
                    margins.right = x;

                weighted_center.y += pixel_brightness * @as(f32, @floatFromInt(y));
                weighted_center.x += pixel_brightness * @as(f32, @floatFromInt(x));
                weight_sum += pixel_brightness;
            }

            if (is_image_empty)
                break :blk;

            weighted_center.x /= weight_sum;
            weighted_center.y /= weight_sum;

            //cropAndCenterAndResizeInputImage();

            classifier.operate();
        }

        drawInputImage(input_image, margins);

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

        const radius = 4;

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

//fn cropAndCenterAndResizeInputImage() !void {
//}

fn drawInputImage(data: []const f32, margins: Margins) void {
    c.DrawRectangle(0, 0, window_height, window_height, c.BLACK);

    for (0..upsample_factor * 28) |i| {
        for (0..upsample_factor * 28) |j| {
            const pixel_brightness: u8 = @intFromFloat(data[upsample_factor * 28 * i + j] * 255);

            if (i >= margins.top and i <= margins.bottom and j >= margins.left and j <= margins.right)
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

const Margins = struct {
    top: usize,
    bottom: usize,
    left: usize,
    right: usize,
};
