const std = @import("std");
const fuizon = @import("../fuizon.zig");

const Container = fuizon.widgets.container.Container;
const Borders = fuizon.widgets.container.Borders;

const Style = fuizon.style.Style;
const Alignment = fuizon.style.Alignment;

const Area = fuizon.area.Area;
const Frame = fuizon.frame.Frame;
const FrameCell = fuizon.frame.FrameCell;

/// Specifies how to wrap lines if they exceeds the content width.
pub const Wrap = enum {
    /// Instructs the wrapper implementation to wrap lines on a per-character basis.
    ///
    /// For instance, the line 'abcabcabc' with a content width of 5 would wrap to
    /// 'abcab\ncabc'.
    character,
};

pub const Span = struct {
    allocator: std.mem.Allocator,
    content: []const u8,
    style: Style = .{},

    /// Initializes an empty span.
    pub fn init(allocator: std.mem.Allocator) Span {
        return .{
            .allocator = allocator,
            .content = "",
            .style = .{},
        };
    }

    test "init()" {
        const span = Span.init(std.testing.allocator);
        defer span.deinit();
    }

    /// Initializes a new span with the given content using the provided styling.
    pub fn initContent(
        allocator: std.mem.Allocator,
        content: []const u8,
        style: Style,
    ) std.mem.Allocator.Error!Span {
        var span = Span.init(allocator);
        try span.setContent(content);
        span.style = style;
        return span;
    }

    test "initContent()" {
        const span = try Span.initContent(std.testing.allocator, "content", .{});
        defer span.deinit();
    }

    /// Updates span content.
    pub fn setContent(
        self: *Span,
        content: []const u8,
    ) std.mem.Allocator.Error!void {
        const new_content = try self.allocator.dupe(u8, content);
        errdefer comptime unreachable;

        if (self.content.len > 0)
            self.allocator.free(self.content);
        self.content = new_content;
    }

    test "setContent()" {
        var span = Span.init(std.testing.allocator);
        defer span.deinit();
        try span.setContent("content");
        try std.testing.expectEqualStrings("content", span.content);
    }

    /// Makes a copy of the span using the same allocator.
    pub fn clone(self: Span) std.mem.Allocator.Error!Span {
        return Span.initContent(
            self.allocator,
            self.content,
            self.style,
        );
    }

    test "clone()" {
        const span = try Span.initContent(std.testing.allocator, "content", .{ .foreground_color = .blue });
        defer span.deinit();
        const copy = try span.clone();
        defer copy.deinit();

        try std.testing.expectEqualDeep(span.style, copy.style);
        try std.testing.expectEqualStrings(span.content, copy.content);
        try std.testing.expect(span.content.ptr != copy.content.ptr);
    }

    /// Deinitializes the span.
    pub fn deinit(self: Span) void {
        if (self.content.len > 0)
            self.allocator.free(self.content);
    }
};

pub const Line = struct {
    allocator: std.mem.Allocator,
    alignment: Alignment = .start,
    span_list: std.ArrayList(Span),

    /// Initializes an empty line with custom alignment.
    pub fn init(allocator: std.mem.Allocator, alignment: Alignment) Line {
        var line: Line = undefined;
        line.allocator = allocator;
        line.alignment = alignment;
        line.span_list = std.ArrayList(Span).init(allocator);
        return line;
    }

    test "init() with left alignment" {
        const line = Line.init(std.testing.allocator, .start);
        defer line.deinit();

        try std.testing.expectEqual(.start, line.alignment);
    }

    test "init() with center alignment" {
        const line = Line.init(std.testing.allocator, .center);
        defer line.deinit();

        try std.testing.expectEqual(.center, line.alignment);
    }

    test "init() with right alignment" {
        const line = Line.init(std.testing.allocator, .end);
        defer line.deinit();

        try std.testing.expectEqual(.end, line.alignment);
    }

    /// Initializes a new line from the provided spans.
    pub fn fromSpans(
        allocator: std.mem.Allocator,
        alignment: Alignment,
        spans: []const Span,
    ) std.mem.Allocator.Error!Line {
        var line = Line.init(allocator, alignment);
        errdefer line.deinit();
        for (spans) |span|
            try line.span_list.append(span);
        return line;
    }

    test "fromSpans()" {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        const spans = [_]Span{
            try Span.initContent(allocator, "first", .{}),
            try Span.initContent(allocator, "second", .{}),
            try Span.initContent(allocator, "third", .{}),
        };

        const line = try Line.fromSpans(std.testing.allocator, undefined, &spans);
        defer line.deinit();

        try std.testing.expectEqualSlices(Span, &spans, line.span_list.items);
    }

    /// Initializes a new line with custom alignment and the given string using
    /// the provided styling.
    pub fn fromString(
        allocator: std.mem.Allocator,
        alignment: Alignment,
        content: []const u8,
        style: Style,
    ) std.mem.Allocator.Error!Line {
        const span = try Span.initContent(allocator, content, style);
        errdefer span.deinit();
        return Line.fromSpans(allocator, alignment, &.{span});
    }

    test "fromString()" {
        const line = try Line.fromString(std.testing.allocator, undefined, "content", .{ .foreground_color = .blue });
        defer line.deinit();

        try std.testing.expectEqual(1, line.span_list.items.len);
        try std.testing.expectEqualStrings("content", line.span_list.items[0].content);
        try std.testing.expectEqualDeep(Style{ .foreground_color = .blue }, line.span_list.items[0].style);
    }

    /// Makes a copy of the line using the same allocator.
    pub fn clone(self: Line) std.mem.Allocator.Error!Line {
        var line = Line.init(self.allocator, self.alignment);
        errdefer line.deinit();
        for (self.span_list.items) |span| {
            const copy = try span.clone();
            errdefer copy.deinit();
            try line.span_list.append(copy);
        }
        return line;
    }

    test "clone()" {
        const line = try Line.fromString(std.testing.allocator, undefined, "content", .{ .foreground_color = .blue });
        defer line.deinit();
        const copy = try line.clone();
        defer copy.deinit();

        try std.testing.expectEqual(line.span_list.items.len, copy.span_list.items.len);
        try std.testing.expectEqualStrings(line.span_list.items[0].content, copy.span_list.items[0].content);
        try std.testing.expectEqualDeep(line.span_list.items[0].style, copy.span_list.items[0].style);
        try std.testing.expect(line.span_list.items.ptr != copy.span_list.items.ptr);
    }

    /// Deinitializes the line.
    pub fn deinit(self: Line) void {
        for (self.span_list.items) |span|
            span.deinit();
        self.span_list.deinit();
    }

    /// Returns the number of characters in the line.
    pub fn length(self: Line) usize {
        var it = self.iterator();
        var counter: usize = 0;
        while (it.next()) |item| : (counter += item.width) {}
        return counter;
    }

    test "length() on empty line" {
        const line = Line.init(std.testing.allocator, undefined);
        defer line.deinit();

        try std.testing.expectEqual(0, line.length());
    }

    test "length() [1]" {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        const line = try Line.fromSpans(std.testing.allocator, undefined, &.{
            try Span.initContent(allocator, "söme cöntent ", .{}),
            try Span.initContent(allocator, "", .{}),
            Span.init(allocator),
            try Span.initContent(allocator, "with unicöde cödepöints", .{}),
        });
        defer line.deinit();

        try std.testing.expectEqual(36, line.length());
    }

    /// Initializes the line iterator.
    pub fn iterator(self: *const Line) Iterator {
        var it: Iterator = undefined;
        it.line = self;
        it.current_span = 0;

        // zig fmt: off
        const content: []const u8 =
            if (it.line.span_list.items.len > 0)
                it.line.span_list.items[0].content
            else
                "";
        // zig fmt: on

        it.current_character = (std.unicode.Utf8View.init(content) catch unreachable).iterator();

        return it;
    }

    pub const Iterator = struct {
        line: *const Line,
        current_span: usize,
        current_character: std.unicode.Utf8Iterator,

        pub fn next(self: *Iterator) ?FrameCell {
            if (self.current_span == self.line.span_list.items.len)
                return null;

            while (true) {
                if (self.current_character.nextCodepoint()) |codepoint| {
                    return .{
                        .width = 1,
                        .content = codepoint,
                        .style = self.line.span_list.items[self.current_span].style,
                    };
                }

                self.current_span += 1;
                if (self.current_span == self.line.span_list.items.len)
                    break;
                // zig fmt: off
                self.current_character =
                    (std.unicode.Utf8View.init(
                        self.line.span_list.items[self.current_span].content,
                        ) catch unreachable).iterator();
                // zig fmt: on
            }

            return null;
        }
    };
};

pub const Text = struct {
    allocator: std.mem.Allocator,
    line_list: std.ArrayList(Line),

    /// Initializes an empty block of text.
    pub fn init(allocator: std.mem.Allocator) Text {
        var text: Text = undefined;
        text.allocator = allocator;
        text.line_list = std.ArrayList(Line).init(allocator);
        return text;
    }

    test "init()" {
        const text = Text.init(std.testing.allocator);
        defer text.deinit();
    }

    /// Initializes a new text by merging the provided lines.
    pub fn initLines(
        allocator: std.mem.Allocator,
        lines: []const Line,
    ) std.mem.Allocator.Error!Text {
        var text = Text.init(allocator);
        errdefer text.deinit();
        for (lines) |line|
            try text.line_list.append(line);
        return text;
    }

    test "initLines()" {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        const lines = [_]Line{
            try Line.fromSpans(allocator, .end, &.{
                try Span.initContent(allocator, "content", .{}),
                Span.init(allocator),
                try Span.initContent(allocator, "", .{ .background_color = .green }),
            }),
            Line.init(allocator, .center),
            try Line.fromString(allocator, .start, "string", .{}),
        };

        const text = try Text.initLines(std.testing.allocator, &lines);
        defer text.deinit();

        try std.testing.expectEqualSlices(Line, &lines, text.line_list.items);
    }

    /// Makes a copy of the text using the same allocator.
    pub fn clone(self: Text) std.mem.Allocator.Error!Text {
        var text = Text.init(self.allocator);
        errdefer text.deinit();
        for (self.line_list.items) |line| {
            const copy = try line.clone();
            errdefer copy.deinit();
            try text.line_list.append(copy);
        }
        return text;
    }

    test "clone()" {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        const text = try Text.initLines(std.testing.allocator, &.{try Line.fromString(allocator, .start, "content", .{ .foreground_color = .red })});
        defer text.deinit();

        const copy = try text.clone();
        defer copy.deinit();

        try std.testing.expectEqual(text.line_list.items.len, copy.line_list.items.len);
        try std.testing.expectEqualDeep(text.line_list.items[0], copy.line_list.items[0]);
        try std.testing.expect(text.line_list.items.ptr != copy.line_list.items.ptr);
    }

    /// Deinitializes the block of text.
    pub fn deinit(self: Text) void {
        for (self.line_list.items) |line|
            line.deinit();
        self.line_list.deinit();
    }
};

//

pub const Paragraph = struct {
    allocator: std.mem.Allocator,
    text_frames: []Frame,
    text: Text,

    container: Container,

    /// Initializes a new Paragraph.
    pub fn init(allocator: std.mem.Allocator) Paragraph {
        var paragraph: Paragraph = undefined;
        paragraph.allocator = allocator;
        paragraph.text = Text.init(allocator);
        paragraph.text_frames = &.{};
        paragraph.container = .{};
        return paragraph;
    }

    /// Deinitializes the Paragraph.
    pub fn deinit(self: Paragraph) void {
        for (self.text_frames) |text_frame|
            text_frame.deinit();
        if (self.text_frames.len > 0)
            self.allocator.free(self.text_frames);

        self.text.deinit();
    }

    //

    /// Returns the width required to fully render the paragraph.
    pub fn width(self: Paragraph) u16 {
        var max_width: u16 = 0;
        for (self.text_frames) |text_frame| {
            if (text_frame.area.width > max_width)
                max_width = text_frame.area.width;
        }

        // zig fmt: off
        return max_width
            + self.container.margin_left + self.container.margin_right
            + (if (self.container.borders.contain(&.{.left}))  @as(u16, 1) else @as(u16, 0))
            + (if (self.container.borders.contain(&.{.right})) @as(u16, 1) else @as(u16, 0));
        // zig fmt: on
    }

    /// Returns the height required to fully render the paragraph.
    pub fn height(self: Paragraph) u16 {
        var h: u16 = 0;
        for (self.text_frames) |text_frame|
            h += text_frame.area.height;
        // zig fmt: off
        return h
            + self.container.margin_top + self.container.margin_bottom
            + (if (self.container.borders.contain(&.{.top}))    @as(u16, 1) else @as(u16, 0))
            + (if (self.container.borders.contain(&.{.bottom})) @as(u16, 1) else @as(u16, 0));
        // zig fmt: on
    }

    //

    /// Adjusts the paragraph dimensions to fit the given text without wrapping.
    pub fn fit(self: *Paragraph, source_text: Text) std.mem.Allocator.Error!void {
        const text = try source_text.clone();
        errdefer text.deinit();
        const text_frames = try self.allocator.alloc(Frame, text.line_list.items.len);
        errdefer self.allocator.free(text_frames);
        for (text_frames) |*text_frame| text_frame.* = Frame.init(self.allocator);
        errdefer for (text_frames) |text_frame| text_frame.deinit();

        for (text_frames, 0..) |*text_frame, i| {
            try text_frame.resize(@intCast(text.line_list.items[i].length()), 1);
            var x: u16 = 0;
            var it = text.line_list.items[i].iterator();
            while (it.next()) |item| : (x += item.width)
                text_frame.index(x, 0).* = item;
        }

        errdefer comptime unreachable;

        for (self.text_frames) |text_frame|
            text_frame.deinit();
        if (self.text_frames.len > 0)
            self.allocator.free(self.text_frames);
        self.text.deinit();

        self.text_frames = text_frames;
        self.text = text;
    }

    /// Adjusts the paragraph dimensions to fit the given text within the
    /// specified width. Text is thereby wrapped based on the selected method.
    pub fn wrap(
        self: *Paragraph,
        source_text: Text,
        content_width: u16,
        method: Wrap,
    ) std.mem.Allocator.Error!void {
        // as there is currently only one method, we can ignore its
        // specification here.
        _ = method;

        const text = try source_text.clone();
        errdefer text.deinit();
        const text_frames = try self.allocator.alloc(Frame, text.line_list.items.len);
        errdefer self.allocator.free(text_frames);
        for (text_frames) |*text_frame| text_frame.* = Frame.init(self.allocator);
        errdefer for (text_frames) |text_frame| text_frame.deinit();

        e: {
            if (content_width == 0) {
                for (text_frames) |*text_frame|
                    try text_frame.resize(0, 0);

                break :e;
            }

            for (text_frames, 0..) |*text_frame, i| {
                const line = text.line_list.items[i];
                const line_width = line.length();

                try text_frame.resize(
                    content_width,
                    @intFromFloat(@ceil(@as(f64, @floatFromInt(line_width)) / @as(f64, @floatFromInt(content_width)))),
                );

                var buffer_iterator: usize = 0;
                var line_iterator = line.iterator();
                while (line_iterator.next()) |cell| : (buffer_iterator += cell.width) {
                    if (buffer_iterator % content_width == 0) {
                        buffer_iterator += switch (line.alignment) {
                            // zig fmt: off
                            .start  => 0,
                            .center => (content_width -| (line_width - buffer_iterator)) / 2,
                            .end    => (content_width -| (line_width - buffer_iterator)),
                            // zig fmt: on
                        };
                    }
                    text_frame.buffer[buffer_iterator] = cell;
                }
            }
        }

        errdefer comptime unreachable;

        for (self.text_frames) |text_frame|
            text_frame.deinit();
        if (self.text_frames.len > 0)
            self.allocator.free(self.text_frames);
        self.text.deinit();

        self.text_frames = text_frames;
        self.text = text;
    }

    //

    /// Renders the block of text to the frame within the given area.
    pub fn render(self: Paragraph, frame: *Frame, area: Area) void {
        self.container.render(frame, area);
        const inner_area = self.container.inner(area);
        var render_y = inner_area.top();
        for (self.text_frames, 0..) |text_frame, i| {
            const line = self.text.line_list.items[i];
            for (text_frame.area.top()..text_frame.area.bottom()) |y| {
                if (render_y >= inner_area.bottom())
                    return;
                var render_x = switch (line.alignment) {
                    // zig fmt: off
                    .start  => inner_area.left(),
                    .center => inner_area.left() + (inner_area.width -| text_frame.area.width) / 2,
                    .end    => inner_area.left() + (inner_area.width -| text_frame.area.width),
                    // zig fmt: on
                };
                for (text_frame.area.left()..text_frame.area.right()) |x| {
                    if (render_x >= inner_area.right())
                        break;
                    frame.index(render_x, render_y).* = text_frame.index(@intCast(x), @intCast(y)).*;
                    render_x += 1;
                }
                render_y += 1;
            }
        }
    }
};

//
// Tests
//

test "fit()" {
    const TestCase = struct {
        const Self = @This();

        id: usize,

        content: []const []const u8,
        content_alignment: Alignment,

        borders: Borders = Borders.none,
        margin_top: u16 = 0,
        margin_bottom: u16 = 0,
        margin_left: u16 = 0,
        margin_right: u16 = 0,

        expected: []const []const u8,

        pub fn test_fn(self: Self) type {
            return struct {
                test {
                    const expected_frame = try Frame.initContent(std.testing.allocator, self.expected, .{});
                    defer expected_frame.deinit();

                    var actual_frame = try Frame.initArea(std.testing.allocator, expected_frame.area);
                    defer actual_frame.deinit();

                    var text = Text.init(std.testing.allocator);
                    defer text.deinit();
                    for (self.content) |line|
                        try text.line_list.append(try Line.fromString(
                            std.testing.allocator,
                            self.content_alignment,
                            line,
                            .{},
                        ));

                    var paragraph = Paragraph.init(std.testing.allocator);
                    defer paragraph.deinit();
                    paragraph.container.borders = self.borders;
                    paragraph.container.margin_top = self.margin_top;
                    paragraph.container.margin_bottom = self.margin_bottom;
                    paragraph.container.margin_left = self.margin_left;
                    paragraph.container.margin_right = self.margin_right;
                    try paragraph.fit(text);
                    paragraph.render(&actual_frame, .{
                        .width = paragraph.width(),
                        .height = paragraph.height(),
                        .origin = actual_frame.area.origin,
                    });

                    try std.testing.expectEqualSlices(
                        FrameCell,
                        expected_frame.buffer,
                        actual_frame.buffer,
                    );
                }
            };
        }
    };

    inline for ([_]TestCase{
        .{
            .id = 0,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .start,
            .expected = &[_][]const u8{
                "hello world              ",
                "this is a multi-line text",
            },
        },
        .{
            .id = 1,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .center,
            .expected = &[_][]const u8{
                "       hello world       ",
                "this is a multi-line text",
            },
        },
        .{
            .id = 2,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .end,
            .expected = &[_][]const u8{
                "              hello world",
                "this is a multi-line text",
            },
        },
        .{
            .id = 3,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .end,
            .margin_top = 1,
            .expected = &[_][]const u8{
                "                         ",
                "              hello world",
                "this is a multi-line text",
            },
        },
        .{
            .id = 4,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .end,
            .margin_left = 1,
            .expected = &[_][]const u8{
                "               hello world",
                " this is a multi-line text",
            },
        },
        .{
            .id = 5,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .end,
            .margin_right = 1,
            .expected = &[_][]const u8{
                "              hello world ",
                "this is a multi-line text ",
            },
        },
        .{
            .id = 6,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .end,
            .margin_bottom = 1,
            .expected = &[_][]const u8{
                "              hello world",
                "this is a multi-line text",
                "                         ",
            },
        },
        .{
            .id = 7,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .start,
            .borders = Borders.all,
            .expected = &[_][]const u8{
                "┌─────────────────────────┐",
                "│hello world              │",
                "│this is a multi-line text│",
                "└─────────────────────────┘",
            },
        },
        .{
            .id = 8,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .center,
            .borders = Borders.all,
            .expected = &[_][]const u8{
                "┌─────────────────────────┐",
                "│       hello world       │",
                "│this is a multi-line text│",
                "└─────────────────────────┘",
            },
        },
        .{
            .id = 9,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .end,
            .borders = Borders.all,
            .expected = &[_][]const u8{
                "┌─────────────────────────┐",
                "│              hello world│",
                "│this is a multi-line text│",
                "└─────────────────────────┘",
            },
        },
        .{
            .id = 10,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .center,
            .margin_top = 1,
            .margin_bottom = 1,
            .margin_left = 1,
            .margin_right = 1,
            .borders = Borders.all,
            .expected = &[_][]const u8{
                "┌───────────────────────────┐",
                "│                           │",
                "│        hello world        │",
                "│ this is a multi-line text │",
                "│                           │",
                "└───────────────────────────┘",
            },
        },
    }) |test_case| {
        _ = test_case.test_fn();
    }
}

test "wrap()" {
    const TestCase = struct {
        const Self = @This();

        id: usize,

        content: []const []const u8,
        content_width: u16,
        content_wrap: Wrap = .character,
        content_alignment: Alignment,

        borders: Borders = Borders.none,

        // title: ?[]const u8 = null,
        // title_style: Style = undefined,
        // title_alignment: Alignment = undefined,

        expected: []const []const u8,

        pub fn test_fn(self: Self) type {
            return struct {
                test {
                    const expected_frame = try Frame.initContent(std.testing.allocator, self.expected, .{});
                    defer expected_frame.deinit();

                    var actual_frame = try Frame.initArea(std.testing.allocator, expected_frame.area);
                    defer actual_frame.deinit();

                    var text = Text.init(std.testing.allocator);
                    defer text.deinit();
                    for (self.content) |line|
                        try text.line_list.append(try Line.fromString(
                            std.testing.allocator,
                            self.content_alignment,
                            line,
                            .{},
                        ));

                    var paragraph = Paragraph.init(std.testing.allocator);
                    defer paragraph.deinit();
                    paragraph.container.borders = self.borders;
                    try paragraph.wrap(text, self.content_width, self.content_wrap);
                    paragraph.render(&actual_frame, actual_frame.area);

                    try std.testing.expectEqualSlices(
                        FrameCell,
                        expected_frame.buffer,
                        actual_frame.buffer,
                    );
                }
            };
        }
    };

    inline for ([_]TestCase{
        .{
            .id = 0,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .start,
            .content_width = 15,
            .expected = &[_][]const u8{
                "hello world    ",
                "this is a multi",
                "-line text     ",
            },
        },
        .{
            .id = 1,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .center,
            .content_width = 15,
            .expected = &[_][]const u8{
                "  hello world  ",
                "this is a multi",
                "  -line text   ",
            },
        },
        .{
            .id = 2,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .end,
            .content_width = 15,
            .expected = &[_][]const u8{
                "    hello world",
                "this is a multi",
                "     -line text",
            },
        },
        .{
            .id = 3,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .start,
            .content_width = 11,
            .expected = &[_][]const u8{
                "hello world    ",
                "this is a m    ",
                "ulti-line t    ",
            },
        },
        .{
            .id = 4,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .center,
            .content_width = 11,
            .expected = &[_][]const u8{
                "  hello world  ",
                "  this is a m  ",
                "  ulti-line t  ",
            },
        },
        .{
            .id = 5,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .end,
            .content_width = 11,
            .expected = &[_][]const u8{
                "    hello world",
                "    this is a m",
                "    ulti-line t",
            },
        },
        .{
            .id = 6,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .start,
            .content_width = 16,
            .expected = &[_][]const u8{
                "hello world    ",
                "this is a multi",
                "line text      ",
            },
        },
        .{
            .id = 7,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .center,
            .content_width = 16,
            .expected = &[_][]const u8{
                "  hello world  ",
                "this is a multi",
                "   line text   ",
            },
        },
        .{
            .id = 8,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .end,
            .content_width = 16,
            .expected = &[_][]const u8{
                "     hello worl",
                "this is a multi",
                "       line tex",
            },
        },
        .{
            .id = 9,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .end,
            .content_width = 0,
            .expected = &[_][]const u8{},
        },
        .{
            .id = 10,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .end,
            .content_width = 15,
            .expected = &[_][]const u8{
                "    hello world",
                "this is a multi",
            },
        },
        .{
            .id = 11,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .borders = Borders.all,
            .content_alignment = .start,
            .content_width = 15,
            .expected = &[_][]const u8{
                "┌───────────────┐",
                "│hello world    │",
                "│this is a multi│",
                "│-line text     │",
                "└───────────────┘",
            },
        },
        .{
            .id = 12,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .borders = Borders.all,
            .content_alignment = .center,
            .content_width = 15,
            .expected = &[_][]const u8{
                "┌───────────────┐",
                "│  hello world  │",
                "│this is a multi│",
                "│  -line text   │",
                "└───────────────┘",
            },
        },
        .{
            .id = 13,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .borders = Borders.all,
            .content_alignment = .end,
            .content_width = 15,
            .expected = &[_][]const u8{
                "┌───────────────┐",
                "│    hello world│",
                "│this is a multi│",
                "│     -line text│",
                "└───────────────┘",
            },
        },
        .{
            .id = 14,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .borders = Borders.all,
            .content_alignment = .start,
            .content_width = 11,
            .expected = &[_][]const u8{
                "┌───────────────┐",
                "│hello world    │",
                "│this is a m    │",
                "│ulti-line t    │",
                "└───────────────┘",
            },
        },
        .{
            .id = 15,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .borders = Borders.all,
            .content_alignment = .center,
            .content_width = 11,
            .expected = &[_][]const u8{
                "┌───────────────┐",
                "│  hello world  │",
                "│  this is a m  │",
                "│  ulti-line t  │",
                "└───────────────┘",
            },
        },
        .{
            .id = 16,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .borders = Borders.all,
            .content_alignment = .end,
            .content_width = 11,
            .expected = &[_][]const u8{
                "┌───────────────┐",
                "│    hello world│",
                "│    this is a m│",
                "│    ulti-line t│",
                "└───────────────┘",
            },
        },
        .{
            .id = 17,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .borders = Borders.all,
            .content_alignment = .start,
            .content_width = 16,
            .expected = &[_][]const u8{
                "┌───────────────┐",
                "│hello world    │",
                "│this is a multi│",
                "│line text      │",
                "└───────────────┘",
            },
        },
        .{
            .id = 18,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .borders = Borders.all,
            .content_alignment = .center,
            .content_width = 16,
            .expected = &[_][]const u8{
                "┌───────────────┐",
                "│  hello world  │",
                "│this is a multi│",
                "│   line text   │",
                "└───────────────┘",
            },
        },
        .{
            .id = 19,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .borders = Borders.all,
            .content_alignment = .end,
            .content_width = 16,
            .expected = &[_][]const u8{
                "┌───────────────┐",
                "│     hello worl│",
                "│this is a multi│",
                "│       line tex│",
                "└───────────────┘",
            },
        },
        .{
            .id = 20,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .borders = Borders.all,
            .content_alignment = .end,
            .content_width = 0,
            .expected = &[_][]const u8{
                "┌┐",
                "└┘",
            },
        },
        .{
            .id = 21,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .borders = Borders.none,
            .content_alignment = .end,
            .content_width = 0,
            .expected = &[_][]const u8{
                "",
            },
        },
        .{
            .id = 22,
            .content = &[_][]const u8{},
            .borders = Borders.all,
            .content_alignment = .start,
            .content_width = 5,
            .expected = &[_][]const u8{
                "┌─────┐",
                "│     │",
                "└─────┘",
            },
        },
        .{
            .id = 23,
            .content = &[_][]const u8{},
            .borders = Borders.none,
            .content_alignment = .start,
            .content_width = 5,
            .expected = &[_][]const u8{
                "     ",
            },
        },
        .{
            .id = 24,
            .content = &[_][]const u8{},
            .borders = Borders.all,
            .content_alignment = .start,
            .content_width = 0,
            .expected = &[_][]const u8{
                "┌┐",
                "└┘",
            },
        },
        .{
            .id = 25,
            .content = &[_][]const u8{},
            .borders = Borders.none,
            .content_alignment = .start,
            .content_width = 0,
            .expected = &[_][]const u8{
                "",
            },
        },
    }) |test_case| {
        _ = test_case.test_fn();
    }
}
