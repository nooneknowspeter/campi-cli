const STD = @import("std");

const ARTIFACTS = @import("../../artifacts/main.zig");
const CONFIG = @import("../../config/main.zig");
const CONTEXT = @import("../../cli/context.zig");
const ENVIRONMENT = @import("../../cli/env.zig");
const MANIFEST = @import("../../manifest/main.zig");
const META_ENV = @import("env.zig");
const PAYLOAD = @import("payload.zig");
const PLAN = @import("../../plan/main.zig");

pub const SCHEMA = @import("schema.zig");

const MultipartBody = struct {
    boundary: []const u8,
    body: []const u8,
};

pub const Campaign = struct {
    name: []const u8,
    status: []const u8,
    objective: []const u8,
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

    fn requestJson(
        self: *const Client,
        method: STD.http.Method,
        path: []const u8,
        content_type: []const u8,
        body: []const u8,
    ) ![]const u8 {
        var client = STD.http.Client{ .allocator = self.allocator, .io = self.io };
        defer client.deinit();

        STD.log.scoped(.meta).debug("{s} {s}", .{ @tagName(method), path });

        const URL = try STD.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.base_url, path });
        defer self.allocator.free(URL);

        var writer = STD.Io.Writer.Allocating.init(self.allocator);
        defer writer.deinit();

        const AUTHORIZATION = try STD.fmt.allocPrint(self.allocator, "Bearer {s}", .{self.access_token});
        defer self.allocator.free(AUTHORIZATION);

        const RESULT = try client.fetch(.{
            .location = .{ .url = URL },
            .method = method,
            .payload = if (method.requestHasBody()) body else null,
            .headers = .{
                .authorization = .{ .override = AUTHORIZATION },
                .content_type = .{ .override = content_type },
            },
            .response_writer = &writer.writer,
        });

        STD.log.scoped(.meta).debug(
            "{s} {s} -> {d} {s}",
            .{
                @tagName(method),
                path,
                @intFromEnum(RESULT.status),
                RESULT.status.phrase() orelse "",
            },
        );

        if (RESULT.status.class() != .success) {
            STD.log.scoped(.meta).err(
                "{s} {s} failed with {d} {s}: {s}",
                .{
                    @tagName(method),
                    path,
                    @intFromEnum(RESULT.status),
                    RESULT.status.phrase() orelse "",
                    writer.written(),
                },
            );

            return error.MetaRequestFailed;
        }

        return writer.toOwnedSlice();
    }

    pub fn createCampaign(
        self: *const Client,
        ad_account_id: []const u8,
        payload: []const u8,
    ) ![]const u8 {
        const PATH = try STD.fmt.allocPrint(self.allocator, "/act_{s}/campaigns", .{ad_account_id});
        defer self.allocator.free(PATH);

        const RESPONSE = try self.requestJson(.POST, PATH, "application/json", payload);
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

        const RESPONSE = try self.requestJson(.POST, PATH, "application/json", payload);
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

        const RESPONSE = try self.requestJson(.POST, PATH, CONTENT_TYPE, MULTIPART.body);
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

        const RESPONSE = try self.requestJson(.POST, PATH, "application/json", payload);
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

        const RESPONSE = try self.requestJson(.POST, PATH, "application/json", payload);
        defer self.allocator.free(RESPONSE);

        return responseId(self.allocator, RESPONSE);
    }

    pub fn archiveCampaign(
        self: *const Client,
        campaign_id: []const u8,
    ) !void {
        const PATH = try STD.fmt.allocPrint(self.allocator, "/{s}", .{campaign_id});
        defer self.allocator.free(PATH);

        const RESPONSE = try self.requestJson(.POST, PATH, "application/json", "{\"status\":\"ARCHIVED\"}");
        defer self.allocator.free(RESPONSE);
    }

    pub fn fetchAccountName(
        self: *const Client,
        ad_account_id: []const u8,
    ) ![]const u8 {
        if (ad_account_id.len == 0) return error.MetaEnvironmentMissing;

        const PATH = try STD.fmt.allocPrint(self.allocator, "/act_{s}?fields=name", .{ad_account_id});
        defer self.allocator.free(PATH);

        const RESPONSE = try self.requestJson(.GET, PATH, "application/json", "");
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
        if (page_id.len == 0) return error.MetaEnvironmentMissing;

        const PATH = try STD.fmt.allocPrint(self.allocator, "/{s}?fields=name", .{page_id});
        defer self.allocator.free(PATH);

        const RESPONSE = try self.requestJson(.GET, PATH, "application/json", "");
        defer self.allocator.free(RESPONSE);

        const PARSED = try STD.json.parseFromSlice(STD.json.Value, self.allocator, RESPONSE, .{});
        defer PARSED.deinit();

        const NAME = PARSED.value.object.get("name") orelse return error.MetaRequestFailed;

        return self.allocator.dupe(u8, NAME.string);
    }

    pub fn fetchCampaigns(
        self: *const Client,
        ad_account_id: []const u8,
    ) ![]Campaign {
        const PATH = try STD.fmt.allocPrint(
            self.allocator,
            "/act_{s}/campaigns?fields=name,status,objective&limit=100",
            .{ad_account_id},
        );
        defer self.allocator.free(PATH);

        const RESPONSE = try self.requestJson(.GET, PATH, "application/json", "");
        defer self.allocator.free(RESPONSE);

        const PARSED = try STD.json.parseFromSlice(STD.json.Value, self.allocator, RESPONSE, .{});
        defer PARSED.deinit();

        const DATA = PARSED.value.object.get("data") orelse return error.MetaRequestFailed;

        var campaigns = STD.ArrayList(Campaign).empty;
        for (DATA.array.items) |entry| {
            const NAME = entry.object.get("name") orelse continue;
            const STATUS = entry.object.get("status") orelse continue;
            const OBJECTIVE = entry.object.get("objective") orelse continue;

            try campaigns.append(self.allocator, .{
                .name = try self.allocator.dupe(u8, NAME.string),
                .status = try self.allocator.dupe(u8, STATUS.string),
                .objective = try self.allocator.dupe(u8, OBJECTIVE.string),
            });
        }

        return campaigns.toOwnedSlice(self.allocator);
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

    return .{ .boundary = BOUNDARY, .body = try body.toOwnedSlice() };
}

fn hasOperations(operations: []const PLAN.SCHEMA.OPERATION) bool {
    for (operations) |operation| {
        if (STD.mem.eql(u8, operation.platform, "meta"))
            return true;
    }

    return false;
}

fn findCampaign(
    loaded_manifests: []const MANIFEST.LoadedManifest,
    operation: PLAN.SCHEMA.OPERATION,
) ?MANIFEST.SCHEMA.CAMPAIGN {
    for (loaded_manifests) |loaded_manifest| {
        if (!STD.mem.eql(u8, loaded_manifest.file_path, operation.input_manifest orelse ""))
            continue;

        for (loaded_manifest.value.campaigns) |campaign| {
            if (STD.mem.eql(u8, campaign.name, operation.campaign))
                return campaign;
        }
    }

    return null;
}

fn checkIfAnyOperationsNeedCreativeDestination(
    loaded_manifests: []const MANIFEST.LoadedManifest,
    operations: []const PLAN.SCHEMA.OPERATION,
) bool {
    for (operations) |operation| {
        if (!STD.mem.eql(u8, operation.platform, "meta")) continue;
        if (operation.operation_type == .archive) continue;

        const CAMPAIGN = findCampaign(loaded_manifests, operation) orelse continue;

        for (CAMPAIGN.ad_groups) |ad_group| {
            if (ad_group.ads.len > 0) return true;
        }
    }

    return false;
}

fn imageHashFor(
    client: *const Client,
    ad_account_id: []const u8,
    media_urls: []const []const u8,
    artifacts: []const ARTIFACTS.SCHEMA.DownloadedArtifact,
) ![]const u8 {
    const SOURCE = media_urls[0];

    for (artifacts) |artifact| {
        if (STD.mem.eql(u8, artifact.source, SOURCE))
            return client.uploadImage(ad_account_id, SOURCE, artifact.content_type, artifact.bytes);
    }

    return error.MetaCreativeMissing;
}

pub fn writeOperations(
    allocator: STD.mem.Allocator,
    context: CONTEXT.CommandContext,
    work_dir: STD.Io.Dir,
    loaded_manifests: []const MANIFEST.LoadedManifest,
    operations: []PLAN.SCHEMA.OPERATION,
) !void {
    if (!hasOperations(operations)) return;

    const OVERRIDES = try ENVIRONMENT.overridesFromConfig(
        allocator,
        if (CONFIG.current_config) |CONFIGURATION|
            CONFIGURATION.platform_configs.meta
        else
            null,
    );

    const ENVIRON = context.environ orelse return error.MetaEnvironmentMissing;

    if (ENVIRONMENT.findMissingEnvVar(ENVIRON, &META_ENV.ENV, OVERRIDES)) |missing| {
        context.stderr.print(
            \\could not find the {s} environment variable
            \\
        ,
            .{ENVIRONMENT.effectiveEnvVar(&META_ENV.ENV, missing.key, OVERRIDES)},
        ) catch {};

        return error.MetaEnvironmentMissing;
    }

    const TOKEN = ENVIRONMENT.findEnvVarValue(ENVIRON, &META_ENV.ENV, "token", OVERRIDES).?;
    const AD_ACCOUNT = ENVIRONMENT.findEnvVarValue(ENVIRON, &META_ENV.ENV, "ad_account_id", OVERRIDES).?;
    const PAGE = ENVIRONMENT.findEnvVarValue(ENVIRON, &META_ENV.ENV, "page_id", OVERRIDES);
    const INSTAGRAM_ACTOR = ENVIRONMENT.findEnvVarValue(ENVIRON, &META_ENV.ENV, "instagram_actor_id", OVERRIDES);

    if (PAGE == null and INSTAGRAM_ACTOR == null and checkIfAnyOperationsNeedCreativeDestination(loaded_manifests, operations)) {
        context.stderr.print(
            \\could not find the CAMPI_META_PAGE_ID
            \\or CAMPI_META_INSTAGRAM_ACTOR_ID environment variables;
            \\one is required to write ad creatives,
            \\
        ,
            .{},
        ) catch {};

        return error.MetaEnvironmentMissing;
    }

    const CLIENT = Client.init(
        allocator,
        context.io,
        ENVIRONMENT.findEnvVarValue(ENVIRON, &META_ENV.ENV, "graph_api_url", OVERRIDES).?,
        TOKEN,
    );

    _ = try CLIENT.fetchAccountName(AD_ACCOUNT);
    if (PAGE) |page|
        _ = try CLIENT.fetchPageName(page);
    if (INSTAGRAM_ACTOR) |instagram_actor|
        _ = try CLIENT.fetchPageName(instagram_actor);

    const SOURCES = try ARTIFACTS.collectCreativeSources(allocator, loaded_manifests);
    const LOADED_ARTIFACTS = ARTIFACTS.loadArtifacts(allocator, context, work_dir, SOURCES);

    if (LOADED_ARTIFACTS.invalid)
        return error.ArtifactCouldNotBeLoaded;

    for (operations) |*operation| {
        if (!STD.mem.eql(u8, operation.platform, "meta"))
            continue;

        switch (operation.operation_type) {
            .create, .update => {
                const CAMPAIGN = findCampaign(loaded_manifests, operation.*) orelse
                    return error.MetaCampaignNotFound;

                if (operation.operation_type == .update) {
                    if (operation.external_id) |old_id| {
                        STD.log.scoped(.meta).debug("archiving meta campaign {s}", .{old_id});
                        try CLIENT.archiveCampaign(old_id);
                    }
                }

                const NEW_ID = try CLIENT.createCampaign(
                    AD_ACCOUNT,
                    try PAYLOAD.campaignPayload(allocator, CAMPAIGN),
                );

                STD.log.scoped(.meta).debug("created meta campaign {s}", .{NEW_ID});

                for (CAMPAIGN.ad_groups) |ad_group| {
                    const AD_SET_ID = try CLIENT.createAdSet(
                        AD_ACCOUNT,
                        try PAYLOAD.adSetPayload(allocator, ad_group, NEW_ID),
                    );

                    for (ad_group.ads) |ad| {
                        const IMAGE_HASH = try imageHashFor(
                            &CLIENT,
                            AD_ACCOUNT,
                            ad.CREATIVE.media_urls,
                            LOADED_ARTIFACTS.artifacts,
                        );

                        var destination = PAYLOAD.CREATIVE_DESTINATION{};
                        if (PAGE) |page|
                            destination.page_id = page;
                        if (INSTAGRAM_ACTOR) |instagram_actor|
                            destination.instagram_actor_id = instagram_actor;

                        const CREATIVE_ID = try CLIENT.createAdCreative(
                            AD_ACCOUNT,
                            try PAYLOAD.creativePayload(allocator, destination, ad, IMAGE_HASH),
                        );

                        _ = try CLIENT.createAd(
                            AD_ACCOUNT,
                            try PAYLOAD.adPayload(allocator, ad, AD_SET_ID, CREATIVE_ID),
                        );
                    }
                }

                operation.external_id = NEW_ID;
            },
            .archive => {
                if (operation.external_id) |old_id| {
                    STD.log.scoped(.meta).debug("archiving meta campaign {s}", .{old_id});
                    try CLIENT.archiveCampaign(old_id);
                }
            },
        }
    }
}
