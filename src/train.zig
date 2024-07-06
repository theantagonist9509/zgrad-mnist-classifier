const std = @import("std");

const IdxUbyte = @import("idxubyte.zig");
const zgrad = @import("zgrad");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    const training_images = (try IdxUbyte.initialize(allocator, "train-images-idx3-ubyte")).data;
    const training_labels = (try IdxUbyte.initialize(allocator, "train-labels-idx1-ubyte")).data;
    const testing_images = (try IdxUbyte.initialize(allocator, "t10k-images-idx3-ubyte")).data;
    const testing_labels = (try IdxUbyte.initialize(allocator, "t10k-labels-idx1-ubyte")).data;

    var prng = std.Random.DefaultPrng.init(0);
    const random = prng.random();

    const file_name = "classifier";

    const T = struct {
        zgrad.AffineTransformation,
        zgrad.LeakyRelu(0.1),
        zgrad.AffineTransformation,
        zgrad.LeakyRelu(0.1),
        zgrad.AffineTransformation,
        zgrad.Softmax,
    };

    const model = zgrad.deserialize(zgrad.Sequence(T), allocator, file_name) catch |err| switch (err) {
        error.FileNotFound => try zgrad.initializeSequence(allocator, @as(T, .{
            try zgrad.AffineTransformation.initialize(zgrad.LeakyRelu(0.1), allocator, random, 28 * 28, 16),
            try zgrad.LeakyRelu(0.1).initializeOutputOnly(allocator, 16),
            try zgrad.AffineTransformation.initializeParametersAndOutputOnly(zgrad.LeakyRelu(0.1), allocator, random, 16, 8),
            try zgrad.LeakyRelu(0.1).initializeOutputOnly(allocator, 8),
            try zgrad.AffineTransformation.initializeParametersAndOutputOnly(zgrad.Softmax, allocator, random, 8, 10),
            try zgrad.Softmax.initializeOutputOnly(allocator, 10),
        })),

        else => |remaining_error| return remaining_error,
    };

    var loss_operation = try zgrad.MeanSquaredError.initializeTargetAndOutput(allocator, 10);
    loss_operation.input = model.output;

    const optimizer = try zgrad.MomentumSgdOptimizer(0.001, 0.9).initialize(allocator, model.parameters);

    const epoch_count = 5;
    const training_images_count = 60_000;
    const testing_images_count = 10_000;

    for (0..epoch_count) |epoch_index| {
        var accumulated_loss: f32 = 0;
        for (0..training_images_count) |image_index| {
            zgrad.zeroGradients(model.symbols);

            for (model.input.value.entries, training_images[28 * 28 * image_index ..][0 .. 28 * 28]) |*input_entry, image_entry|
                input_entry.* = @as(f32, @floatFromInt(image_entry)) / 255;

            @memset(loss_operation.target.value.entries, 0);
            loss_operation.target.value.entries[training_labels[image_index]] = 1;

            model.operate();
            loss_operation.operate();

            accumulated_loss += loss_operation.output.value.entries[0];

            loss_operation.backpropagate();
            model.backpropagate();

            optimizer.updateParameters();
        }

        var correct_count: usize = 0;

        for (0..testing_images_count) |image_index| {
            for (model.input.value.entries, testing_images[28 * 28 * image_index ..][0 .. 28 * 28]) |*input_entry, image_entry|
                input_entry.* = @as(f32, @floatFromInt(image_entry)) / 255;

            model.operate();

            const prediction = model.output.value.argmax();

            if (epoch_index == epoch_count - 1 and image_index < 100) {
                drawImage(model.input.value.entries);
                std.debug.print("{}\n", .{prediction});
            }

            if (prediction == testing_labels[image_index])
                correct_count += 1;
        }

        std.debug.print("[{}/{}] test_accuracy: {}, cost: {}\n", .{ epoch_index + 1, epoch_count, @as(f32, @floatFromInt(correct_count)) / testing_images_count, accumulated_loss / training_images_count });
    }

    try zgrad.serialize(allocator, model, file_name);
}

fn drawImage(data: []const f32) void {
    for (0..28) |i| {
        for (0..28) |j| {
            const character = getBrightnessCharacter(data[i * 28 + j]);
            std.debug.print("{c}{c}", .{ character, character });
        }

        std.debug.print("\n", .{});
    }
}

fn getBrightnessCharacter(brightness: f32) u8 {
    // https://paulbourke.net/dataformats/asciiart
    const characters = "$@B%8&WM#*oahkbdpqwmZO0QLCJUYXzcvunxrjft/\\|()1{}[]?-_+~<>i!lI;:,\"^`'. ";

    for (characters, 1..) |_, i| {
        if (brightness <= @as(f32, @floatFromInt(i)) / characters.len)
            return characters[characters.len - i];
    }

    unreachable;
}
