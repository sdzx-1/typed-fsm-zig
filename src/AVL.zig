//The AVL tree implemented using array allows up to 100,000 states.
//https://www.geeksforgeeks.org/c/c-program-to-implement-avl-tree/
//
idx: i32 = 0,
nodes: [100_000]Node = undefined,

pub const Node = struct {
    key: u32,
    data: u32,
    left: i32,
    right: i32,
    height: i32,
};
const Self = @This();

pub fn search(self: *Self, root: i32, key: u32) ?u32 {
    if (root == -1) return null;
    const node = self.access(root);
    if (key == node.key) return node.data;
    if (key < node.key) return self.search(node.left, key);
    if (key > node.key) return self.search(node.right, key);
    return null;
}
pub fn insert(self: *Self, node: i32, key: u32, data: u32) i32 {
    // // Function to insert a key into AVL tree
    // struct Node* insert(struct Node* node, int key)
    // {
    //     // 1. Perform standard BST insertion
    //     if (node == NULL)
    //         return createNode(key);
    if (node == -1) return self.createNode(key, data);

    //     if (key < node->key)
    //     else if (key > node->key)
    //     else // Equal keys are not allowed in BST

    if (key < self.access(node).key) {
        //         node->left = insert(node->left, key);
        self.access(node).left = self.insert(self.access(node).left, key, data);
    } else if (key > self.access(node).key) {
        //         node->right = insert(node->right, key);
        self.access(node).right = self.insert(self.access(node).right, key, data);
    } else {
        //         return node;
        return node;
    }

    //     // 2. Update height of this ancestor node
    //     node->height = 1
    //                    + max(getHeight(node->left),
    //                          getHeight(node->right));

    self.access(node).height = @as(i32, 1) + @max(
        self.getHeight(self.access(node).left),
        self.getHeight(self.access(node).right),
    );

    //     // 3. Get the balance factor of this ancestor node to
    //     // check whether this node became unbalanced
    //     int balance = getBalanceFactor(node);
    const balance = self.getBalanceFactor(node);

    //     // 4. If the node becomes unbalanced, then there are 4
    //     // cases

    //     // Left Left Case
    //     if (balance > 1 && key < node->left->key)
    //         return rightRotate(node);

    if (balance > 1 and key < self.access(self.access(node).left).key) {
        return self.rightRotate(node);
    }

    //     // Right Right Case
    //     if (balance < -1 && key > node->right->key)
    //         return leftRotate(node);

    if (balance < -1 and key > self.access(self.access(node).right).key) {
        return self.leftRotate(node);
    }

    //     // Left Right Case
    //     if (balance > 1 && key > node->left->key) {
    //         node->left = leftRotate(node->left);
    //         return rightRotate(node);
    //     }

    if (balance > 1 and key > self.access(self.access(node).left).key) {
        self.access(node).left = self.leftRotate(self.access(node).left);
        return self.rightRotate(node);
    }

    //     // Right Left Case
    //     if (balance < -1 && key < node->right->key) {
    //         node->right = rightRotate(node->right);
    //         return leftRotate(node);
    //     }

    if (balance < -1 and key < self.access(self.access(node).right).key) {
        self.access(node).right = self.rightRotate(self.access(node).right);
        return self.leftRotate(node);
    }

    //     // Return the (unchanged) node pointer
    //     return node;
    return node;
}

fn access(self: *Self, i: i32) *Node {
    return &self.nodes[@as(usize, @intCast(i))];
}

// // Function to get height of the node
// int getHeight(struct Node* n)
// {
//     if (n == NULL)
//         return 0;
//     return n->height;
// }

fn getHeight(self: *Self, n: i32) i32 {
    if (n == -1) {
        return 0;
    } else {
        return self.access(n).height;
    }
}

// // Function to create a new node
// struct Node* createNode(int key)
// {
//     struct Node* node
//         = (struct Node*)malloc(sizeof(struct Node));
//     node->key = key;
//     node->left = NULL;
//     node->right = NULL;
//     node->height = 1; // New node is initially added at leaf
//     return node;
// }

fn createNode(self: *Self, key: u32, data: u32) i32 {
    const curr = self.idx;
    self.idx += 1;
    self.access(curr).* = .{
        .key = key,
        .data = data,
        .left = -1,
        .right = -1,
        .height = 1,
    };
    return curr;
}

// // Utility function to get the maximum of two integers
// int max(int a, int b) { return (a > b) ? a : b; }

// // Function to get balance factor of a node
// int getBalanceFactor(struct Node* n)
// {
//     if (n == NULL)
//         return 0;
//     return getHeight(n->left) - getHeight(n->right);
// }

fn getBalanceFactor(self: *Self, n: i32) i32 {
    if (n == -1) return 0;
    return self.getHeight(self.access(n).left) - self.getHeight(self.access(n).right);
}

fn rightRotate(self: *Self, y: i32) i32 {
    // // Right rotation function
    // struct Node* rightRotate(struct Node* y)
    // {
    //     struct Node* x = y->left;
    const x = self.access(y).left;
    //     struct Node* T2 = x->right;
    const T2 = self.access(x).right;

    //     // Perform rotation
    //     x->right = y;
    //     y->left = T2;
    self.access(x).right = y;
    self.access(y).left = T2;

    //     // Update heights
    //     y->height
    //         = max(getHeight(y->left), getHeight(y->right)) + 1;
    self.access(y).height = @max(
        self.getHeight(self.access(y).left),
        self.getHeight(self.access(y).right),
    ) + @as(i32, 1);

    //     x->height
    //         = max(getHeight(x->left), getHeight(x->right)) + 1;

    self.access(x).height = @max(
        self.getHeight(self.access(x).left),
        self.getHeight(self.access(x).right),
    ) + @as(i32, 1);

    //     return x;
    return x;
}

fn leftRotate(self: *Self, x: i32) i32 {
    // // Left rotation function
    // struct Node* leftRotate(struct Node* x)
    // {
    //     struct Node* y = x->right;
    const y = self.access(x).right;
    //     struct Node* T2 = y->left;
    const T2 = self.access(y).left;

    //     // Perform rotation
    //     y->left = x;
    self.access(y).left = x;
    //     x->right = T2;
    self.access(x).right = T2;

    //     // Update heights
    //     x->height
    //         = max(getHeight(x->left), getHeight(x->right)) + 1;

    self.access(x).height = @max(
        self.getHeight(self.access(x).left),
        self.getHeight(self.access(x).right),
    ) + @as(i32, 1);
    //     y->height
    //         = max(getHeight(y->left), getHeight(y->right)) + 1;

    self.access(y).height = @max(
        self.getHeight(self.access(y).left),
        self.getHeight(self.access(y).right),
    ) + @as(i32, 1);

    //     return y;
    return y;
}

// // Function to perform preorder traversal of AVL tree
// void inOrder(struct Node* root)
// {
//     if (root != NULL) {
//         inOrder(root->left);
//         printf("%d ", root->key);
//         inOrder(root->right);
//     }
// }

fn inOrder(self: *Self, root: i32) void {
    if (root != -1) {
        self.inOrder(self.access(root).left);
        std.debug.print("{d} ", .{self.access(root).key});
        self.inOrder(self.access(root).right);
    }
}

test "avl" {
    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();

    const len_arr: []const usize = &.{ 0, 1, 2, 3, 4, 6, 8, 10, 200, 450, 780, 1000, 4000, 8000, 10000, 30000 };

    inline for (len_arr) |len| {
        var tmp_arr: [len]struct { u32, u32 } = undefined;
        for (0..len) |i| {
            tmp_arr[i] = .{ @as(u32, @intCast(i)), @as(u32, @intCast(i)) };
        }

        for (0..len) |_| {
            const id_a: usize = @intCast(rand.intRangeAtMost(u32, 0, len - 1));
            const id_b: usize = @intCast(rand.intRangeAtMost(u32, 0, len - 1));
            const tmp = tmp_arr[id_a];
            tmp_arr[id_a] = tmp_arr[id_b];
            tmp_arr[id_b] = tmp;
        }

        var root: i32 = -1;
        var avl: @This() = .{};

        for (0..len) |i| {
            const tmp = tmp_arr[i];
            root = avl.insert(root, tmp.@"0", tmp.@"1");
        }

        for (0..len) |i| {
            const key: u32 = @intCast(i);
            std.debug.assert(key == avl.search(root, key));
        }
    }
}

const std = @import("std");
