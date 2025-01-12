const std = @import("std");
const c = @cImport({
    @cInclude("crossterm_ffi/event.h");
});

// zig fmt: off
pub const KeyModifiers = struct {
    pub const NONE:     u16 = 0;
    pub const SHIFT:    u16 = 1 << 0;
    pub const CONTROL:  u16 = 1 << 1;
    pub const ALT:      u16 = 1 << 2;
    pub const SUPER:    u16 = 1 << 3;
    pub const HYPER:    u16 = 1 << 4;
    pub const META:     u16 = 1 << 5;
    pub const KEYPAD:   u16 = 1 << 6;
    pub const CAPS:     u16 = 1 << 7;
    pub const NUM_LOCK: u16 = 1 << 8;
    pub const ALL:      u16 = 0x1ff;
};
// zig fmt: on

pub const KeyEventType = enum(u8) {
    char = 0,
    backspace,
    enter,
    left_arrow,
    right_arrow,
    up_arrow,
    down_arrow,
    home,
    end,
    page_up,
    page_down,
    tab,
    backtab,
    delete,
    insert,
    escape,

    f1 = 244,
    f2,
    f3,
    f4,
    f5,
    f6,
    f7,
    f8,
    f9,
    f10,
    f11,
    f12,
};

pub const KeyEvent = struct {
    type: KeyEventType,
    code: u21,
    modifiers: u16,
};

pub const ResizeEvent = struct {
    width: u16,
    height: u16,
};

pub const Event = union(enum) {
    key: KeyEvent,
    resize: ResizeEvent,
};

fn from_crossterm_key_event_to_fuizon_key_event(event: c.crossterm_key_event) KeyEvent {
    var result: KeyEvent = undefined;
    result.type = @enumFromInt(event.type);
    result.code = @intCast(event.code);
    result.modifiers = event.modifiers;
    return result;
}

fn from_crossterm_resize_event_to_fuizon_resize_event(event: c.crossterm_resize_event) ResizeEvent {
    var result: ResizeEvent = undefined;
    result.width = event.width;
    result.height = event.height;
    return result;
}

fn from_crossterm_event_to_fuizon_event(event: c.crossterm_event) Event {
    var result: Event = undefined;
    switch (event.type) {
        c.CROSSTERM_KEY_EVENT => result = .{ .key = from_crossterm_key_event_to_fuizon_key_event(event.unnamed_0.key) },
        c.CROSSTERM_RESIZE_EVENT => result = .{ .resize = from_crossterm_resize_event_to_fuizon_resize_event(event.unnamed_0.resize) },

        else => unreachable,
    }
    return result;
}

pub fn read() !Event {
    var ret: c_int = 0;
    var event: c.crossterm_event = std.mem.zeroes(c.crossterm_event);

    ret = c.crossterm_event_read(&event);
    if (0 != ret) {
        return error.EventReadError;
    }

    return from_crossterm_event_to_fuizon_event(event);
}

pub fn poll() !bool {
    var ret: c_int = 0;
    var is_available: c_int = 0;
    ret = c.crossterm_event_poll(&is_available);
    if (0 != ret) {
        return error.EventPollError;
    }
    return if (is_available == 1) true else false;
}
