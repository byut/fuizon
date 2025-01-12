pub const AnsiColor = struct {
    value: u8,
};

pub const RgbColor = struct {
    r: u8,
    g: u8,
    b: u8,
};

pub const Color = union(enum) {
    black,
    white,
    red,
    green,
    blue,
    yellow,
    magenta,
    cyan,
    grey,
    dark_red,
    dark_green,
    dark_blue,
    dark_yellow,
    dark_magenta,
    dark_cyan,
    dark_grey,

    ansi: AnsiColor,
    rgb: RgbColor,
};
