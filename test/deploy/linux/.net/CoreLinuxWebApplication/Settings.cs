namespace CoreLinuxWebApplication
{
    public class Settings
    {
        public string Port { get; set; }
        public string Name { get; set; }

        public string GetName(string defaultName = null)
        {
            if (string.IsNullOrWhiteSpace(Name))
            {
                if (string.IsNullOrWhiteSpace(defaultName))
                {
                    return GetType().Assembly.GetName().Name;
                }
                return defaultName;
            }
            return Name;
        }

        public int GetPort(int defaultPort = 80)
        {
            int result;
            if (int.TryParse(Port, out result))
            {
                return result;
            }
            return defaultPort;
        }

        public static Settings Load()
        {
            return JsonFileLoader.Load<Settings>(@"CoreLinuxWebApplication.json");
        }
    }
}
