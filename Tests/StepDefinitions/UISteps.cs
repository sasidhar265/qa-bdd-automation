using NUnit.Framework;
using OpenQA.Selenium;
using OpenQA.Selenium.Chrome;
using Reqnroll;

namespace Tests.StepDefinitions;

[Binding]
public class UISteps
{
    public const string WebDriverContextKey = "WebDriver";
    private const string TestSiteUrl = "https://example.cypress.io/";
    private readonly ScenarioContext _scenarioContext;
    private IWebDriver? _driver;

    public UISteps(ScenarioContext scenarioContext)
    {
        _scenarioContext = scenarioContext;
    }

    [Given("I open the test site")]
    public void GivenIOpenTheTestSite()
    {
        var chromeOptions = CreateChromeOptions();
        var chromeDriverBinary = Environment.GetEnvironmentVariable("CHROMEDRIVER_BIN");
        var chromeDriverService = string.IsNullOrWhiteSpace(chromeDriverBinary)
            ? ChromeDriverService.CreateDefaultService()
            : ChromeDriverService.CreateDefaultService(Path.GetDirectoryName(chromeDriverBinary)!, Path.GetFileName(chromeDriverBinary));

        _driver = new ChromeDriver(chromeDriverService, chromeOptions);
        _scenarioContext[WebDriverContextKey] = _driver;
        _driver.Navigate().GoToUrl(TestSiteUrl);
    }

    [Then("The title should contain {string}")]
    public void ThenTheTitleShouldContain(string expectedTitle)
    {
        Assert.That(_driver, Is.Not.Null, "Browser was not started before verifying the page title.");
        Assert.That(_driver!.Title, Does.Contain(expectedTitle));
    }

    public static bool TryGetDriver(ScenarioContext scenarioContext, out IWebDriver driver)
    {
        if (scenarioContext.TryGetValue(WebDriverContextKey, out IWebDriver? storedDriver) && storedDriver != null)
        {
            driver = storedDriver;
            return true;
        }

        driver = null!;
        return false;
    }

    public static void RemoveDriver(ScenarioContext scenarioContext)
    {
        scenarioContext.Remove(WebDriverContextKey);
    }

    public void CloseBrowser()
    {
        _driver?.Quit();
        _driver = null;
    }

    private static ChromeOptions CreateChromeOptions()
    {
        var chromeOptions = new ChromeOptions();
        var chromeBinary = Environment.GetEnvironmentVariable("CHROME_BIN");

        if (!string.IsNullOrWhiteSpace(chromeBinary))
        {
            chromeOptions.BinaryLocation = chromeBinary;
        }

        if (string.Equals(Environment.GetEnvironmentVariable("CHROME_HEADLESS"), "true", StringComparison.OrdinalIgnoreCase))
        {
            chromeOptions.AddArguments("--headless=new", "--no-sandbox", "--disable-dev-shm-usage", "--window-size=1920,1080");
        }

        return chromeOptions;
    }
}
