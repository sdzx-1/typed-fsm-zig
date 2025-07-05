const std = @import("std");
const ps = @import("polystate.zig");
const Mode = ps.Mode;
const Method = ps.Method;
const Adler32 = std.hash.Adler32;

name: []const u8,
mode: Mode,
node_set: std.AutoArrayHashMapUnmanaged(u32, Node),
edge_array_list: std.ArrayListUnmanaged(Edge),
node_id_counter: u32 = 0,

pub const Node = struct {
    name: []const u8,
    id: u32,
};

pub const Edge = struct {
    from: u32,
    to: u32,
    method: ?Method,
    label: []const u8,
};

const Self = @This();

pub const init: Self = .{
    .name = "",
    .mode = .not_suspendable,
    .node_set = .empty,
    .edge_array_list = .empty,
};

pub fn format(
    val: @This(),
    comptime _: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    try writer.writeAll("digraph fsm_state_graph {\n");

    { //state graph
        try writer.writeAll("subgraph cluster_");
        try writer.writeAll(val.name);
        try writer.writeAll(" {\n");

        try writer.writeAll("label = \"");
        try writer.writeAll(val.name);
        try writer.writeAll(
            \\_state_graph";
            \\ labelloc = "t";
            \\ labeljust = "c";
            \\
        );

        var node_set_iter = val.node_set.iterator();
        while (node_set_iter.next()) |entry| {
            try std.fmt.formatIntValue(entry.key_ptr.*, "d", options, writer);
            try writer.writeAll(" [label = \"");
            try std.fmt.formatIntValue(entry.value_ptr.id, "d", options, writer);
            try writer.writeAll("\"];\n");
        }
        for (val.edge_array_list.items) |edge| {
            try std.fmt.formatIntValue(edge.from, "d", options, writer);
            try writer.writeAll(" -> ");
            try std.fmt.formatIntValue(edge.to, "d", options, writer);
            try writer.writeAll(" [label = \"");
            try writer.writeAll(edge.label);
            if (edge.method) |method| {
                switch (method) {
                    .current => {
                        try writer.writeAll("\"");
                    },
                    .next => {
                        try writer.writeAll("\"  color=\"blue\" ");
                    },
                }
            } else {
                try writer.writeAll("\"");
            }

            try writer.writeAll("];\n");
        }

        try writer.writeAll("}\n");
    }

    { //all_state

        try writer.writeAll("subgraph cluster_");
        try writer.writeAll(val.name);
        try writer.writeAll("_state {\n");

        try writer.writeAll("label = \"");
        try writer.writeAll(val.name);
        try writer.writeAll(
            \\_state";
            \\ labelloc = "t";
            \\ labeljust = "c";
            \\
        );

        try writer.writeAll("all_node [shape=plaintext, label=<\n");
        try writer.writeAll("<TABLE BORDER=\"0\" CELLBORDER=\"1\" CELLSPACING=\"0\">\n");

        const nodes = val.node_set.values();

        for (nodes) |node| {
            try writer.writeAll("<TR>");
            try writer.writeAll("<TD ALIGN=\"LEFT\">");
            try std.fmt.formatIntValue(node.id, "d", options, writer);
            try writer.writeAll(" -- ");
            try writer.writeAll(node.name);
            try writer.writeAll("</TD>");
            try writer.writeAll("</TR>\n");
        }

        try writer.writeAll("</TABLE>\n");
        try writer.writeAll(">]\n");

        try writer.writeAll("}\n");
    }

    try writer.writeAll("}\n");
}

pub fn deinit(self: *Self, gpa: std.mem.Allocator) void {
    self.node_set.deinit(gpa);
    self.edge_array_list.deinit(gpa);
}

fn makeHash(
    Ty: type, //State
) u32 {
    return Adler32.hash(@typeName(Ty));
}

pub fn insertEdge(
    graph: *@This(),
    gpa: std.mem.Allocator,
    From: type, //State
    To: type, //State
    method: ?Method,
    label: []const u8,
) !void {
    const from_id: u32 = makeHash(From);
    const to_id: u32 = makeHash(To);
    try graph.edge_array_list.append(
        gpa,
        .{ .from = from_id, .to = to_id, .method = method, .label = label },
    );
}
pub fn generate(graph: *@This(), gpa: std.mem.Allocator, FsmState: type) void {
    graph.name = FsmState.name;
    graph.mode = FsmState.mode;
    dspGenerate(graph, gpa, FsmState.State);
}

fn dspGenerate(graph: *@This(), gpa: std.mem.Allocator, State: type) void {
    const id: u32 = makeHash(State);
    if (graph.node_set.get(id)) |_| {} else {
        graph.node_set.put(gpa, id, .{
            .name = @typeName(State),
            .id = graph.node_id_counter,
        }) catch unreachable;
        graph.node_id_counter += 1;
        switch (@typeInfo(State)) {
            .@"union" => |un| {
                inline for (un.fields) |field| {
                    const edge_label = field.name;
                    const NextFsmState = field.type;
                    const NextState = NextFsmState.State;
                    const method_val = if (NextFsmState.mode == .not_suspendable) null else NextFsmState.transition_method;

                    if (graph.mode == .not_suspendable) {
                        graph.insertEdge(gpa, State, NextState, null, edge_label) catch unreachable;
                    } else {
                        graph.insertEdge(gpa, State, NextState, method_val, edge_label) catch unreachable;
                    }
                    dspGenerate(graph, gpa, NextState);
                }
            },
            else => @compileError("Only support tagged union!"),
        }
    }
}
