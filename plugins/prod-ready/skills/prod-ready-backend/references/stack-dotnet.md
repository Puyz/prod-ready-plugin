# ASP.NET Core (8+) uygulama notları

Aşağıdaki referans `Program.cs`, minimal API ile yazılmıştır ve **net8.0 üzerinde 0 hata, 0 uyarıyla derlenmiştir**. Tek NuGet bağımlılığı `Microsoft.EntityFrameworkCore.SqlServer`'dır. Controller kullanılıyorsa eşdeğerleri en alttaki "Controller notları" bölümünde.

Başlıklardaki ID'ler `SKILL.md` içindeki maddelere karşılık gelir.

## Referans Program.cs

Kapsadığı maddeler: B01, B02, B04, B06, B07, B10, B11, B12, B15, B21, B22, B24, B25, B26, B29.

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

// B01: Identity'nin PBKDF2-SHA512 hasher'ı, OWASP iterasyonuyla (tam Identity gerekmez)
builder.Services.Configure<PasswordHasherOptions>(o => o.IterationCount = 210_000);
builder.Services.AddSingleton<IPasswordHasher<User>, PasswordHasher<User>>();

// B02/B04/B25: cookie yalnızca session id taşır; geçerlilik DB'deki session satırından gelir
builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(o =>
    {
        o.Cookie.Name = "__Host-session";
        o.Cookie.HttpOnly = true;
        o.Cookie.SecurePolicy = CookieSecurePolicy.Always;
        o.Cookie.SameSite = SameSiteMode.Lax; // SPA ve API aynı site (eTLD+1) olmalı
        o.ExpireTimeSpan = TimeSpan.FromMinutes(30);
        o.SlidingExpiration = true;
        o.Events.OnRedirectToLogin = ctx => { ctx.Response.StatusCode = 401; return Task.CompletedTask; };
        o.Events.OnRedirectToAccessDenied = ctx => { ctx.Response.StatusCode = 403; return Task.CompletedTask; };
        o.Events.OnValidatePrincipal = async ctx =>
        {
            // shortcut: her istekte bir DB sorgusu; profilde görünürse kısa süreli cache ekle
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

// B10: varsayılan deny; public endpoint'ler AllowAnonymous() ile açılır
builder.Services.AddAuthorizationBuilder()
    .SetFallbackPolicy(new AuthorizationPolicyBuilder().RequireAuthenticatedUser().Build());

builder.Services.AddCors(o => o.AddPolicy("web", p => p
    .WithOrigins(origins).AllowCredentials()
    .WithHeaders("Content-Type", "X-CSRF").WithMethods("GET", "POST", "PUT", "DELETE")));

// B06/B26: IP başına partition. DİKKAT: AddFixedWindowLimiter("login", ...) TÜM istemciler için TEK bucket'tır.
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

// B26: X-Forwarded-* yalnızca bilinen proxy'den kabul edilir
builder.Services.Configure<ForwardedHeadersOptions>(o =>
{
    o.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    o.KnownProxies.Add(IPAddress.Parse(cfg["Proxy:Ip"] ?? throw new InvalidOperationException("Proxy:Ip missing")));
});

var app = builder.Build();
var dummyHash = app.Services.GetRequiredService<IPasswordHasher<User>>().HashPassword(new User(), "timing-equalizer");

app.UseForwardedHeaders();           // İLK middleware: altındakiler gerçek IP/şemayı görür
app.UseExceptionHandler();           // B29: ProblemDetails + traceId, stack trace yok
app.UseStatusCodePages();
if (!app.Environment.IsDevelopment()) app.UseHsts();
// B23: API'de UseHttpsRedirection kullanma; istemci cookie'yi zaten HTTP'den göndermiş olur. HTTP dinleme.
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
app.Use(async (ctx, next) =>         // B21: SameSite=Lax + custom header (preflight zorlar) + Origin allowlist
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
    // B15: .NET 8/9 minimal API'de model validation YOK; elle (veya FluentValidation filter'ıyla) doğrula
    if (string.IsNullOrWhiteSpace(dto.Email) || dto.Email.Length > 254 ||
        string.IsNullOrEmpty(dto.Password) || dto.Password.Length > 128)
        return Results.ValidationProblem(new Dictionary<string, string[]> { ["credentials"] = ["Invalid input."] });

    var fail = Results.Problem("Invalid email or password.", statusCode: StatusCodes.Status401Unauthorized);
    var email = dto.Email.Trim().ToLowerInvariant();
    var user = await db.Users.SingleOrDefaultAsync(u => u.Email == email);
    if (user is null)
    {
        hasher.VerifyHashedPassword(new User(), dummyHash, dto.Password); // B07: gerçek kontrolle aynı maliyet
        return fail;
    }

    // B07: kilitli hesap da aynı sürede yanıtlansın diye önce doğrula
    var result = hasher.VerifyHashedPassword(user, user.PasswordHash, dto.Password);
    var locked = user.LockoutEnd > DateTime.UtcNow;
    if (locked || result == PasswordVerificationResult.Failed)
    {
        // shortcut: sayaç eşzamanlılığa dayanıklı değil, paralel denemeler birkaç fazla sayabilir; gerekirse rowversion ekle
        if (!locked && ++user.FailedLogins >= 5)
        {
            user.LockoutEnd = DateTime.UtcNow.AddMinutes(15); // B06: hesap bazlı süreli kilit
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
        ExpiresAt = DateTime.UtcNow.AddHours(8), // 30 dk sliding cookie üstüne mutlak sınır
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
    // B31: burada audit olayı yaz (user id, IP, sonuç); parola asla
    return Results.NoContent();
}).AllowAnonymous().RequireRateLimiting("login");

app.MapPost("/api/auth/logout", async (ClaimsPrincipal principal, AppDb db, HttpContext http) =>
{
    var sid = principal.FindFirstValue("sid");
    await db.Sessions.Where(s => s.Id == sid).ExecuteDeleteAsync(); // B04: çalınan cookie artık geçersiz
    await http.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
    return Results.NoContent();
});
// Parola değişiminde: db.Sessions.Where(s => s.UserId == id).ExecuteDeleteAsync()

app.MapGet("/api/orders/{id:int}", async (int id, ClaimsPrincipal principal, AppDb db, CancellationToken ct) =>
{
    var userId = int.Parse(principal.FindFirstValue(ClaimTypes.NameIdentifier)!); // B12: oturumdan, asla istekten
    var order = await db.Orders.AsNoTracking()
        .Where(o => o.Id == id && o.UserId == userId) // B11: sahiplik sorgunun içinde; başkasınınki 404
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
    public string Email { get; set; } = "";        // küçük harfle saklanır, unique index
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

SPA her POST, PUT ve DELETE isteğinde `X-CSRF: 1` header'ını ve `credentials: 'include'` ayarını göndermeli.

## Middleware sırası
1. `UseForwardedHeaders`
2. `UseExceptionHandler`
3. `UseHsts`
4. Security header'lar
5. `UseCors`
6. CSRF kontrolü
7. `UseRateLimiter`
8. `UseAuthentication`
9. `UseAuthorization`
10. Endpoint'ler

Bu sıranın tuzakları:
- **Forwarded headers ilk sırada değilse** rate limit, HSTS ve log'lar proxy'nin IP'sini görür.
- **`ASPNETCORE_FORWARDEDHEADERS_ENABLED=true`** ayarı `KnownProxies` listesini temizler ve her proxy'ye güvenir. Bu ayarı prod'da kullanma.

## Madde notları

### B01 Parola
- Identity'nin V3 hash formatı PBKDF2-HMAC-SHA512 kullanır, varsayılan 100 bin iterasyonla. Referanstaki ayarla 210 bin yap (OWASP önerisi).
- Argon2id istersen `Konscious.Security.Cryptography.Argon2` paketini kullan.

### B04 Sunucu tarafında iptal
- **Identity kullanıyorsan:** Parola değişince `UpdateSecurityStampAsync` çağır. `SecurityStampValidator` varsayılan olarak **30 dakikada bir** kontrol eder. Bunu kısalt: `builder.Services.Configure<SecurityStampValidatorOptions>(o => o.ValidationInterval = TimeSpan.FromMinutes(1));`
- **Identity yoksa:** Referanstaki `OnValidatePrincipal` + session tablosu desenini kullan.
- **Alternatif:** Ticket'ın kendisini sunucuda tutmak için `o.SessionStore = new MyTicketStore()` (`ITicketStore`) kullanabilirsin.

### B05 JWT (yalnızca token kullanılıyorsa)
Paket: `Microsoft.AspNetCore.Authentication.JwtBearer`
```csharp
.AddJwtBearer(o => o.TokenValidationParameters = new TokenValidationParameters
{
    ValidateIssuer = true, ValidIssuer = cfg["Jwt:Issuer"],
    ValidateAudience = true, ValidAudience = cfg["Jwt:Audience"],
    ValidateLifetime = true, ClockSkew = TimeSpan.FromSeconds(30),
    ValidateIssuerSigningKey = true, IssuerSigningKey = key,     // ≥32 byte rastgele
    ValidAlgorithms = [SecurityAlgorithms.HmacSha256],
});
```

### B06 Identity kullanıyorsan
- `Lockout` ayarlarını yap: `MaxFailedAccessAttempts`, `DefaultLockoutTimeSpan`.
- **Ve** `CheckPasswordSignInAsync(user, pwd, lockoutOnFailure: true)` çağır. Bu parametrenin varsayılanı `false` olduğu için atlanırsa kilit hiç devreye girmez.

### B15 Validation
- **Controller:** `[ApiController]` attribute'u geçersiz modelde otomatik 400 döner.
- **Minimal API, .NET 8/9:** Otomatik validation yoktur. FluentValidation'ı bir endpoint filter içinde çağır ya da elle doğrula.
- **.NET 10:** `builder.Services.AddValidation();` minimal API'de DataAnnotations doğrulamasını açar.

### B16 SQL
```csharp
db.Orders.FromSql($"SELECT * FROM orders WHERE id = {id}");        // ✅ parametreli (EF7+; eski adı FromSqlInterpolated)
db.Orders.FromSqlRaw("SELECT * FROM orders WHERE id = " + id);     // ❌ (EF1003 uyarısı)
```
Dinamik sıralama için: `sort switch { "total" => q.OrderBy(o => o.Total), _ => q.OrderBy(o => o.CreatedAt) }`

Multi-tenant yapıda global query filter kullan: `HasQueryFilter(o => o.TenantId == _tenantId)`. İki dikkat noktası var:
- `_tenantId` **DbContext'in bir alanı** olmalı. Dışarıdan yakalanan bir local değişken cache'lenen modele gömülür ve sonuçta tüm tenant'lar aynı veriyi görür.
- `IgnoreQueryFilters()` filtreyi kapatır. Yalnızca admin akışında kullan.

### B19 Deserialization
- `BinaryFormatter`: net8 ASP.NET projelerinde derleme hatası verir (SYSLIB0011). .NET 9+'da kaldırıldı ve her zaman `PlatformNotSupportedException` atar.
- Newtonsoft kullanılıyorsa `TypeNameHandling.None` olmalı.
- System.Text.Json polimorfizminde yalnızca `[JsonDerivedType]` ile allowlist'e eklenmiş tipler kullanılmalı. `object`'e deserialize edip sonra cast etme.

### B21 Antiforgery (.NET 8+)
- `AddAntiforgery` eklendiğinde antiforgery middleware otomatik devreye girer. Ancak yalnızca form-bound endpoint'leri (`[FromForm]`, `IFormFile`) doğrular, JSON istekleri doğrulamaz.
- JSON API için referanstaki custom header + Origin desenini kullan.
- `IFormFile` alan upload endpoint'leri (B27) token ister. Token göndermeyeceksen `.DisableAntiforgery()` çağır ve yerine bir alternatif kontrol koy.

### B22 CORS + cookie
- `SameSite=Lax` olan bir cookie cross-site fetch isteklerinde gönderilmez. SPA ile API **aynı sitede** olmalı (ör. `app.example.com` ve `api.example.com`). Farklı sitelerdeyse BFF kullan, `SameSite=None`'a geçme.
- `app.UseCors("web")` çağrısı yapılmazsa policy hiç uygulanmaz.

### B27 Upload
- Boyutu `[RequestSizeLimit(5_000_000)]` veya `.WithMetadata(new RequestSizeLimitAttribute(5_000_000))` ile sınırla.
- Uzantıyı allowlist'ten geçir ve dosyanın ilk byte'larını kontrol et (PNG için `89 50 4E 47`).
- Dosya adı olarak `$"{Guid.NewGuid()}{ext}"` kullan.
- Dosyaları `wwwroot` dışında ya da private Blob/S3'te tut ve SAS veya signed URL ile sun.

### B28 Secret ve Data Protection
- **Development:**
  ```
  dotnet user-secrets init
  dotnet user-secrets set "Jwt:Key" "..."
  ```
  `init` komutu çalıştırılmadan `set` çalışmaz.
- **Prod:**
  ```csharp
  builder.Configuration.AddAzureKeyVault(new Uri(vaultUri), new ManagedIdentityCredential());
  ```
  - Gereken paketler: `Azure.Extensions.AspNetCore.Configuration.Secrets` ve `Azure.Identity`.
  - Prod'da `DefaultAzureCredential` yerine `ManagedIdentityCredential` kullan. `DefaultAzureCredential` bir dizi kimlik yöntemini sırayla dener, bu yavaştır ve yanlış kimliği seçebilir.
- **Data Protection anahtarları:** Cookie auth bu anahtarlara bağlıdır. Container'da veya birden fazla instance çalışıyorsa anahtarları kalıcı ve korumalı bir yerde sakla: `AddDataProtection().PersistKeysToAzureBlobStorage(...).ProtectKeysWithAzureKeyVault(...)` ya da DB veya Redis store. Aksi halde her restart herkesin oturumunu kapatır ve instance'lar birbirinin cookie'sini okuyamaz.
- `appsettings.json` içinde secret olmamalı.

### B30 Prod config
- `UseDeveloperExceptionPage` yalnızca Development ortamında açık olmalı.
- **.NET 9+:** `builder.Services.AddOpenApi();` + `if (app.Environment.IsDevelopment()) app.MapOpenApi();`. Paket: `Microsoft.AspNetCore.OpenApi`.
- **.NET 8 + Swashbuckle:** `AddSwaggerGen()` + `UseSwagger()`/`UseSwaggerUI()` yalnızca Development'ta. Paket: `Swashbuckle.AspNetCore`.
- `X-Powered-By` header'ını Kestrel değil IIS ekler. IIS kullanıyorsan `web.config` dosyasından kaldır.

### B31 Log
Serilog ile yapılandırılmış log kullan. Request body'lerini loglama. Parola ve token alanlarını destructuring policy ile maskele.

### B36 Bağımlılık
- Komut: `dotnet list package --vulnerable --include-transitive`. .NET 10'da `dotnet package list --vulnerable --include-transitive` da çalışır.
- .NET 8+ her restore'da NuGetAudit çalıştırır (NU1901–NU1904 uyarıları). `.csproj`'a `<NuGetAuditMode>all</NuGetAuditMode>` ve `<WarningsAsErrors>NU1903;NU1904</WarningsAsErrors>` ekle. `NuGetAuditMode` varsayılan olarak `all` değerini yalnızca net10'da alır.

### B38 Health
`builder.Services.AddHealthChecks(); app.MapHealthChecks("/health").AllowAnonymous();`

Varsayılan writer yalnızca durumu (`Healthy`/`Unhealthy`) yazar.

## .NET 9 / 10 farkları
- **Swashbuckle:** Yerine `AddOpenApi`/`MapOpenApi` (9+).
- **Validation:** `AddValidation()` minimal API'de DataAnnotations doğrulamasını açar (10).
- **Cookie auth:** Bilinen API endpoint'lerinde redirect yerine kendiliğinden 401/403 döner (10). Referanstaki event'ler 8/9 için gereklidir; 10'da da zararsızdır.
- **Forwarded headers:** `KnownNetworks` obsolete oldu (ASPDEPR005), yerine `KnownIPNetworks` (10).
- **BinaryFormatter:** Kaldırıldı (9).

## Controller notları
- Kimlik bilgisi `ControllerBase.User` üzerinden okunur. Minimal API'de ise `ClaimsPrincipal` handler'a parametre olarak alınır.
- `[ApiController]` otomatik 400 döner.
- `[AllowAnonymous]` ve `[Authorize(Roles = "admin")]` attribute'ları, minimal API'deki `.AllowAnonymous()` ve `.RequireAuthorization("admin")` karşılıklarıdır.
