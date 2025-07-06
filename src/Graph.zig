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

//GitHub markdown does not yet support elk layout
//When the number of nodes or edges is too large, mermaid is not as good as graphviz
pub fn print_mermaid(
    self: @This(),
    writer: anytype,
) !void {
    try writer.print(
        \\---
        \\config:
        \\  look: handDrawn
        \\  layout: elk
        \\  elk:
        \\    mergeEdges: false
        \\    nodePlacementStrategy: LINEAR_SEGMENTS
        \\title: {s}
        \\---
        \\stateDiagram-v2
        \\
    , .{self.name});

    var node_set_iter = self.node_set.iterator();
    while (node_set_iter.next()) |entry| {
        try writer.print("    {d}: {s}\n", .{ entry.key_ptr.*, entry.value_ptr.name });
    }

    std.debug.print("\n", .{});

    for (self.edge_array_list.items) |edge| {
        const sym = if (edge.method) |method| switch (method) {
            .next => "↪",
            .current => "",
        } else "";
        try writer.print("    {d} --> {d}: {s} {s}\n", .{ edge.from, edge.to, sym, edge.label });
    }
}

pub fn print_graphviz(
    self: @This(),
    writer: anytype,
) !void {
    try writer.writeAll("digraph fsm_state_graph {\n");

    { //state graph
        try writer.print(
            \\  subgraph cluster_{s} {s}
            \\    label = "{s}_graph";
            \\    labelloc = "t";
            \\    labeljust = "c";
            \\
        , .{
            self.name, "{", self.name,
        });

        var node_set_iter = self.node_set.iterator();
        while (node_set_iter.next()) |entry| {
            try writer.print("    {d} [label = \"{d}\"];\n", .{ entry.key_ptr.*, entry.value_ptr.id });
        }
        for (self.edge_array_list.items) |edge| {
            try writer.print("    {d} -> {d} [label = \"{s}", .{ edge.from, edge.to, edge.label });
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

        try writer.writeAll("  }\n");
    }

    { //all_state

        try writer.print(
            \\  subgraph cluster_{s}_state {s}
            \\    label = "{s}_state";
            \\    labelloc = "t";
            \\    labeljust = "c";
            \\    all_node [shape=plaintext, label=<
            \\      <TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0">
        ,
            .{ self.name, "{", self.name },
        );

        const nodes = self.node_set.values();

        for (nodes) |node| {
            try writer.print(
                \\
                \\      <TR><TD ALIGN="LEFT"> {d} -- {s} </TD></TR>
            , .{ node.id, node.name });
        }

        try writer.print(
            \\
            \\      </TABLE>
            \\    >]
            \\  {s}
            \\
        , .{"}"});
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
