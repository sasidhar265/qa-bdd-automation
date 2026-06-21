using NUnit.Framework;
using Reqnroll;
using RestSharp;

namespace Tests.StepDefinitions;

[Binding]
public class ApiSteps
{
    private const string BaseApiUrl = "https://jsonplaceholder.typicode.com";
    private RestResponse? _response;

    [Given("I send GET request to {string}")]
    public void GivenISendGetRequestTo(string endpoint)
    {
        var client = new RestClient(BaseApiUrl);
        var request = new RestRequest(endpoint);

        _response = client.Execute(request);
    }

    [Then("response status should be {int}")]
    public void ThenResponseStatusShouldBe(int expectedStatusCode)
    {
        Assert.That(_response, Is.Not.Null, "API response was not created before verifying the status code.");
        Assert.That((int)_response!.StatusCode, Is.EqualTo(expectedStatusCode));
    }
}
