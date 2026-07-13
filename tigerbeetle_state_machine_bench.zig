const std = @import("std");

const constants = @import("path/to/tigerbeetle/src/constants.zig");
const MultiBatchEncoder = @import("path/to/tigerbeetle/src/vsr/multi_batch.zig").MultiBatchEncoder;
const TestContext = @import("path/to/tigerbeetle/src/state_machine_tests.zig").TestContext;
const tb = @import("path/to/tigerbeetle/src/tigerbeetle.zig");
const test_options = @import("test_options");

const batch_size = 29;
const operations = if (test_options.benchmark) 30_000 else batch_size;

fn submit(
    context: *TestContext,
    operation: TestContext.StateMachine.Operation,
    comptime Event: type,
    events: []const Event,
    input_buffer: []align(constants.cache_line_size) u8,
    output_buffer: *align(constants.cache_line_size) [constants.message_body_size_max]u8,
) void {
    const event_bytes = std.mem.sliceAsBytes(events);
    std.mem.copyForwards(u8, input_buffer[0..event_bytes.len], event_bytes);

    var encoder = MultiBatchEncoder.init(input_buffer, .{
        .element_size = operation.event_size(),
    });
    encoder.add(@intCast(event_bytes.len));
    const input_size = encoder.finish();
    const input = input_buffer[0..input_size];

    context.prepare(operation, input);
    _ = context.execute(context.op, operation, input, output_buffer);
    context.op += 1;
}

test "benchmark: state machine comparison" {
    if (!test_options.benchmark) return;

    var context: TestContext = undefined;
    try context.init(std.testing.allocator);
    defer context.deinit(std.testing.allocator);

    var input_buffer: [constants.message_body_size_max]u8 align(constants.cache_line_size) = undefined;
    var output_buffer: [constants.message_body_size_max]u8 align(constants.cache_line_size) = undefined;

    var accounts = [_]tb.Account{ std.mem.zeroes(tb.Account), std.mem.zeroes(tb.Account) };
    for (&accounts, 1..) |*account, id| {
        account.id = id;
        account.ledger = 1;
        account.code = 1;
    }
    submit(
        &context,
        .create_accounts,
        tb.Account,
        accounts[0..],
        input_buffer[0..],
        &output_buffer,
    );

    const transfers = try std.testing.allocator.alloc(tb.Transfer, operations);
    defer std.testing.allocator.free(transfers);
    for (transfers, 0..) |*transfer, index| {
        transfer.* = std.mem.zeroes(tb.Transfer);
        transfer.id = 10 + index;
        transfer.debit_account_id = 1;
        transfer.credit_account_id = 2;
        transfer.amount = 1;
        transfer.ledger = 1;
        transfer.code = 1;
    }

    var timer = try std.time.Timer.start();
    for (0..operations / batch_size) |batch| {
        const first = batch * batch_size;
        submit(
            &context,
            .create_transfers,
            tb.Transfer,
            transfers[first .. first + batch_size],
            input_buffer[0..],
            &output_buffer,
        );
    }
    const elapsed_ns = timer.read();
    const elapsed_s = @as(f64, @floatFromInt(elapsed_ns)) / std.time.ns_per_s;
    const operations_per_second = @as(f64, @floatFromInt(operations)) / elapsed_s;
    const batch_latency_ms = elapsed_s * 1_000.0 / @as(f64, @floatFromInt(operations / batch_size));

    std.debug.print("implementation=tigerbeetle-zig\n", .{});
    std.debug.print("operations={d}\n", .{operations});
    std.debug.print("batch_size={d}\n", .{batch_size});
    std.debug.print("operations_per_second={d:.0}\n", .{operations_per_second});
    std.debug.print("batch_latency_ms={d:.3}\n", .{batch_latency_ms});
}
