# 11 - Configuration Management Rules

---

## DO

1. **Use the Options Pattern** whenever possible (JwtOptions, EventBus options, caching...).
   Configuration read once at startup may be read directly from `IConfiguration` when that is simpler.

2. **Validate at startup** (recommended):

   ```csharp
   services.AddOptions<JwtOptions>()
       .BindConfiguration(JwtOptions.SectionName)
       .ValidateDataAnnotations()
       .ValidateOnStart();
   ```

3. **Structure appsettings into clear sections** (Database, Redis, Jwt, EventBus:*, OpenTelemetry:...).

4. **Separate environments**: appsettings.json (safe), .Development.json (never commit real secrets), user-secrets for dev, Docker secrets / Vault for prod.

5. **Options classes use Data Annotations for validation:**

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

6. **Feature flags** for toggling features without a redeploy:

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

1. Do **NOT** read `IConfiguration["Section:Key"]` directly in business logic:

   ```csharp
   // [FAIL] WRONG
   var connStr = _config["Database:ConnectionString"];
   // [OK] CORRECT
   var connStr = _dbOptions.Value.ConnectionString;
   ```

2. Do **NOT** commit secrets, connection strings, or API keys into source code or appsettings.json:

   ```json
   // [FAIL] WRONG - committed to git
   { "Jwt": { "SecretKey": "my-super-secret-key" } }
   ```

   Use `dotnet user-secrets set "Jwt:SecretKey" "..."` during development.

3. Do **NOT** skip `ValidateOnStart()` - missing/invalid config should crash at startup, not at runtime.

4. Do **NOT** inject `IConfiguration` into the Domain or Application layer.

5. Do **NOT** reference a section name with a raw `string` constant:

   ```csharp
   // [FAIL] WRONG - typo-prone, cannot be refactored
   .BindConfiguration("Dtabase")
   // [OK] CORRECT
   .BindConfiguration(DatabaseOptions.SectionName)
   ```

## Illustrative example

```csharp
// -- Infrastructure/Options/DatabaseOptions.cs
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

// -- Infrastructure/Options/RabbitMqOptions.cs
public class RabbitMqOptions
{
    public const string SectionName = "RabbitMq";

    [Required] public string Host     { get; set; } = default!;
    [Required] public string Username { get; set; } = default!;
    [Required] public string Password { get; set; } = default!;
    public int Port { get; set; } = 5672;
}

// -- Infrastructure/DependencyInjection.cs
services.AddOptions<DatabaseOptions>()
    .BindConfiguration(DatabaseOptions.SectionName)
    .ValidateDataAnnotations()
    .ValidateOnStart();

services.AddOptions<RabbitMqOptions>()
    .BindConfiguration(RabbitMqOptions.SectionName)
    .ValidateDataAnnotations()
    .ValidateOnStart();

// -- appsettings.json (safe - no secrets)
{
  "Database": {
    "MaxRetryCount": 3,
    "CommandTimeoutSeconds": 30
  },
  "Jwt": {
    "Issuer": "https://id.example.com",
    "Audience": "{Company}API",
    "ExpiryMinutes": 60
  },
  "Features": {
    "EnableAiSuggestions": false,
    "EnableBulkImport": true
  }
}

// -- appsettings.Development.json (never commit the real ConnectionString)
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Database={database}_dev;Username=postgres;Password=postgres"
  }
}
```
