pub fn Witness(T: type, end: T, start: T) type {
    switch (@typeInfo(T)) {
        .@"enum" => |tenum| {
            const i: usize = @intFromEnum(start);
            const ename = tenum.fields[i].name;
            const stru = @field(T, ename ++ "Msg")(end);
            return struct {
                pub const wtype = T;
                pub const wstart = start;
                pub const wend = end;
                pub fn render(_: @This()) @TypeOf(stru.render) {
                    if (end == start) @compileError("Can't render");
                    return stru.render;
                }
                pub fn getMsg(_: @This()) @TypeOf(stru.genMsg) {
                    if (end == start) @compileError("Can't getMsg");
                    return stru.genMsg;
                }

                pub fn terminal(_: @This()) void {
                    if (end != start) @compileError("Can't terminal");
                    return {};
                }
            };
        },
        else => @compileError("The type not support, it must be enum"),
    }
}
