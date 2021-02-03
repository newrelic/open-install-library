using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Hosting;

namespace CoreLinuxWebApplication
{
    public class Program
    {
        public static void Main(string[] args)
        {
            CreateHostBuilder(args).Build().Run();
        }

        public static IHostBuilder CreateHostBuilder(string[] args) =>
            Host.CreateDefaultBuilder(args)
                .ConfigureWebHostDefaults(webBuilder =>
                {
                    webBuilder.UseStartup<Startup>();
                    var port = Settings.Load().GetPort();
                    webBuilder.UseKestrel(options =>
                    {
                        options.Listen(System.Net.IPAddress.Any, port);
                    });
                });
    }
}
