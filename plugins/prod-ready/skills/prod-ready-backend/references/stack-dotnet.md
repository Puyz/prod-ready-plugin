# ASP.NET Core (8+) implementation notes

The reference `Program.cs` below uses minimal APIs and **compiles on net8.0 and net10.0 with 0 errors and 0 warnings**. Its only NuGet dependency is `Microsoft.EntityFrameworkCore.SqlServer`. If you use controllers, see "Controller notes" at the end.

IDs in headings refer to the items in `SKILL.md`.

## Reference Program.cs

Covers: B01, B02, B04, B06, B07, B10, B11, B12, B15, B21, B22, B24, B25, B26, B29.

```csharp
using System.Net;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);
var cfg = builder.Configuration;
var origins = cfg.GetSection("Cors:Origins").Get<string[]>() ?? [];

builder.WebHost.ConfigureKestrel(o =>
{
    o.AddServerHeader = false;
    o.Limits.MaxRequestBodySize = 1_000_000; // B26
});
builder.Services.AddDbContext<AppDb>(o => o.UseSqlServer(cfg.GetConnectionString("Db")));
builder.Services.AddProblemDetails();

// B01: Identity's PBKDF2-SHA512 hasher at the OWASP iteration count (full Identity not required)
builder.Services.Configure<PasswordHasherOptions>(o => o.IterationCount = 210_000);
builder.Services.AddSingleton<IPasswordHasher<User>, PasswordHasher<User>>();

// B02/B04/B25: the cookie carries only a session id; the DB session row decides validity
builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(o =>
    {
        o.Cookie.Name = "__Host-session";
        o.Cookie.HttpOnly = true;
        o.Cookie.SecurePolicy = CookieSecurePolicy.Always;
        o.Cookie.SameSite = SameSiteMode.Lax; // SPA and API must be same-site (eTLD+1)
        o.ExpireTimeSpan = TimeSpan.FromMinutes(30);
        o.SlidingExpiration = true;
        o.Events.OnRedirectToLogin = ctx => { ctx.Response.StatusCode = 401; return Task.CompletedTask; };
        o.Events.OnRedirectToAccessDenied = ctx => { ctx.Response.StatusCode = 403; return Task.CompletedTask; };
        o.Events.OnValidatePrincipal = async ctx =>
        {
            // shortcut: one DB query per request; add a short-lived cache if it shows up in profiles
            var sid = ctx.Principal?.FindFirstValue("sid");
            var db = ctx.HttpContext.RequestServices.GetRequiredService<AppDb>();
            var alive = sid is not null && await db.Sessions.AnyAsync(s => s.Id == sid && s.ExpiresAt > DateTime.UtcNow);
            if (!alive)
            {
                ctx.RejectPrincipal();
                await ctx.HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
            }
        };
    });

// B10: deny by default; public endpoints opt out with AllowAnonymous()
builder.Services.AddAuthorizationBuilder()
    .SetFallbackPolicy(new AuthorizationPolicyBuilder().RequireAuthenticatedUser().Build());

builder.Services.AddCors(o => o.AddPolicy("web", p => p
    .WithOrigins(origins).AllowCredentials()
    .WithHeaders("Content-Type", "X-CSRF").WithMethods("GET", "POST", "PUT", "DELETE")));

// B06/B26: partitioned per IP. WARNING: AddFixedWindowLimiter("login", ...) is ONE bucket shared by ALL clients.
builder.Services.AddRateLimiter(o =>
{
    o.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    o.OnRejected = (ctx, _) =>
    {
        if (ctx.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retry))
            ctx.HttpContext.Response.Headers.RetryAfter = ((int)retry.TotalSeconds).ToString();
        return ValueTask.CompletedTask;
    };
    o.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(ctx =>
        RateLimitPartition.GetFixedWindowLimiter(Ip(ctx),
            _ => new FixedWindowRateLimiterOptions { PermitLimit = 100, Window = TimeSpan.FromMinutes(1) }));
    o.AddPolicy("login", ctx => RateLimitPartition.GetFixedWindowLimiter(Ip(ctx),
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 10, Window = TimeSpan.FromMinutes(1) }));
});

// B26: accept X-Forwarded-* only from the known proxy
builder.Services.Configure<ForwardedHeadersOptions>(o =>
{
    o.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    o.KnownProxies.Add(IPAddress.Parse(cfg["Proxy:Ip"] ?? throw new InvalidOperationException("Proxy:Ip missing")));
});

var app = builder.Build();
var dummyHash = app.Services.GetRequiredService<IPasswordHasher<User>>().HashPassword(new User(), "timing-equalizer");

app.UseForwardedHeaders();           // FIRST middleware, so everything below sees the real IP/scheme
app.UseExceptionHandler();           // B29: ProblemDetails + traceId, no stack trace
app.UseStatusCodePages();
if (!app.Environment.IsDevelopment()) app.UseHsts();
// B23: no UseHttpsRedirection for an API; the client has already sent the cookie over HTTP. Don't listen on HTTP.
app.Use(async (ctx, next) =>         // B24
{
    var h = ctx.Response.Headers;
    h["X-Content-Type-Options"] = "nosniff";
    h["X-Frame-Options"] = "DENY";
    h["Referrer-Policy"] = "no-referrer";
    h["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()";
    h["Content-Security-Policy"] = "default-src 'none'; frame-ancestors 'none'";
    await next();
});
app.UseCors("web");
app.Use(async (ctx, next) =>         // B21: SameSite=Lax + custom header (forces preflight) + Origin allowlist
{
    var m = ctx.Request.Method;
    if (!HttpMethods.IsGet(m) && !HttpMethods.IsHead(m) && !HttpMethods.IsOptions(m))
    {
        var origin = ctx.Request.Headers.Origin.ToString();
        if (!ctx.Request.Headers.ContainsKey("X-CSRF") || (origin.Length > 0 && !origins.Contains(origin)))
        {
            ctx.Response.StatusCode = StatusCodes.Status403Forbidden;
            return;
        }
    }
    await next();
});
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

app.MapPost("/api/auth/login", async (LoginDto dto, AppDb db, IPasswordHasher<User> hasher, HttpContext http) =>
{
    // B15: .NET 8/9 minimal APIs do NOT validate models; validate by hand (or with a FluentValidation filter)
    if (string.IsNullOrWhiteSpace(dto.Email) || dto.Email.Length > 254 ||
        string.IsNullOrEmpty(dto.Password) || dto.Password.Length > 128)
        return Results.ValidationProblem(new Dictionary<string, string[]> { ["credentials"] = ["Invalid input."] });

    var fail = Results.Problem("Invalid email or password.", statusCode: StatusCodes.Status401Unauthorized);
    var email = dto.Email.Trim().ToLowerInvariant();
    var user = await db.Users.SingleOrDefaultAsync(u => u.Email == email);
    if (user is null)
    {
        hasher.VerifyHashedPassword(new User(), dummyHash, dto.Password); // B07: same cost as a real check
        return fail;
    }

    // B07: verify first so a locked account answers in the same time
    var result = hasher.VerifyHashedPassword(user, user.PasswordHash, dto.Password);
    var locked = user.LockoutEnd > DateTime.UtcNow;
    if (locked || result == PasswordVerificationResult.Failed)
    {
        // shortcut: the counter is not concurrency-safe, parallel guesses can overshoot by a few; add a rowversion if it matters
        if (!locked && ++user.FailedLogins >= 5)
        {
            user.LockoutEnd = DateTime.UtcNow.AddMinutes(15); // B06: per-account, time-limited lock
            user.FailedLogins = 0;
        }
        await db.SaveChangesAsync();
        return fail;
    }

    if (result == PasswordVerificationResult.SuccessRehashNeeded)
        user.PasswordHash = hasher.HashPassword(user, dto.Password);
    user.FailedLogins = 0;
    var session = new Session
    {
        Id = Convert.ToHexString(RandomNumberGenerator.GetBytes(32)),
        UserId = user.Id,
        ExpiresAt = DateTime.UtcNow.AddHours(8), // absolute cap on top of the 30-minute sliding cookie
    };
    db.Sessions.Add(session);
    await db.SaveChangesAsync();

    var identity = new ClaimsIdentity(
    [
        new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
        new Claim(ClaimTypes.Role, user.Role),
        new Claim("sid", session.Id),
    ], CookieAuthenticationDefaults.AuthenticationScheme);
    await http.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, new ClaimsPrincipal(identity));
    // B31: write an audit event here (user id, IP, result); never the password
    return Results.NoContent();
}).AllowAnonymous().RequireRateLimiting("login");

app.MapPost("/api/auth/logout", async (ClaimsPrincipal principal, AppDb db, HttpContext http) =>
{
    var sid = principal.FindFirstValue("sid");
    await db.Sessions.Where(s => s.Id == sid).ExecuteDeleteAsync(); // B04: a stolen cookie is now dead
    await http.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
    return Results.NoContent();
});
// On password change: db.Sessions.Where(s => s.UserId == id).ExecuteDeleteAsync()

app.MapGet("/api/orders/{id:int}", async (int id, ClaimsPrincipal principal, AppDb db, CancellationToken ct) =>
{
    var userId = int.Parse(principal.FindFirstValue(ClaimTypes.NameIdentifier)!); // B12: from the session, never the request
    var order = await db.Orders.AsNoTracking()
        .Where(o => o.Id == id && o.UserId == userId) // B11: ownership inside the query; someone else's order is 404
        .Select(o => new OrderDto(o.Id, o.Total, o.Status, o.CreatedAt))
        .FirstOrDefaultAsync(ct);
    return order is null ? Results.NotFound() : Results.Ok(order);
});

app.Run();

static string Ip(HttpContext ctx) => ctx.Connection.RemoteIpAddress?.ToString() ?? "unknown";

record LoginDto(string Email, string Password);
record OrderDto(int Id, decimal Total, string Status, DateTime CreatedAt);

class User
{
    public int Id { get; set; }
    public string Email { get; set; } = "";        // stored lower-cased, unique index
    public string PasswordHash { get; set; } = "";
    public string Role { get; set; } = "user";
    public int FailedLogins { get; set; }
    public DateTime? LockoutEnd { get; set; }
}
class Session
{
    public string Id { get; set; } = "";
    public int UserId { get; set; }
    public DateTime ExpiresAt { get; set; }
}
class Order
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public decimal Total { get; set; }
    public string Status { get; set; } = "";
    public DateTime CreatedAt { get; set; }
}
class AppDb(DbContextOptions<AppDb> options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<Session> Sessions => Set<Session>();
    public DbSet<Order> Orders => Set<Order>();
    protected override void OnModelCreating(ModelBuilder b)
    {
        b.Entity<User>().HasIndex(u => u.Email).IsUnique();
        b.Entity<Session>().HasIndex(s => s.UserId);
        b.Entity<Order>().HasIndex(o => o.UserId);
        b.Entity<Order>().Property(o => o.Total).HasPrecision(18, 2);
    }
}
```

The SPA must send the `X-CSRF: 1` header and `credentials: 'include'` on every POST, PUT and DELETE.

## Middleware order
1. `UseForwardedHeaders`
2. `UseExceptionHandler`
3. `UseHsts`
4. Security headers
5. `UseCors`
6. CSRF check
7. `UseRateLimiter`
8. `UseAuthentication`
9. `UseAuthorization`
10. Endpoints

Pitfalls of this order:
- **If forwarded headers are not first,** rate limiting, HSTS and logs all see the proxy's IP.
- **`ASPNETCORE_FORWARDEDHEADERS_ENABLED=true`** clears `KnownProxies` and trusts every proxy. Don't use it in production.

## Item notes

### B01 Passwords
- Identity's V3 hash format uses PBKDF2-HMAC-SHA512 with 100k iterations by default. The reference raises it to 210k (OWASP's recommendation).
- For Argon2id, use the `Konscious.Security.Cryptography.Argon2` package.

### B04 Server-side revocation
- **With Identity:** call `UpdateSecurityStampAsync` on password change. `SecurityStampValidator` checks only **every 30 minutes** by default; shorten it: `builder.Services.Configure<SecurityStampValidatorOptions>(o => o.ValidationInterval = TimeSpan.FromMinutes(1));`
- **Without Identity:** use the `OnValidatePrincipal` + session table pattern from the reference.
- **Alternative:** keep the ticket itself on the server with `o.SessionStore = new MyTicketStore()` (`ITicketStore`).

### B05 JWT (only if tokens are used)
Package: `Microsoft.AspNetCore.Authentication.JwtBearer`
```csharp
.AddJwtBearer(o => o.TokenValidationParameters = new TokenValidationParameters
{
    ValidateIssuer = true, ValidIssuer = cfg["Jwt:Issuer"],
    ValidateAudience = true, ValidAudience = cfg["Jwt:Audience"],
    ValidateLifetime = true, ClockSkew = TimeSpan.FromSeconds(30),
    ValidateIssuerSigningKey = true, IssuerSigningKey = key,     // ≥32 random bytes
    ValidAlgorithms = [SecurityAlgorithms.HmacSha256],
});
```

### B06 With Identity
- Configure `Lockout` (`MaxFailedAccessAttempts`, `DefaultLockoutTimeSpan`).
- **And** call `CheckPasswordSignInAsync(user, pwd, lockoutOnFailure: true)`. The parameter defaults to `false`, so if you omit it the lock never triggers.

### B15 Validation
- **Controllers:** `[ApiController]` returns 400 automatically for invalid models.
- **Minimal APIs on .NET 8/9:** no automatic validation. Call FluentValidation from an endpoint filter or validate by hand.
- **.NET 10:** `builder.Services.AddValidation();` enables DataAnnotations validation for minimal APIs.

### B16 SQL
```csharp
db.Orders.FromSql($"SELECT * FROM orders WHERE id = {id}");        // ✅ parameterized (EF7+; formerly FromSqlInterpolated)
db.Orders.FromSqlRaw("SELECT * FROM orders WHERE id = " + id);     // ❌ (EF1003 warning)
```
Dynamic sorting: `sort switch { "total" => q.OrderBy(o => o.Total), _ => q.OrderBy(o => o.CreatedAt) }`

For multi-tenancy use a global query filter: `HasQueryFilter(o => o.TenantId == _tenantId)`. Two caveats:
- `_tenantId` must be **a field of the DbContext**. A captured local gets baked into the cached model and every tenant ends up seeing the same data.
- `IgnoreQueryFilters()` turns the filter off. Use it only in admin flows.

### B19 Deserialization
- `BinaryFormatter`: a compile error in net8 ASP.NET projects (SYSLIB0011); removed in .NET 9+, always throws `PlatformNotSupportedException`.
- With Newtonsoft, `TypeNameHandling` must be `None`.
- With System.Text.Json polymorphism, allow only types registered with `[JsonDerivedType]`. Never deserialize to `object` and cast.

### B21 Antiforgery (.NET 8+)
- With `AddAntiforgery`, the antiforgery middleware is added automatically, but it validates only form-bound endpoints (`[FromForm]`, `IFormFile`), not JSON.
- For JSON APIs, use the custom header + Origin pattern from the reference.
- Upload endpoints taking `IFormFile` (B27) require a token. If you won't send one, call `.DisableAntiforgery()` and put an alternative check in place.

### B22 CORS + cookies
- A `SameSite=Lax` cookie is not sent on cross-site fetches. The SPA and API must be **same-site** (e.g. `app.example.com` and `api.example.com`). If they are cross-site, use a BFF; don't switch to `SameSite=None`.
- Without `app.UseCors("web")` the policy is never applied.

### B27 Upload
- Limit size with `[RequestSizeLimit(5_000_000)]` or `.WithMetadata(new RequestSizeLimitAttribute(5_000_000))`.
- Allowlist extensions and check the first bytes (PNG: `89 50 4E 47`).
- Use `$"{Guid.NewGuid()}{ext}"` as the file name.
- Store outside `wwwroot` or in private Blob/S3 and serve via SAS or signed URLs.

### B28 Secrets and Data Protection
- **Development:**
  ```
  dotnet user-secrets init
  dotnet user-secrets set "Jwt:Key" "..."
  ```
  `set` does not work until `init` has run.
- **Production:**
  ```csharp
  builder.Configuration.AddAzureKeyVault(new Uri(vaultUri), new ManagedIdentityCredential());
  ```
  - Packages: `Azure.Extensions.AspNetCore.Configuration.Secrets` and `Azure.Identity`.
  - In production prefer `ManagedIdentityCredential` over `DefaultAzureCredential`, which probes a chain of credentials, is slow and can pick the wrong one.
- **Data Protection keys:** cookie auth depends on them. In containers or with several instances, persist and protect the keys: `AddDataProtection().PersistKeysToAzureBlobStorage(...).ProtectKeysWithAzureKeyVault(...)`, or a DB/Redis store. Otherwise every restart signs everyone out and instances cannot read each other's cookies.
- No secrets in `appsettings.json`.

### B30 Production config
- `UseDeveloperExceptionPage` only in Development.
- **.NET 9+:** `builder.Services.AddOpenApi();` + `if (app.Environment.IsDevelopment()) app.MapOpenApi();` Package: `Microsoft.AspNetCore.OpenApi`.
- **.NET 8 + Swashbuckle:** `AddSwaggerGen()` + `UseSwagger()`/`UseSwaggerUI()` only in Development. Package: `Swashbuckle.AspNetCore`.
- `X-Powered-By` is added by IIS, not Kestrel. If you host on IIS, remove it in `web.config`.

### B31 Logging
Structured logging with Serilog. Don't log request bodies. Mask password and token fields with a destructuring policy.

### B36 Dependencies
- Command: `dotnet list package --vulnerable --include-transitive`. On .NET 10, `dotnet package list --vulnerable --include-transitive` also works.
- .NET 8+ runs NuGetAudit on every restore (NU1901–NU1904). Add `<NuGetAuditMode>all</NuGetAuditMode>` and `<WarningsAsErrors>NU1903;NU1904</WarningsAsErrors>` to the `.csproj`. `NuGetAuditMode` defaults to `all` only on net10.

### B38 Health
`builder.Services.AddHealthChecks(); app.MapHealthChecks("/health").AllowAnonymous();`

The default writer outputs only the status (`Healthy`/`Unhealthy`).

## .NET 9 / 10 differences
- **Swashbuckle:** replaced by `AddOpenApi`/`MapOpenApi` (9+).
- **Validation:** `AddValidation()` enables DataAnnotations for minimal APIs (10).
- **Cookie auth:** returns 401/403 instead of redirecting for known API endpoints (10). The events in the reference are required on 8/9 and harmless on 10.
- **Forwarded headers:** `KnownNetworks` is obsolete (ASPDEPR005); use `KnownIPNetworks` (10).
- **BinaryFormatter:** removed (9).

## Controller notes
- Identity is read from `ControllerBase.User`. In minimal APIs, take a `ClaimsPrincipal` parameter in the handler.
- `[ApiController]` returns 400 automatically.
- `[AllowAnonymous]` and `[Authorize(Roles = "admin")]` are the counterparts of `.AllowAnonymous()` and `.RequireAuthorization("admin")` in minimal APIs.
