using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace AppLogger;

public class Logger
{
    private readonly ILogger<Logger>? _logger;

    public Logger()
    {
    }

    public Logger(ILogger<Logger> logger)
    {
        _logger = logger;
    }

    public void Log(string message)
    {
        if (_logger != null)
        {
            _logger.LogInformation(message);
        }
        else
        {
            Console.WriteLine($"Log: {message}");
        }
    }

    public void LogError(string message, Exception? exception = null)
    {
        if (_logger != null)
        {
            _logger.LogError(exception, message);
        }
        else
        {
            Console.WriteLine($"Error: {message}");
            if (exception != null)
                Console.WriteLine($"Exception: {exception.Message}");
        }
    }

    public void LogWarning(string message, Exception? exception = null)
    {
        if (_logger != null)
        {
            if (exception != null)
                _logger.LogWarning(exception, message);
            else
                _logger.LogWarning(message);
        }
        else
        {
            Console.WriteLine($"Warning: {message}");
            if (exception != null)
                Console.WriteLine($"Exception: {exception.Message}");
        }
    }
}

public static class LoggerServiceExtensions
{
    public static IServiceCollection AddAppLogger(this IServiceCollection services)
    {
        services.AddSingleton<Logger>();
        return services;
    }

    public static IHostBuilder AddAppLogger(this IHostBuilder hostBuilder)
    {
        return hostBuilder.ConfigureServices((context, services) =>
        {
            services.AddAppLogger();
        });
    }
}

/// <summary>
/// ETABS API connection and model creation utilities
/// </summary>
public static class EtabsConnect
{
    private static readonly Logger _logger = new();

    /// <summary>
    /// Creates a sample ETABS model with a steel deck template and performs basic API operations
    /// </summary>
    public static void CreateSample()
    {
        // Configuration flags
        bool AttachToInstance = true;  // Set to true to attach to existing ETABS instance
        bool SpecifyPath = false;       // Set to true to manually specify ETABS.exe path
        string ProgramPath = @"C:\Program Files\Computers and Structures\ETABS 22\ETABS.exe";

        // Model paths
        string ModelDirectory = @"C:\CSi_ETABS_API_Example";
        string ModelName = "ETABS_API_Example.edb";

        try
        {
            Directory.CreateDirectory(ModelDirectory);
            _logger.Log($"Model directory created/verified: {ModelDirectory}");
        }
        catch (Exception ex)
        {
            _logger.LogError($"Could not create directory: {ModelDirectory}", ex);
            return;
        }

        string ModelPath = Path.Combine(ModelDirectory, ModelName);

        // ETABS API objects
        ETABSv1.cOAPI? myETABSObject = null;
        int ret = 0;

        try
        {
            // Create API helper object
            ETABSv1.cHelper myHelper;
            try
            {
                myHelper = new ETABSv1.Helper();
                _logger.Log("Helper object created successfully");
            }
            catch (Exception ex)
            {
                _logger.LogError("Cannot create an instance of the Helper object", ex);
                return;
            }

            // Connect to ETABS instance or create new one
            if (AttachToInstance)
            {
                try
                {
                    myETABSObject = myHelper.GetObject("CSI.ETABS.API.ETABSObject");
                    _logger.Log("Attached to running ETABS instance");
                }
                catch (Exception ex)
                {
                    _logger.LogError("No running instance of ETABS found or failed to attach", ex);
                    return;
                }
            }
            else
            {
                try
                {
                    if (SpecifyPath)
                    {
                        myETABSObject = myHelper.CreateObject(ProgramPath);
                        _logger.Log($"ETABS instance created from: {ProgramPath}");
                    }
                    else
                    {
                        myETABSObject = myHelper.CreateObjectProgID("CSI.ETABS.API.ETABSObject");
                        _logger.Log("ETABS instance created from latest installed version");
                    }

                    ret = myETABSObject.ApplicationStart();
                    if (ret == 0)
                    {
                        _logger.Log("ETABS application started successfully");
                    }
                    else
                    {
                        _logger.LogWarning($"ApplicationStart returned: {ret}");
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError("Cannot start a new instance of ETABS", ex);
                    return;
                }
            }

            // Get SAP Model reference
            ETABSv1.cSapModel mySapModel = myETABSObject.SapModel;
            _logger.Log("SAP Model reference obtained");

            // Initialize new model
            ret = mySapModel.InitializeNewModel();
            if (ret == 0)
            {
                _logger.Log("New model initialized successfully");
            }
            else
            {
                _logger.LogWarning($"InitializeNewModel returned: {ret}");
            }

            // Create steel deck template model
            // Parameters: NumStories, XDim, YDim, StoryHeight, XJoints, YJoints, DeckType
            ret = mySapModel.File.NewSteelDeck(4, 12, 12, 4, 4, 24, 24);
            if (ret == 0)
            {
                _logger.Log("Steel deck template model created successfully with 4 stories");
            }
            else
            {
                _logger.LogWarning($"NewSteelDeck returned: {ret}");
            }

            // Save the model
            ret = mySapModel.File.Save(ModelPath);
            if (ret == 0)
            {
                _logger.Log($"Model saved successfully to: {ModelPath}");
            }
            else
            {
                _logger.LogWarning($"Save returned: {ret}");
            }

            // Run analysis
            ret = mySapModel.Analyze.RunAnalysis();
            if (ret == 0)
            {
                _logger.Log("Analysis completed successfully");
            }
            else
            {
                _logger.LogWarning($"RunAnalysis returned: {ret}");
            }

            // Get model statistics
            string[] FrameNames = new string[0];
            int NumberFrames = 0;
            int retFrames = mySapModel.FrameObj.GetNameList(ref NumberFrames, ref FrameNames);
            if (retFrames == 0)
            {
                _logger.Log($"Model contains {NumberFrames} frame objects");
            }

            // Refresh view
            mySapModel.View.RefreshView(0, false);
            _logger.Log("Model view refreshed");

            _logger.Log("ETABS sample model creation completed successfully!");
        }
        catch (Exception ex)
        {
            _logger.LogError("An unexpected error occurred during ETABS model creation", ex);
        }
        finally
        {
            // Cleanup
            if (myETABSObject != null)
            {
                try
                {
                    myETABSObject.ApplicationExit(false);
                    _logger.Log("ETABS application closed");
                }
                catch (Exception ex)
                {
                    _logger.LogWarning("Error closing ETABS application", ex);
                }

                try
                {
                    System.Runtime.InteropServices.Marshal.ReleaseComObject(myETABSObject);
                    _logger.Log("ETABS object released successfully");
                }
                catch (Exception ex)
                {
                    _logger.LogWarning("Error releasing ETABS object", ex);
                }
            }
        }
    }

    /// <summary>
    /// Creates a simple steel deck model for testing
    /// </summary>
    public static void CreateSteelDeckModel()
    {
        string ModelDirectory = @"C:\CSi_ETABS_API_Example";
        string ModelName = "SteelDeck_Model.edb";
        string ModelPath = Path.Combine(ModelDirectory, ModelName);

        ETABSv1.cOAPI? myETABSObject = null;
        int ret = 0;

        try
        {
            System.IO.Directory.CreateDirectory(ModelDirectory);
            _logger.Log($"Model directory: {ModelDirectory}");

            ETABSv1.cHelper myHelper = new ETABSv1.Helper();
            myETABSObject = myHelper.CreateObjectProgID("CSI.ETABS.API.ETABSObject");
            _logger.Log("ETABS object created");

            ret = myETABSObject.ApplicationStart();
            _logger.Log("ETABS application started");

            ETABSv1.cSapModel mySapModel = myETABSObject.SapModel;

            // Initialize new model
            ret = mySapModel.InitializeNewModel();
            _logger.Log("New model initialized");

            // Create steel deck template model
            // Parameters: NumStories, XDim, YDim, StoryHeight, XJoints, YJoints, DeckType
            ret = mySapModel.File.NewSteelDeck(3, 24, 24, 10, 4, 4, 24);
            if (ret == 0)
            {
                _logger.Log("Steel deck model created successfully");
            }
            else
            {
                _logger.LogWarning($"NewSteelDeck returned: {ret}");
            }

            // Save model
            ret = mySapModel.File.Save(ModelPath);
            if (ret == 0)
            {
                _logger.Log($"Steel deck model saved successfully to: {ModelPath}");
            }
            else
            {
                _logger.LogWarning($"Save returned status: {ret}");
            }
        }
        catch (Exception ex)
        {
            _logger.LogError("Error creating steel deck model", ex);
        }
        finally
        {
            if (myETABSObject != null)
            {
                try
                {
                    myETABSObject.ApplicationExit(false);
                    System.Runtime.InteropServices.Marshal.ReleaseComObject(myETABSObject);
                    _logger.Log("ETABS object released successfully");
                }
                catch (Exception ex)
                {
                    _logger.LogWarning("Error releasing ETABS object", ex);
                }
            }
        }
    }
}
