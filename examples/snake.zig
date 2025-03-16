const std = @import("std");
const fuizon = @import("fuizon");

const Area = fuizon.area.Area;

const Frame = fuizon.frame.Frame;
const FrameCell = fuizon.frame.FrameCell;

const Style = fuizon.style.Style;
const Color = fuizon.style.Color;
const AnsiColor = fuizon.style.AnsiColor;
const RgbColor = fuizon.style.RgbColor;
const Attribute = fuizon.style.Attribute;
const Attributes = fuizon.style.Attributes;

const Direction = struct { x: i3, y: i3 };
const Position = struct { x: i17, y: i17 };

//
// Port of the Signal & Slot Pattern from QT/C++
//

pub fn Signal(comptime args: anytype) type {
    comptime for (args) |arg| {
        if (@TypeOf(arg) != type)
            @compileError(std.fmt.comptimePrint(
                "expected a tuple of types, found {any}",
                .{@TypeOf(args)},
            ));
    };

    return struct {
        const Self = @This();
        const Handler: type = slot: {
            var info = std.builtin.Type{ .Fn = undefined };
            var params: [args.len + 1]std.builtin.Type.Fn.Param = undefined;
            params[0].is_generic = false;
            params[0].is_noalias = false;
            params[0].type = ?*anyopaque;
            for (args, 1..) |arg, i| {
                params[i].is_generic = false;
                params[i].is_noalias = false;
                params[i].type = arg;
            }
            info.Fn.params = &params;
            info.Fn.is_generic = false;
            info.Fn.is_var_args = false;
            info.Fn.return_type = anyerror!void;
            info.Fn.calling_convention = .Unspecified;
            break :slot @Type(info);
        };
        const Slot = struct {
            receiver: ?*anyopaque,
            handler: *const Handler,
        };

        allocator: std.mem.Allocator,
        slot_list: std.ArrayList(Slot),

        pub fn init(allocator: std.mem.Allocator) Self {
            var signal = @as(Self, undefined);
            signal.allocator = allocator;
            signal.slot_list = std.ArrayList(Slot).init(allocator);
            return signal;
        }

        pub fn deinit(self: Self) void {
            self.slot_list.deinit();
        }

        pub fn connect(self: *Self, receiver: anytype, handler: *const Handler) std.mem.Allocator.Error!void {
            const anyreceiver = @as(?*anyopaque, @ptrCast(@alignCast(@constCast(receiver))));
            try self.slot_list.append(.{ .receiver = anyreceiver, .handler = handler });
        }

        pub fn disconnect(self: *Self, receiver: anytype, handler: *const Handler) void {
            const anyreceiver = @as(?*anyopaque, @ptrCast(@alignCast(@constCast(receiver))));
            for (self.slot_list.items, 0..) |slot, i| {
                if (slot.receiver == anyreceiver and slot.handler == handler) {
                    _ = self.slot_list.swapRemove(i);
                    break;
                }
            }
        }

        pub fn emit(self: Self, params: anytype) anyerror!void {
            for (self.slot_list.items) |slot| {
                try @call(
                    .never_inline,
                    slot.handler,
                    .{slot.receiver} ++ params,
                );
            }
        }
    };
}

//
// TUI Renderer
//

const Renderer = struct {
    allocator: std.mem.Allocator,
    frames: [2]Frame,
    buffer: @TypeOf(std.io.bufferedWriter(std.io.getStdOut().writer())),

    pub fn init(allocator: std.mem.Allocator) std.mem.Allocator.Error!*Renderer {
        const renderer = try allocator.create(Renderer);
        errdefer renderer.deinit();
        renderer.allocator = allocator;
        renderer.frames[0] = Frame.init(allocator);
        renderer.frames[1] = Frame.init(allocator);
        renderer.buffer = std.io.bufferedWriter(std.io.getStdOut().writer());
        return renderer;
    }

    pub fn initFullscreen(allocator: std.mem.Allocator) !*Renderer {
        var renderer = try Renderer.init(allocator);
        errdefer renderer.deinit();

        const render_area = try fuizon.backend.area.fullscreen().render(renderer.writer());
        try renderer.flush();
        const render_frame: *Frame = renderer.frame();

        try render_frame.resize(render_area.width, render_area.height);
        render_frame.moveTo(render_area.origin.x, render_area.origin.y);

        return renderer;
    }

    pub fn deinit(self: *const Renderer) void {
        self.frames[0].deinit();
        self.frames[1].deinit();
        self.allocator.destroy(self);
    }

    pub fn frame(self: anytype) switch (@TypeOf(self)) {
        *const Renderer => *const Frame,
        *Renderer => *Frame,
        else => unreachable,
    } {
        return &self.frames[0];
    }

    pub fn writer(self: *Renderer) @TypeOf(self.buffer).Writer {
        return self.buffer.writer();
    }

    pub fn save(self: *Renderer) std.mem.Allocator.Error!void {
        try self.frames[1].copy(self.frames[0]);
    }

    pub fn render(self: *Renderer) !void {
        try fuizon.backend.frame.render(self.writer(), self.frames[0], self.frames[1]);
    }

    pub fn flush(self: *Renderer) !void {
        try self.buffer.flush();
    }

    //
    // Slots
    //

    pub fn onRenderSignal(receiver: ?*anyopaque, req: RenderRequest) anyerror!void {
        const self = @as(*Renderer, @ptrCast(@alignCast(receiver)));
        try req.callback(req.context, self.frame());
        try self.render();
        try self.save();
        try self.flush();
    }
};

const RenderRequest = struct {
    context: ?*anyopaque,
    callback: *const fn (?*anyopaque, frame: *Frame) anyerror!void,
};

//
// Game View
//

const GameView = struct {
    allocator: std.mem.Allocator,
    model: *GameModel,

    render_signal: Signal(.{RenderRequest}),

    pub fn init(
        allocator: std.mem.Allocator,
        renderer: *Renderer,
        model: *GameModel,
    ) std.mem.Allocator.Error!*GameView {
        const view = try allocator.create(GameView);
        errdefer allocator.destroy(view);
        view.allocator = allocator;
        view.model = model;
        view.render_signal = @TypeOf(view.render_signal).init(allocator);
        errdefer view.render_signal.deinit();
        try view.render_signal.connect(renderer, Renderer.onRenderSignal);
        try model.update_signal.connect(view, GameView.onGameUpdateSignal);
        return view;
    }

    pub fn deinit(self: *const GameView) void {
        self.model.update_signal.disconnect(self, GameView.onGameUpdateSignal);
        self.render_signal.deinit();
        self.allocator.destroy(self);
    }

    pub fn render(self: *const GameView) anyerror!void {
        try self.render_signal.emit(.{RenderRequest{
            .context = @ptrCast(@alignCast(@constCast(self))),
            .callback = (struct {
                fn renderFn(context: ?*anyopaque, frame: *Frame) anyerror!void {
                    const view = @as(*const GameView, @ptrCast(@alignCast(context)));
                    frame.fill(view.model.game.area, .{ .width = 1, .content = ' ', .style = .{} });
                    for (view.model.game.snake.body.items) |item| {
                        frame.index(@intCast(item.position.x + 0), @intCast(item.position.y)).style.background_color = .blue;
                        frame.index(@intCast(item.position.x + 1), @intCast(item.position.y)).style.background_color = .blue;
                    }
                    for (view.model.game.apple_list.items) |item| {
                        frame.index(@intCast(item.position.x + 0), @intCast(item.position.y)).style.background_color = .red;
                        frame.index(@intCast(item.position.x + 1), @intCast(item.position.y)).style.background_color = .red;
                    }
                }
            }).renderFn,
        }});
    }

    //
    // Slots
    //

    pub fn onGameUpdateSignal(receiver: ?*anyopaque) anyerror!void {
        return @as(*const GameView, @ptrCast(@alignCast(receiver))).render();
    }
};

//
// Game Model
//

const GameModel = struct {
    const Modified = struct { game: *Game };

    allocator: std.mem.Allocator,
    game: Game,

    update_signal: Signal(.{}),

    pub fn init(allocator: std.mem.Allocator, area: Area) std.mem.Allocator.Error!*GameModel {
        const state = try allocator.create(GameModel);
        errdefer allocator.destroy(state);
        state.allocator = allocator;
        state.game = try Game.init(allocator, area);
        state.update_signal = @TypeOf(state.update_signal).init(allocator);
        return state;
    }

    pub fn initRandom(
        allocator: std.mem.Allocator,
        area: Area,
        napples: usize,
    ) std.mem.Allocator.Error!*GameModel {
        var state = try GameModel.init(allocator, area);
        errdefer state.deinit();
        for (0..napples) |_|
            try state.game.apple_list.append(Apple.random(area));
        return state;
    }

    pub fn deinit(self: *const GameModel) void {
        self.game.deinit();
        self.update_signal.deinit();
        self.allocator.destroy(self);
    }

    pub fn resize(self: *GameModel, area: Area) std.mem.Allocator.Error!void {
        const napples = self.game.apple_list.items.len;
        self.game.deinit();
        self.game = try Game.init(self.allocator, area);
        for (0..napples) |_|
            try self.game.apple_list.append(Apple.random(area));
    }

    pub fn update(self: GameModel) anyerror!void {
        try self.update_signal.emit(.{});
    }
};

//
// Game
//

const Game = struct {
    score: u64,
    area: Area,
    snake: Snake,
    apple_list: std.ArrayList(Apple),

    pub fn init(allocator: std.mem.Allocator, area: Area) std.mem.Allocator.Error!Game {
        var game: Game = undefined;
        game.score = 0;
        game.area = area;
        game.snake = try Snake.init(allocator, .{ .x = area.origin.x, .y = area.origin.y }, .{ .x = 1, .y = 0 });
        errdefer game.snake.deinit();
        game.apple_list = std.ArrayList(Apple).init(allocator);
        return game;
    }

    pub fn deinit(self: *const Game) void {
        self.snake.deinit();
        self.apple_list.deinit();
    }

    pub fn tick(self: *Game) !void {
        self.snake.tick();
        for (self.apple_list.items) |*apple| {
            if (self.snake.body.items[0].position.x == apple.position.x and
                self.snake.body.items[0].position.y == apple.position.y)
            {
                try self.snake.grow(self.*);
                self.score += 1;
                apple.* = Apple.random(self.area);
            }
        }
    }

    pub fn validate(self: Game) bool {
        return self.snake.validate(self);
    }
};

const Snake = struct {
    body: std.ArrayList(SnakeBodyPart),

    pub fn init(
        allocator: std.mem.Allocator,
        position: Position,
        direction: Direction,
    ) std.mem.Allocator.Error!Snake {
        var snake: Snake = undefined;
        snake.body = std.ArrayList(SnakeBodyPart).init(allocator);
        errdefer snake.body.deinit();
        try snake.body.insert(0, .{ .position = position, .direction = direction });
        return snake;
    }

    pub fn deinit(self: Snake) void {
        self.body.deinit();
    }

    //

    pub fn grow(self: *Snake, game: Game) std.mem.Allocator.Error!void {
        std.debug.assert(self.body.items.len > 0);

        const tail = &self.body.items[self.body.items.len - 1];
        var new_direction = @as(?Direction, null);

        for ([_]Direction{
            // zig fmt: off
            .{ .x =  1, .y =  0 },
            .{ .x = -1, .y =  0 },
            .{ .x =  0, .y =  1 },
            .{ .x =  0, .y = -1 },
            // zig fmt: on
        }) |direction| {
            const x: i17 = tail.position.x - direction.x * 2;
            const y: i17 = tail.position.y - direction.y;

            // zig fmt: off
            if (x >= game.area.left()   and
                x <  game.area.right()  and
                y >= game.area.top()    and
                y <  game.area.bottom()) 
            {
                new_direction = direction;
            } else 
                continue;
            // zig fmt: on

            if (direction.x == tail.direction.x and
                direction.y == tail.direction.y)
                break;
        }

        if (new_direction == null)
            unreachable;

        try self.append(new_direction.?);
    }

    pub fn append(self: *Snake, direction: Direction) std.mem.Allocator.Error!void {
        std.debug.assert(self.body.items.len > 0);
        var position = self.body.items[self.body.items.len - 1].position;
        position.x -= direction.x * 2;
        position.y -= direction.y;
        try self.body.append(.{ .position = position, .direction = direction });
    }

    //

    pub fn redirect(self: *Snake, direction: Direction) void {
        std.debug.assert(self.body.items.len > 0);
        self.body.items[0].direction = direction;
    }

    //

    pub fn tick(self: *Snake) void {
        std.debug.assert(self.body.items.len > 0);
        var index = self.body.items.len - 1;
        while (index > 0) : (index -= 1)
            self.body.items[index] = self.body.items[index - 1];
        self.body.items[0].position.x += self.body.items[0].direction.x * 2;
        self.body.items[0].position.y += self.body.items[0].direction.y;
    }

    pub fn validate(self: Snake, game: Game) bool {
        if (self.body.items.len == 0)
            return false;

        for (self.body.items) |item| {
            // zig fmt: off
            if (item.position.x <  game.area.left()    or
                item.position.x >= game.area.right()   or
                item.position.y <  game.area.top()     or
                item.position.y >= game.area.bottom()) return false;
            // zig fmt: on
        }

        for (0..self.body.items.len) |i| {
            for (i + 1..self.body.items.len) |j| {
                const lhs = &self.body.items[i];
                const rhs = &self.body.items[j];

                if (lhs.position.x == rhs.position.x and
                    lhs.position.y == rhs.position.y)
                    return false;
            }
        }

        return true;
    }

    //
};

const SnakeBodyPart = struct {
    position: Position,
    direction: Direction,
};

const Apple = struct {
    position: Position,

    pub fn random(area: Area) Apple {
        const x = randomEvenInRangeLessThan(i17, 0, @intCast(area.width)) + area.left();
        const y = randomEvenInRangeLessThan(i17, 0, @intCast(area.height)) + area.top();

        return .{ .position = .{ .x = x, .y = y } };
    }

    fn randomEvenInRangeLessThan(comptime T: type, at_least: T, less_than: T) T {
        const r = std.crypto.random.intRangeLessThan(T, at_least, less_than);
        if (@mod(r, 2) == 0) return r;
        if (r + 1 < less_than) return r + 1;
        if (r - 1 >= at_least) return r - 1;
        unreachable;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    //
    // Terminal Render Environment Setup
    //

    const renderer = try Renderer.initFullscreen(allocator);
    defer renderer.deinit();
    defer renderer.flush() catch {};

    const writer = renderer.writer();

    try fuizon.backend.raw_mode.enable();
    defer fuizon.backend.raw_mode.disable() catch {};
    try fuizon.backend.alternate_screen.enter(writer);
    defer fuizon.backend.alternate_screen.leave(writer) catch {};
    try fuizon.backend.cursor.hide(writer);
    defer fuizon.backend.cursor.show(writer) catch {};

    try renderer.flush();

    //
    // Game
    //

    const model = try GameModel.initRandom(allocator, renderer.frame().area, 20);
    defer model.deinit();

    const view = try GameView.init(allocator, renderer, model);
    defer view.deinit();

    //
    // Event Loop
    //

    while (true) {
        if (try fuizon.backend.event.poll()) {
            const event = try fuizon.backend.event.read();
            switch (event) {
                .key => switch (event.key.code) {
                    .char => switch (event.key.code.char) {
                        'q' => break,
                        // zig fmt: off
                        'h' => model.game.snake.redirect(.{ .x = -1, .y =  0 }),
                        'j' => model.game.snake.redirect(.{ .x =  0, .y =  1 }),
                        'k' => model.game.snake.redirect(.{ .x =  0, .y = -1 }),
                        'l' => model.game.snake.redirect(.{ .x =  1, .y =  0 }),
                        // zig fmt: on
                        else => {},
                    },
                    else => {},
                },
                .resize => {
                    try renderer.frame().resize(event.resize.width, event.resize.height);
                    renderer.frame().reset();
                    try model.resize(renderer.frame().area);
                    try model.update();
                    continue;
                },
            }
        }

        try model.game.tick();
        if (!model.game.validate())
            break;
        try model.update();

        std.time.sleep(16 * std.time.ns_per_ms / 1);
    }

    _ = try fuizon.backend.event.read();
}
