using System.Diagnostics;
using System.Text;
using Allure.Net.Commons;
using NUnit.Framework;
using OpenQA.Selenium;
using Reqnroll;
using Tests.StepDefinitions;

namespace Tests.Hooks;

[Binding]
public class AllureHooks
{
    private const string ResultsDirectory = "allure-results";
    private const string ReportDirectory = "allure-report";
    private static readonly string ProjectDirectory = GetProjectDirectory();
    private static readonly string ReportPath = Path.Combine(ProjectDirectory, ReportDirectory);
    private static readonly string TestOutputResultsPath = Path.Combine(TestContext.CurrentContext.TestDirectory, ResultsDirectory);
    private readonly ScenarioContext _scenarioContext;

    public AllureHooks(ScenarioContext scenarioContext)
    {
        _scenarioContext = scenarioContext;
    }

    [BeforeTestRun]
    public static void BeforeTestRun()
    {
        RecreateDirectory(TestOutputResultsPath);
        Environment.SetEnvironmentVariable("ALLURE_RESULTS_DIRECTORY", TestOutputResultsPath);
    }

    [AfterStep]
    public void AttachFailureDetailsAfterStep()
    {
        if (_scenarioContext.TestError == null)
        {
            return;
        }

        AttachFailureDetails("Failed step");
    }

    [AfterScenario]
    public void AttachFailureDetailsAfterScenario()
    {
        if (_scenarioContext.TestError != null)
        {
            AttachFailureDetails("Failed scenario");
        }
    }

    [AfterScenario]
    public void CloseBrowser()
    {
        if (!UISteps.TryGetDriver(_scenarioContext, out var driver))
        {
            return;
        }

        driver.Quit();
        UISteps.RemoveDriver(_scenarioContext);
    }

    [AfterTestRun]
    public static void AfterTestRun()
    {
        GenerateHtmlReport();
    }

    private void AttachFailureDetails(string attachmentPrefix)
    {
        var error = _scenarioContext.TestError;
        if (error == null)
        {
            return;
        }

        var failureDetails = $"{error.GetType().FullName}{Environment.NewLine}{error.Message}{Environment.NewLine}{error.StackTrace}";
        AllureApi.AddAttachment($"{attachmentPrefix} error", "text/plain", Encoding.UTF8.GetBytes(failureDetails));

        if (UISteps.TryGetDriver(_scenarioContext, out var driver))
        {
            AttachScreenshot(driver, attachmentPrefix);
        }
    }

    private static void AttachScreenshot(IWebDriver driver, string attachmentPrefix)
    {
        if (driver is not ITakesScreenshot screenshotDriver)
        {
            return;
        }

        var screenshot = screenshotDriver.GetScreenshot();
        var screenshotBytes = screenshot.AsByteArray;

        AllureApi.AddAttachment($"{attachmentPrefix} screenshot", "image/png", screenshotBytes, "png");

        var screenshotPath = Path.Combine(TestOutputResultsPath, $"{SanitizeFileName(attachmentPrefix)}-screenshot.png");
        File.WriteAllBytes(screenshotPath, screenshotBytes);
        TestContext.AddTestAttachment(screenshotPath, $"{attachmentPrefix} screenshot");
    }

    private static void GenerateHtmlReport()
    {
        if (!Directory.Exists(TestOutputResultsPath))
        {
            Console.WriteLine($"Allure results directory was not found: {TestOutputResultsPath}");
            return;
        }

        var process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = "allure",
                Arguments = $"generate \"{TestOutputResultsPath}\" --clean --single-file -o \"{ReportPath}\"",
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false
            }
        };

        try
        {
            process.Start();
            var output = process.StandardOutput.ReadToEnd();
            var error = process.StandardError.ReadToEnd();
            process.WaitForExit();

            if (!string.IsNullOrWhiteSpace(output))
            {
                Console.WriteLine(output);
            }

            if (process.ExitCode != 0)
            {
                Console.Error.WriteLine($"Allure report generation failed with exit code {process.ExitCode}.");
                Console.Error.WriteLine(error);
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Allure report generation was skipped: {ex.Message}");
        }
    }

    private static string GetProjectDirectory()
    {
        var directory = new DirectoryInfo(TestContext.CurrentContext.TestDirectory);

        while (directory != null && !File.Exists(Path.Combine(directory.FullName, "Tests.csproj")))
        {
            directory = directory.Parent;
        }

        return directory?.FullName ?? TestContext.CurrentContext.WorkDirectory;
    }

    private static void RecreateDirectory(string directory)
    {
        if (Directory.Exists(directory))
        {
            Directory.Delete(directory, true);
        }

        Directory.CreateDirectory(directory);
    }

    private static string SanitizeFileName(string value)
    {
        foreach (var invalidCharacter in Path.GetInvalidFileNameChars())
        {
            value = value.Replace(invalidCharacter, '-');
        }

        return value.Replace(' ', '-').ToLowerInvariant();
    }
}
