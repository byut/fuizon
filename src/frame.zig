const std = @import("std");
const fuizon = @import("fuizon.zig");
const c = @cImport({
    @cInclude("crossterm_ffi/stream.h");
});

const Style = fuizon.Style;

const VerticalAnchor = fuizon.VerticalAnchor;
const HorizontalAnchor = fuizon.HorizontalAnchor;

pub const FrameCell = struct {
    content: u21,
    style: Style,
};

// ...
pub const Frame = struct {
    allocator: std.mem.Allocator,

    xanchor: HorizontalAnchor,
    yanchor: VerticalAnchor,
    xoffset: u16,
    yoffset: u16,

    width: u16,
    height: u16,

    buffer: std.ArrayList(FrameCell),
    stream: *c.crossterm_stream,

    pub fn init(allocator: std.mem.Allocator, stream: *c.crossterm_stream) Frame {
        return .{
            .allocator = allocator,
            .xanchor = .left,
            .yanchor = .top,
            .xoffset = 0,
            .yoffset = 0,
            .width = 0,
            .height = 0,
            .buffer = std.ArrayList(FrameCell).init(allocator),
            .stream = stream,
        };
    }

    pub fn deinit(self: *Frame) void {
        self.buffer.deinit();
    }

    pub fn get(self: *Frame, row: usize, col: usize) !*FrameCell {
        if (row >= self.height or col >= self.width) return error.OutOfRange;
        return self.get_unchecked(row, col);
    }

    pub fn get_unchecked(self: *Frame, row: usize, col: usize) *FrameCell {
        return &self.buffer.items[row * self.width + col];
    }

    pub fn resize(self: *Frame, width: u16, height: u16) !void {
        self.width = width;
        self.height = height;
        try self.buffer.resize(self.width * self.height);
    }

    pub fn clear(self: *Frame) void {
        for (self.buffer.items) |*item| {
            item.content = ' ';
            item.style = .{
                .foreground_color = null,
                .background_color = null,
                .underline_color = null,
                .attributes = 0,
            };
        }
    }

    pub fn clone(self: *const Frame) Frame {
        var frame: Frame = undefined;
        @memcpy(&frame, self);
        return frame;
    }
};
