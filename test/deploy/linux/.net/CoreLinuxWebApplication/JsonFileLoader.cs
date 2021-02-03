using System.IO;
using System;

using System.Text.Json;

namespace CoreLinuxWebApplication
{
    public class JsonFileLoader
    {
        public static T Load<T>(string filename) where T : class
        {
            var file = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "", filename);
            return JsonSerializer.Deserialize<T>(File.ReadAllText(file));
        }
    }
}
