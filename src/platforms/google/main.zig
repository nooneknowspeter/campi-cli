const STD = @import("std");

const SCHEMA = @import("schema.zig");

pub const ClientParameters = struct {
    api_url: []const u8,
    developer_token: []const u8,
    customer_id: []const u8,
    login_customer_id: ?[]const u8,
    access_token: []const u8,
};

pub const TokenParameters = struct {
    token_url: []const u8,
    client_id: []const u8,
    client_secret: []const u8,
    refresh_token: []const u8,
};

const ACCOUNT_QUERY = "SELECT customer.id, customer.descriptive_name FROM customer";

const CAMPAIGN_QUERY =
    "SELECT campaign.id, campaign.name, campaign.status, campaign.advertising_channel_type FROM campaign ORDER BY campaign.id";

const AD_GROUP_QUERY =
    "SELECT ad_group.id, ad_group.name, ad_group.status, ad_group.campaign FROM ad_group ORDER BY ad_group.id";

const AD_QUERY =
    "SELECT ad_group_ad.ad.id, ad_group_ad.ad.name, ad_group_ad.ad.type, ad_group_ad.ad_group, ad_group_ad.status FROM ad_group_ad ORDER BY ad_group_ad.ad.id";

pub const Client = struct {
    allocator: STD.mem.Allocator,
    io: STD.Io,
    parameters: *const ClientParameters,

    pub fn init(
        allocator: STD.mem.Allocator,
        io: STD.Io,
        parameters: *const ClientParameters,
    ) Client {
        return .{
            .allocator = allocator,
            .io = io,
            .parameters = parameters,
        };
    }

    fn requestJson(self: *const Client, body: []const u8) ![]const u8 {
        const URL = try STD.fmt.allocPrint(
            self.allocator,
            "{s}/customers/{s}:search",
            .{ self.parameters.api_url, self.parameters.customer_id },
        );
        defer self.allocator.free(URL);

        var client = STD.http.Client{ .allocator = self.allocator, .io = self.io };
        defer client.deinit();

        STD.log.scoped(.google).debug("POST {s}", .{URL});

        var writer = STD.Io.Writer.Allocating.init(self.allocator);
        defer writer.deinit();

        const AUTHORIZATION = try STD.fmt.allocPrint(
            self.allocator,
            "Bearer {s}",
            .{self.parameters.access_token},
        );
        defer self.allocator.free(AUTHORIZATION);

        var headers: [2]STD.http.Header = undefined;
        headers[0] = .{
            .name = "developer-token",
            .value = self.parameters.developer_token,
        };

        var header_count: usize = 1;

        if (self.parameters.login_customer_id) |login_customer_id| {
            headers[header_count] = .{
                .name = "login-customer-id",
                .value = login_customer_id,
            };
            header_count += 1;
        }

        const RESULT = try client.fetch(.{
            .location = .{ .url = URL },
            .method = .POST,
            .payload = body,
            .headers = .{
                .authorization = .{ .override = AUTHORIZATION },
                .content_type = .{ .override = "application/json" },
            },
            .extra_headers = headers[0..header_count],
            .response_writer = &writer.writer,
        });

        STD.log.scoped(.google).debug(
            "POST {s} -> {d} {s}",
            .{
                URL,
                @intFromEnum(RESULT.status),
                RESULT.status.phrase() orelse "",
            },
        );

        if (RESULT.status.class() != .success) {
            STD.log.scoped(.google).err(
                "POST {s} failed with {d} {s}: {s}",
                .{
                    URL,
                    @intFromEnum(RESULT.status),
                    RESULT.status.phrase() orelse "",
                    writer.written(),
                },
            );

            return error.GoogleRequestFailed;
        }

        return writer.toOwnedSlice();
    }

    fn queryBody(
        self: *const Client,
        query: []const u8,
        page_token: ?[]const u8,
    ) ![]const u8 {
        if (page_token) |token|
            return STD.fmt.allocPrint(
                self.allocator,
                "{{\"query\":\"{s}\",\"pageToken\":\"{s}\"}}",
                .{ query, token },
            );

        return STD.fmt.allocPrint(
            self.allocator,
            "{{\"query\":\"{s}\"}}",
            .{query},
        );
    }

    fn search(
        self: *const Client,
        comptime T: type,
        comptime destroy: fn (STD.mem.Allocator, []T) void,
        query: []const u8,
        decode: fn (STD.mem.Allocator, []const u8) anyerror!?[]T,
    ) ![]T {
        var items: []T = &.{};
        errdefer destroy(self.allocator, items);

        var page_token: ?[]const u8 = null;
        defer if (page_token) |token| self.allocator.free(token);

        while (true) {
            const BODY = try self.queryBody(query, page_token);
            defer self.allocator.free(BODY);

            const RESPONSE = try self.requestJson(BODY);
            defer self.allocator.free(RESPONSE);

            const DECODED = try decode(self.allocator, RESPONSE);
            const PAGE = DECODED orelse break;

            const LENGTH = items.len;
            items = if (LENGTH == 0)
                try self.allocator.alloc(T, PAGE.len)
            else
                try self.allocator.realloc(items, LENGTH + PAGE.len);

            @memcpy(items[LENGTH..], PAGE);
            self.allocator.free(PAGE);

            const NEXT = try nextPageToken(self.allocator, RESPONSE);
            if (NEXT == null) break;

            if (page_token) |token| self.allocator.free(token);
            page_token = NEXT;
        }

        return items;
    }

    pub fn fetchAccount(self: *const Client) !?SCHEMA.ACCOUNT {
        const BODY = try self.queryBody(ACCOUNT_QUERY, null);
        defer self.allocator.free(BODY);

        const RESPONSE = try self.requestJson(BODY);
        defer self.allocator.free(RESPONSE);

        return SCHEMA.decodeAccount(self.allocator, RESPONSE);
    }

    pub fn fetchCampaigns(self: *const Client) ![]SCHEMA.CAMPAIGN {
        return self.search(
            SCHEMA.CAMPAIGN,
            SCHEMA.freeCampaigns,
            CAMPAIGN_QUERY,
            SCHEMA.decodeCampaigns,
        );
    }

    pub fn fetchAdGroups(self: *const Client) ![]SCHEMA.AD_GROUP {
        return self.search(
            SCHEMA.AD_GROUP,
            SCHEMA.freeAdGroups,
            AD_GROUP_QUERY,
            SCHEMA.decodeAdGroups,
        );
    }

    pub fn fetchAds(self: *const Client) ![]SCHEMA.AD {
        return self.search(
            SCHEMA.AD,
            SCHEMA.freeAds,
            AD_QUERY,
            SCHEMA.decodeAds,
        );
    }
};

pub fn fetchAccessToken(
    allocator: STD.mem.Allocator,
    io: STD.Io,
    parameters: *const TokenParameters,
) ![]const u8 {
    const CLIENT_ID = try formEncode(allocator, parameters.client_id);
    defer allocator.free(CLIENT_ID);

    const CLIENT_SECRET = try formEncode(allocator, parameters.client_secret);
    defer allocator.free(CLIENT_SECRET);

    const REFRESH_TOKEN = try formEncode(allocator, parameters.refresh_token);
    defer allocator.free(REFRESH_TOKEN);

    const BODY = try STD.fmt.allocPrint(
        allocator,
        "client_id={s}&client_secret={s}&refresh_token={s}&grant_type=refresh_token",
        .{ CLIENT_ID, CLIENT_SECRET, REFRESH_TOKEN },
    );
    defer allocator.free(BODY);

    var client = STD.http.Client{ .allocator = allocator, .io = io };
    defer client.deinit();

    var writer = STD.Io.Writer.Allocating.init(allocator);
    defer writer.deinit();

    const RESULT = try client.fetch(.{
        .location = .{ .url = parameters.token_url },
        .method = .POST,
        .payload = BODY,
        .headers = .{
            .content_type = .{ .override = "application/x-www-form-urlencoded" },
        },
        .response_writer = &writer.writer,
    });

    if (RESULT.status.class() != .success) {
        STD.log.scoped(.google).err(
            "POST {s} failed with {d} {s}: {s}",
            .{
                parameters.token_url,
                @intFromEnum(RESULT.status),
                RESULT.status.phrase() orelse "",
                writer.written(),
            },
        );

        return error.GoogleRequestFailed;
    }

    const PARSED = try STD.json.parseFromSlice(
        STD.json.Value,
        allocator,
        writer.written(),
        .{},
    );
    defer PARSED.deinit();

    const TOKEN = PARSED.value.object.get("access_token") orelse
        return error.GoogleRequestFailed;

    return allocator.dupe(u8, TOKEN.string);
}

fn nextPageToken(
    allocator: STD.mem.Allocator,
    document: []const u8,
) !?[]const u8 {
    const PARSED = try STD.json.parseFromSlice(
        STD.json.Value,
        allocator,
        document,
        .{},
    );
    defer PARSED.deinit();

    const TOKEN = PARSED.value.object.get("nextPageToken") orelse return null;

    return switch (TOKEN) {
        .string => |text| try allocator.dupe(u8, text),
        else => null,
    };
}

pub fn formEncode(
    allocator: STD.mem.Allocator,
    value: []const u8,
) ![]const u8 {
    var writer = STD.Io.Writer.Allocating.init(allocator);
    defer writer.deinit();

    try writeFormEncoded(&writer.writer, value);

    return writer.toOwnedSlice();
}

fn writeFormEncoded(writer: *STD.Io.Writer, value: []const u8) !void {
    for (value) |character| {
        if (STD.ascii.isAlphanumeric(character) or
            character == '-' or
            character == '_' or
            character == '.' or
            character == '~')
        {
            try writer.writeByte(character);
        } else {
            try writer.print("%{X:0>2}", .{character});
        }
    }
}

pub fn normalizeCustomerId(
    allocator: STD.mem.Allocator,
    customer_id: []const u8,
) ![]const u8 {
    var output = try allocator.alloc(u8, customer_id.len);

    var length: usize = 0;

    for (customer_id) |character| {
        if (character == '-') continue;

        output[length] = character;
        length += 1;
    }

    return allocator.realloc(output, length);
}
