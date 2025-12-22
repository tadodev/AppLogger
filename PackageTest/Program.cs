using System.Reflection;

Console.WriteLine("=== AppLoggerT Package Test ===");
Console.WriteLine();

// Test 1: Verify AppLogger is available
Console.WriteLine("[Test 1] Checking AppLogger availability...");
try
{
    var logger = new AppLogger.Logger();
    logger.Log("Logger created successfully!");
    Console.WriteLine("✓ AppLogger works correctly");
}
catch (Exception ex)
{
    Console.WriteLine($"✗ AppLogger failed: {ex.Message}");
    return;
}

Console.WriteLine();

// Test 2: Verify ETABSv1.dll is in output directory
Console.WriteLine("[Test 2] Checking ETABSv1.dll availability...");
var outputDir = AppDomain.CurrentDomain.BaseDirectory;
var etabsDllPath = Path.Combine(outputDir, "ETABSv1.dll");

if (File.Exists(etabsDllPath))
{
    Console.WriteLine($"✓ ETABSv1.dll found at: {etabsDllPath}");
    var fileInfo = new FileInfo(etabsDllPath);
    Console.WriteLine($"  Size: {fileInfo.Length:N0} bytes");
    Console.WriteLine($"  Modified: {fileInfo.LastWriteTime}");
}
else
{
    Console.WriteLine($"✗ ETABSv1.dll NOT found at: {etabsDllPath}");
    Console.WriteLine("  This will cause runtime errors when calling ETABS methods.");
    return;
}

Console.WriteLine();

// Test 3: Try to load ETABSv1 assembly
Console.WriteLine("[Test 3] Attempting to load ETABSv1 assembly...");
try
{
    var assembly = Assembly.LoadFrom(etabsDllPath);
    Console.WriteLine($"✓ Successfully loaded: {assembly.FullName}");

    // Try to get the Helper type
    var helperType = assembly.GetType("ETABSv1.Helper");
    if (helperType != null)
    {
        Console.WriteLine("✓ ETABSv1.Helper type found");
    }
}
catch (Exception ex)
{
    Console.WriteLine($"✗ Failed to load ETABSv1: {ex.Message}");
    return;
}

Console.WriteLine();

// Test 4: Try to create ETABS model
Console.WriteLine("[Test 4] Testing ETABS API functionality...");
Console.WriteLine("Creating steel deck model (this will launch ETABS)...");
Console.WriteLine();

try
{
    AppLogger.EtabsConnect.CreateSteelDeckModel();
    Console.WriteLine();
    Console.WriteLine("✓ ETABS model created successfully!");
}
catch (Exception ex)
{
    Console.WriteLine($"✗ ETABS operation failed: {ex.Message}");
    Console.WriteLine($"  Type: {ex.GetType().Name}");
    if (ex.InnerException != null)
    {
        Console.WriteLine($"  Inner: {ex.InnerException.Message}");
    }
    Console.WriteLine();
    Console.WriteLine("Stack trace:");
    Console.WriteLine(ex.StackTrace);
    return;
}

Console.WriteLine();
Console.WriteLine("=== All Tests Passed! ===");