//! This file implements a dunstblick protocol display client.
//! It does not depend on any network interface, but has a pure push/pull API
//! that allows using it in any freestanding environment.
//!
//! Design considerations:
//! Dunstblick application servers can be embedded types, thus this state machine is implemented
//! with tight memory requirement in mind. It tries not to create unnecessary copies or allocate memory.

const std = @import("std");
const zig_charm = @import("charm");
const shared_types = @import("shared_types.zig");
const types = @import("../data-types.zig");
const protocol = @import("v1.zig");

const CryptoState = @import("CryptoState.zig");

pub const ReceiveData = struct {
    consumed: usize,
    event: ?ReceiveEvent,

    fn notEnough(len: usize) @This() {
        return .{
            .consumed = len,
            .event = null,
        };
    }

    fn createEvent(consumed: usize, event: ReceiveEvent) @This() {
        return @This(){
            .consumed = consumed,
            .event = event,
        };
    }
};

pub const ReceiveEvent = union(enum) {
    initiate_handshake: InitiateHandshake,
    authenticate_info: AuthenticateInfo,
    connect_header: ConnectHeader,
    resource_request: ResourceRequest,
    message: []const u8,

    const InitiateHandshake = struct {
        has_username: bool,
        has_password: bool,
    };
    const AuthenticateInfo = struct {
        //
    };
    const ConnectHeader = struct {
        capabilities: protocol.ClientCapabilities,
        screen_width: u16,
        screen_height: u16,
    };
    const ResourceRequest = struct {
        requested_resources: []const types.ResourceID,
    };
};

pub const AuthAction = enum {
    /// The server waits for authentication informationen.
    /// Provide more data from the client.
    expect_auth_info,

    /// The server does not expend authentication information,
    /// just invoke `sendAuthenticationResult()`
    send_auth_result,

    /// Drop the connection, the authentication would fail anyways (server does not expect what client sends)
    drop,
};

pub const ReceiveError = error{
    OutOfMemory,
    UnexpectedData,
    UnsupportedVersion,
    ProtocolViolation,
};

pub fn ServerStateMachine(comptime Writer: type) type {
    return struct {
        const Self = @This();

        pub const SendError = Writer.Error || error{
            /// A necessary allocation couldn't be performed.
            OutOfMemory,
            /// A slice contained too many elements
            SliceOutOfRange,
        };

        allocator: *std.mem.Allocator,
        writer: Writer,

        /// The cryptographic provider for the connection.
        crypto: CryptoState,

        /// When this is `true`, the packages will be encrypted/decrypted with `charm`.
        crpyto_enabled: bool = false,

        receive_buffer: shared_types.MsgReceiveBuffer = .{},
        temp_msg_buffer: std.ArrayListUnmanaged(u8) = .{},

        state: shared_types.State = .initiate_handshake,

        /// Number of resources that are available on the server
        available_resource_count: u32 = undefined,

        /// Number of resources that are requested by the client.
        requested_resource_count: u32 = undefined,

        expects_password: bool = false,
        expects_username: bool = false,

        will_receive_username: bool = false,
        will_receive_password: bool = false,

        pub fn init(allocator: *std.mem.Allocator, writer: Writer) Self {
            return Self{
                .allocator = allocator,
                .writer = writer,
                .crypto = CryptoState.init(),
            };
        }

        pub fn deinit(self: *Self) void {
            self.receive_buffer.deinit(self.allocator);
            self.temp_msg_buffer.deinit(self.allocator);
            self.* = undefined;
        }

        pub fn isFaulted(self: Self) bool {
            return (self.state == .faulted);
        }

        pub fn pushData(self: *Self, new_data: []const u8) ReceiveError!ReceiveData {
            switch (self.state) {
                .initiate_handshake => {
                    switch (try self.receive_buffer.pushData(self.allocator, new_data, @sizeOf(protocol.InitiateHandshake))) {
                        .need_more => return ReceiveData.notEnough(new_data.len),
                        .ok => |info| {
                            const value = info.get(protocol.InitiateHandshake);

                            if (!std.mem.eql(u8, &value.magic, &protocol.magic))
                                return error.UnexpectedData;
                            if (value.protocol_version != protocol.protocol_version)
                                return error.UnsupportedVersion;

                            self.crypto.client_nonce = value.client_nonce;
                            self.will_receive_username = value.flags.has_username;
                            self.will_receive_password = value.flags.has_password;

                            self.state = .acknowledge_handshake;
                            return ReceiveData.createEvent(
                                info.consumed,
                                ReceiveEvent{
                                    .initiate_handshake = .{
                                        .has_username = value.flags.has_username,
                                        .has_password = value.flags.has_password,
                                    },
                                },
                            );
                        },
                    }
                },
                .acknowledge_handshake => return error.UnexpectedData,
                .authenticate_info => @panic("not implemented yet"),
                .authenticate_result => return error.UnexpectedData,
                .connect_header => {
                    switch (try self.receive_buffer.pushData(self.allocator, new_data, @sizeOf(protocol.ConnectHeader))) {
                        .need_more => return ReceiveData.notEnough(new_data.len),
                        .ok => |info| {
                            const value = info.get(protocol.ConnectHeader);

                            self.state = .connect_response;

                            return ReceiveData.createEvent(
                                info.consumed,
                                ReceiveEvent{
                                    .connect_header = .{
                                        .capabilities = value.capabilities,
                                        .screen_width = value.screen_width,
                                        .screen_height = value.screen_height,
                                    },
                                },
                            );
                        },
                    }
                },
                .connect_response => return error.UnexpectedData,
                .connect_response_item => return error.UnexpectedData,
                .resource_request => {
                    switch (try self.receive_buffer.pushPrefix(self.allocator, new_data, 4)) {
                        .need_more => return ReceiveData.notEnough(new_data.len),
                        .ok => |prefix_info| {
                            // prefix_info.consumed
                            const len = std.mem.readIntLittle(u32, prefix_info.data[0..4]);

                            const total_len = @sizeOf(u32) + @sizeOf(types.ResourceID) * len;

                            switch (try self.receive_buffer.pushData(self.allocator, new_data[prefix_info.consumed..], total_len)) {
                                .need_more => return ReceiveData.notEnough(new_data.len - prefix_info.consumed),
                                .ok => |info| {
                                    const resources = @alignCast(4, std.mem.bytesAsSlice(types.ResourceID, info.data[4..]));
                                    std.debug.assert(resources.len == len);

                                    self.requested_resource_count = len;
                                    self.state = .{ .resource_header = 0 };

                                    return ReceiveData.createEvent(
                                        prefix_info.consumed + info.consumed,
                                        ReceiveEvent{
                                            .resource_request = .{
                                                .requested_resources = resources,
                                            },
                                        },
                                    );
                                },
                            }
                        },
                    }
                },
                .resource_header => return error.UnexpectedData,
                .established => {
                    switch (try self.receive_buffer.pushPrefix(self.allocator, new_data, 4)) {
                        .need_more => return ReceiveData.notEnough(new_data.len),
                        .ok => |prefix_info| {
                            // prefix_info.consumed
                            const len = std.mem.readIntLittle(u32, prefix_info.data[0..4]);

                            const total_len = @sizeOf(u32) + len;

                            switch (try self.receive_buffer.pushData(self.allocator, new_data[prefix_info.consumed..], total_len)) {
                                .need_more => return ReceiveData.notEnough(new_data.len - prefix_info.consumed),
                                .ok => |info| {
                                    return ReceiveData.createEvent(
                                        prefix_info.consumed + info.consumed,
                                        ReceiveEvent{ .message = info.data[4..] },
                                    );
                                },
                            }
                        },
                    }
                },
                .faulted => return error.UnexpectedData,
            }
        }

        /// Writes raw data to the stream.
        fn sendRaw(self: *Self, data: []const u8) SendError!void {
            try self.writer.writeAll(data);
        }

        /// Writes a blob of data to the stream and encrypts it if required.
        /// This will also send the necessary tag.
        fn send(self: *Self, data: []u8) SendError!void {
            if (self.crypto.encryption_enabled) {
                const tag = self.crypto.encrypt(data);
                try self.sendRaw(data);
                try self.sendRaw(&tag);
            } else {
                try self.sendRaw(data);
            }
        }

        pub fn acknowledgeHandshake(self: *Self, response: protocol.AcknowledgeHandshake.Response) SendError!AuthAction {
            std.debug.assert(self.state == .acknowledge_handshake);

            // "reject" is only allowed when a name/password will actually be sent
            std.debug.assert(!response.rejects_username or self.will_receive_username);
            std.debug.assert(!response.rejects_password or self.will_receive_password);

            // "require" must only be set when no name/password was sent
            std.debug.assert(!response.requires_username or self.will_receive_username);
            std.debug.assert(!response.requires_password or self.will_receive_password);

            var bits = protocol.AcknowledgeHandshake{
                .response = response,
                .server_nonce = self.crypto.server_nonce,
            };

            try self.send(std.mem.asBytes(&bits));

            if (response.rejects_username or
                response.rejects_password or
                response.requires_username or
                response.requires_password)
            {
                self.state = .faulted;
                return .drop;
            } else {
                if (self.will_receive_username or self.will_receive_password) {
                    self.state = .authenticate_info;
                    return .expect_auth_info;
                } else {
                    self.state = .authenticate_result;
                    return .send_auth_result;
                }
            }
        }

        pub fn sendAuthenticationResult(self: *Self, result: protocol.AuthenticationResult.Result, encrypt_transport: bool) SendError!void {
            std.debug.assert(self.state == .authenticate_result);

            // Encryption is only allowed when a password was provided
            std.debug.assert(!encrypt_transport or self.will_receive_password);

            var bits = protocol.AuthenticationResult{
                .result = result,
                .flags = .{
                    .encrypted = encrypt_transport,
                },
            };

            try self.send(std.mem.asBytes(&bits));

            // After this, crypto handshake is done, we can now successfully
            // encrypt our messages if wanted
            self.crypto.encryption_enabled = encrypt_transport;

            self.state = .connect_header;
        }

        pub fn sendConnectResponse(self: *Self, resources: []const protocol.ConnectResponseItem) SendError!void {
            std.debug.assert(self.state == .connect_response);

            var bits = protocol.ConnectResponse{
                .resource_count = std.math.cast(u32, resources.len) catch return error.SliceOutOfRange,
            };

            try self.send(std.mem.asBytes(&bits));

            for (resources) |descriptor| {
                var clone = descriptor;
                try self.send(std.mem.asBytes(&clone));
            }

            self.available_resource_count = bits.resource_count;
            if (self.available_resource_count == 0) {
                self.state = .established;
            } else {
                self.state = .resource_request;
            }
        }

        pub fn sendResourceHeader(self: *Self, id: types.ResourceID, data: []const u8) SendError!void {
            std.debug.assert(self.state == .resource_header);
            std.debug.assert(self.state.resource_header < self.available_resource_count);

            var length_data: [4]u8 = undefined;
            std.mem.writeIntLittle(u32, &length_data, std.math.cast(u32, data.len) catch return error.SliceOutOfRange);

            var bits = protocol.ResourceHeader{
                .id = id,
            };

            const header_len = @sizeOf(protocol.ResourceHeader);

            self.temp_msg_buffer.shrinkRetainingCapacity(0);
            try self.temp_msg_buffer.resize(self.allocator, header_len + data.len);

            std.mem.copy(u8, self.temp_msg_buffer.items, std.mem.asBytes(&bits));
            std.mem.copy(u8, self.temp_msg_buffer.items[header_len..], data);

            try self.sendRaw(&length_data); // must be unencrypted data!
            try self.send(self.temp_msg_buffer.items);

            self.state.resource_header += 1;
            if (self.state.resource_header == self.requested_resource_count) {
                self.state = .established;
            }
        }

        pub fn sendMessage(self: *Self, message: []const u8) SendError!void {
            std.debug.assert(self.state == .established);

            var length_data: [4]u8 = undefined;
            std.mem.writeIntLittle(u32, &length_data, std.math.cast(u32, message.len) catch return error.SliceOutOfRange);

            try self.temp_msg_buffer.resize(self.allocator, message.len);
            std.mem.copy(u8, self.temp_msg_buffer.items, message);

            try self.sendRaw(&length_data); // must be unencrypted data!
            try self.send(self.temp_msg_buffer.items);
        }
    };
}
