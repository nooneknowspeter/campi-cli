const STD = @import("std");

pub const SCHEMA = @import("schema.zig");

pub const ACCESS_TOKEN_ENV = "CAMPI_META_TOKEN";
pub const AD_ACCOUNT_ENV = "CAMPI_META_AD_ACCOUNT";
pub const PAGE_ID_ENV = "CAMPI_META_PAGE_ID";
pub const GRAPH_API_URL_ENV = "CAMPI_META_GRAPH_API_URL";

pub const DEFAULT_GRAPH_API_URL = "https://graph.facebook.com";

pub fn hasAccessToken(environ: STD.process.Environ) bool {
    return STD.process.Environ.containsUnemptyConstant(environ, ACCESS_TOKEN_ENV);
}

pub fn hasAdAccount(environ: STD.process.Environ) bool {
    return STD.process.Environ.containsUnemptyConstant(environ, AD_ACCOUNT_ENV);
}

pub fn hasPageId(environ: STD.process.Environ) bool {
    return STD.process.Environ.containsUnemptyConstant(environ, PAGE_ID_ENV);
}

pub fn accessToken(environ: STD.process.Environ) ?[]const u8 {
    return STD.process.Environ.getPosix(environ, ACCESS_TOKEN_ENV);
}

pub fn adAccountId(environ: STD.process.Environ) ?[]const u8 {
    return STD.process.Environ.getPosix(environ, AD_ACCOUNT_ENV);
}

pub fn pageId(environ: STD.process.Environ) ?[]const u8 {
    return STD.process.Environ.getPosix(environ, PAGE_ID_ENV);
}

pub fn graphApiUrl(environ: STD.process.Environ) []const u8 {
    return STD.process.Environ.getPosix(environ, GRAPH_API_URL_ENV) orelse DEFAULT_GRAPH_API_URL;
}

const MultipartBody = struct {
    boundary: []const u8,
    body: []const u8,
};

pub const Client = struct {
    allocator: STD.mem.Allocator,
    io: STD.Io,
    base_url: []const u8,
    access_token: []const u8,

    pub fn init(
        allocator: STD.mem.Allocator,
        io: STD.Io,
        base_url: []const u8,
        access_token: []const u8,
    ) Client {
        return .{
            .allocator = allocator,
            .io = io,
            .base_url = base_url,
            .access_token = access_token,
        };
    }

    fn postJson(
        self: *const Client,
        path: []const u8,
        content_type: []const u8,
        body: []const u8,
    ) ![]const u8 {
        var client = STD.http.Client{ .allocator = self.allocator, .io = self.io };
        defer client.deinit();

        STD.log.scoped(.meta).debug("POST {s}", .{path});

        const URL = try STD.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.base_url, path });
        defer self.allocator.free(URL);

        var writer = STD.Io.Writer.Allocating.init(self.allocator);
        defer writer.deinit();

        const AUTHORIZATION = try STD.fmt.allocPrint(self.allocator, "Bearer {s}", .{self.access_token});
        defer self.allocator.free(AUTHORIZATION);

        const RESULT = try client.fetch(.{
            .location = .{ .url = URL },
            .method = .POST,
            .payload = body,
            .headers = .{
                .authorization = .{ .override = AUTHORIZATION },
                .content_type = .{ .override = content_type },
            },
            .response_writer = &writer.writer,
        });

        STD.log.scoped(.meta).debug(
            "POST {s} -> {d} {s}",
            .{ path, @intFromEnum(RESULT.status), RESULT.status.phrase() orelse "" },
        );

        if (RESULT.status.class() != .success)
            return error.MetaRequestFailed;

        return writer.toOwnedSlice();
    }

    pub fn createCampaign(
        self: *const Client,
        ad_account_id: []const u8,
        payload: []const u8,
    ) ![]const u8 {
        const PATH = try STD.fmt.allocPrint(self.allocator, "/act_{s}/campaigns", .{ad_account_id});
        defer self.allocator.free(PATH);

        const RESPONSE = try self.postJson(PATH, "application/json", payload);
        defer self.allocator.free(RESPONSE);

        return responseId(self.allocator, RESPONSE);
    }

    pub fn createAdSet(
        self: *const Client,
        ad_account_id: []const u8,
        payload: []const u8,
    ) ![]const u8 {
        const PATH = try STD.fmt.allocPrint(self.allocator, "/act_{s}/adsets", .{ad_account_id});
        defer self.allocator.free(PATH);

        const RESPONSE = try self.postJson(PATH, "application/json", payload);
        defer self.allocator.free(RESPONSE);

        return responseId(self.allocator, RESPONSE);
    }

    pub fn uploadImage(
        self: *const Client,
        ad_account_id: []const u8,
        filename: []const u8,
        content_type: []const u8,
        bytes: []const u8,
    ) ![]const u8 {
        const PATH = try STD.fmt.allocPrint(self.allocator, "/act_{s}/adimages", .{ad_account_id});
        defer self.allocator.free(PATH);

        const MULTIPART = try multipartBody(self.allocator, filename, content_type, bytes);
        defer {
            self.allocator.free(MULTIPART.boundary);
            self.allocator.free(MULTIPART.body);
        }

        const CONTENT_TYPE = try STD.fmt.allocPrint(
            self.allocator,
            "multipart/form-data; boundary={s}",
            .{MULTIPART.boundary},
        );
        defer self.allocator.free(CONTENT_TYPE);

        const RESPONSE = try self.postJson(PATH, CONTENT_TYPE, MULTIPART.body);
        defer self.allocator.free(RESPONSE);

        const PARSED = try STD.json.parseFromSlice(STD.json.Value, self.allocator, RESPONSE, .{});
        defer PARSED.deinit();

        const IMAGES = PARSED.value.object.get("images") orelse return error.MetaRequestFailed;

        var image_entries = IMAGES.object.iterator();
        const ENTRY = image_entries.next() orelse return error.MetaRequestFailed;
        const HASH = ENTRY.value_ptr.object.get("hash") orelse return error.MetaRequestFailed;

        return self.allocator.dupe(u8, HASH.string);
    }

    pub fn createAdCreative(
        self: *const Client,
        ad_account_id: []const u8,
        payload: []const u8,
    ) ![]const u8 {
        const PATH = try STD.fmt.allocPrint(self.allocator, "/act_{s}/adcreatives", .{ad_account_id});
        defer self.allocator.free(PATH);

        const RESPONSE = try self.postJson(PATH, "application/json", payload);
        defer self.allocator.free(RESPONSE);

        return responseId(self.allocator, RESPONSE);
    }

    pub fn createAd(
        self: *const Client,
        ad_account_id: []const u8,
        payload: []const u8,
    ) ![]const u8 {
        const PATH = try STD.fmt.allocPrint(self.allocator, "/act_{s}/ads", .{ad_account_id});
        defer self.allocator.free(PATH);

        const RESPONSE = try self.postJson(PATH, "application/json", payload);
        defer self.allocator.free(RESPONSE);

        return responseId(self.allocator, RESPONSE);
    }

    pub fn archiveCampaign(
        self: *const Client,
        campaign_id: []const u8,
    ) !void {
        const PATH = try STD.fmt.allocPrint(self.allocator, "/{s}", .{campaign_id});
        defer self.allocator.free(PATH);

        const RESPONSE = try self.postJson(PATH, "application/json", "{\"status\":\"ARCHIVED\"}");
        defer self.allocator.free(RESPONSE);
    }

    pub fn fetchAccountName(
        self: *const Client,
        ad_account_id: []const u8,
    ) ![]const u8 {
        const PATH = try STD.fmt.allocPrint(self.allocator, "/act_{s}?fields=name", .{ad_account_id});
        defer self.allocator.free(PATH);

        const RESPONSE = try self.postJson(PATH, "application/json", "");
        defer self.allocator.free(RESPONSE);

        const PARSED = try STD.json.parseFromSlice(STD.json.Value, self.allocator, RESPONSE, .{});
        defer PARSED.deinit();

        const NAME = PARSED.value.object.get("name") orelse return error.MetaRequestFailed;

        return self.allocator.dupe(u8, NAME.string);
    }

    pub fn fetchPageName(
        self: *const Client,
        page_id: []const u8,
    ) ![]const u8 {
        const PATH = try STD.fmt.allocPrint(self.allocator, "/{s}?fields=name", .{page_id});
        defer self.allocator.free(PATH);

        const RESPONSE = try self.postJson(PATH, "application/json", "");
        defer self.allocator.free(RESPONSE);

        const PARSED = try STD.json.parseFromSlice(STD.json.Value, self.allocator, RESPONSE, .{});
        defer PARSED.deinit();

        const NAME = PARSED.value.object.get("name") orelse return error.MetaRequestFailed;

        return self.allocator.dupe(u8, NAME.string);
    }
};

fn responseId(allocator: STD.mem.Allocator, response: []const u8) ![]const u8 {
    const PARSED = try STD.json.parseFromSlice(STD.json.Value, allocator, response, .{});
    defer PARSED.deinit();

    const ID = PARSED.value.object.get("id") orelse return error.MetaRequestFailed;

    return allocator.dupe(u8, ID.string);
}

fn multipartBody(
    allocator: STD.mem.Allocator,
    filename: []const u8,
    content_type: []const u8,
    bytes: []const u8,
) !MultipartBody {
    var hasher = STD.hash.Wyhash.init(0);
    hasher.update(filename);
    hasher.update(bytes);

    const SUM = hasher.final();

    const BOUNDARY = try STD.fmt.allocPrint(allocator, "campi{x}", .{SUM});

    var body = STD.Io.Writer.Allocating.init(allocator);
    defer body.deinit();

    try body.writer.print(
        \\--{s}\r\nContent-Disposition: form-data; name="filename"\r\n\r\n{s}\r\n
        \\--{s}\r\nContent-Disposition: form-data; name="bytes"; filename="{s}"\r\nContent-Type: {s}\r\n\r\n
    , .{ BOUNDARY, filename, BOUNDARY, filename, content_type });
    try body.writer.writeAll(bytes);
    try body.writer.print("\r\n--{s}--\r\n", .{BOUNDARY});

    return .{ .boundary = BOUNDARY, .body = body.toOwnedSlice() };
}
