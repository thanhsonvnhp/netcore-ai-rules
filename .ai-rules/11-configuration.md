# 11 – Configuration Management Rules

---

## DO

1. **Dùng Options Pattern** khi có thể (JwtOptions, EventBus options, caching...). 
 Các cấu hình chỉ đọc một lần khi startup có thể cho phép đọc trực tiếp từ IConfiguration.

2. **Validate tại startup** (recommended):

   ```csharp
   services.AddOptions<JwtOptions>()
       .BindConfiguration(JwtOptions.SectionName)
       .ValidateDataAnnotations()
       .ValidateOnStart();
   ```

3. **Cấu trúc appsettings theo section rõ ràng** (Database, Redis, Jwt, EventBus:*, OpenTelemetry:...).

4. **Phân tách môi trường**: appsettings.json (safe), .Development.json (không commit secrets thật), user-secrets cho dev, Docker secrets / Vault cho prod.

5. **Options class dùng Data Annotations để validate:**

   ```csharp
   public class JwtOptions
   {
       public const string SectionName = "Jwt";

       [Required] public string Issuer    { get; set; } = default!;
       [Required] public string Audience  { get; set; } = default!;
       [Required] public string SecretKey { get; set; } = default!;
       [Range(1, 1440)] public int ExpiryMinutes { get; set; } = 60;
   }
   ```

6. **Feature flags** cho toggle tính năng không cần redeploy:

   ```csharp
   public class FeatureFlags
   {
       public bool EnableAiSuggestions { get; set; }
       public bool EnableBulkImport    { get; set; }
   }
   // Usage:
   if (_features.Value.EnableAiSuggestions) { ... }
   ```

## DON'T

1. **KHÔNG** đọc `IConfiguration["Section:Key"]` trực tiếp trong business logic:

   ```csharp
   // ❌ WRONG
   var connStr = _config["Database:ConnectionString"];
   // ✅ CORRECT
   var connStr = _dbOptions.Value.ConnectionString;
   ```

2. **KHÔNG** commit secrets, connection strings, API keys vào source code hay appsettings.json:

   ```json
   // ❌ WRONG — commit vào git
   { "Jwt": { "SecretKey": "my-super-secret-key" } }
   ```

   Dùng `dotnet user-secrets set "Jwt:SecretKey" "..."` khi phát triển.

3. **KHÔNG** bỏ qua `ValidateOnStart()` — nếu config thiếu/sai sẽ crash runtime thay vì startup.

4. **KHÔNG** inject `IConfiguration` vào Domain hoặc Application layer.

5. **KHÔNG** dùng `string` constant trực tiếp để trỏ section name:

   ```csharp
   // ❌ WRONG — dễ typo, không refactor được
   .BindConfiguration("Dtabase")
   // ✅ CORRECT
   .BindConfiguration(DatabaseOptions.SectionName)
   ```

## Ví dụ minh họa

```csharp
// ── Infrastructure/Options/DatabaseOptions.cs
public class DatabaseOptions
{
    public const string SectionName = "Database";

    [Required]
    public string ConnectionString { get; set; } = default!;

    [Range(1, 10)]
    public int MaxRetryCount { get; set; } = 3;

    [Range(5, 300)]
    public int CommandTimeoutSeconds { get; set; } = 30;
}

// ── Infrastructure/Options/RabbitMqOptions.cs
public class RabbitMqOptions
{
    public const string SectionName = "RabbitMq";

    [Required] public string Host     { get; set; } = default!;
    [Required] public string Username { get; set; } = default!;
    [Required] public string Password { get; set; } = default!;
    public int Port { get; set; } = 5672;
}

// ── Infrastructure/DependencyInjection.cs
services.AddOptions<DatabaseOptions>()
    .BindConfiguration(DatabaseOptions.SectionName)
    .ValidateDataAnnotations()
    .ValidateOnStart();

services.AddOptions<RabbitMqOptions>()
    .BindConfiguration(RabbitMqOptions.SectionName)
    .ValidateDataAnnotations()
    .ValidateOnStart();

// ── appsettings.json (safe — không có secrets)
{
  "Database": {
    "MaxRetryCount": 3,
    "CommandTimeoutSeconds": 30
  },
  "Jwt": {
    "Issuer": "https://id.smartoffice.vn",
    "Audience": "SmartOfficeAPI",
    "ExpiryMinutes": 60
  },
  "Features": {
    "EnableAiSuggestions": false,
    "EnableBulkImport": true
  }
}

// ── appsettings.Development.json (không commit ConnectionString thật)
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Database=smart_office_dev;Username=postgres;Password=postgres"
  }
}
```
