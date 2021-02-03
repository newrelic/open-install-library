using Microsoft.AspNetCore.Mvc;

namespace CoreLinuxWebApplication.Controllers
{
    [ApiController]
    [Route("")]
    public class DefaultController : ControllerBase
    {
        [HttpGet]
        public ContentResult Get()
        {
            var settings = Settings.Load();
            var content = @"
<!DOCTYPE html>
<html lang=""en"">
<head>
    <meta charset=""utf-8"" />
      <title>" +settings.GetName() + @"</title>
</head>
<body>
  <div style=""text-align: center"">
    <h1>Welcome to " + settings.GetName() + @"</h1>
    <br/>
    <p>Get the local <a href=""/weatherforecast"">weather forecast</a></p>
    <p>
  </div>
</body>
</html>";

            return new ContentResult
            {
                ContentType = "text/html",
                StatusCode = 200,
                Content = content
            };

        }
    }
}
