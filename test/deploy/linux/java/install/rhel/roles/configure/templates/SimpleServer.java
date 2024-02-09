
//import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.net.ServerSocket;
import java.util.Date;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import org.apache.catalina.core.StandardContext;
import org.apache.catalina.startup.Tomcat;
import org.apache.commons.text.RandomStringGenerator;

public class SimpleServer {

  public static void main(String[] args) throws Exception {
    // Run client in a separate thread
    ExecutorService executor = Executors.newSingleThreadExecutor();
    executor.submit(new SimpleClient());

    // Start Tomcat server
    Tomcat tomcat = new Tomcat();
    tomcat.setPort(8080); // Adjust port if needed

    StandardContext ctx = new StandardContext();
    ctx.setPath("/");
    tomcat.addContext(ctx);

    // Health endpoint
    ctx.addServlet("healthServlet", "health", new SimpleServlet("health"));

    // Data endpoint
    ctx.addServlet("dataServlet", "data", new SimpleServlet("data"));

    tomcat.start();
    tomcat.getServer().await();
  }

  private static class SimpleServlet extends javax.servlet.http.HttpServlet {

    private final String message;

    public SimpleServlet(String message) { this.message = message; }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
        throws IOException {
      resp.setContentType("application/json");

      if ("health".equals(message)) {
        resp.getWriter().write(String.format(
            "{\"status\": \"healthy\", \"time\": \"%s\"}", new Date()));
      } else if ("data".equals(message)) {
        resp.getWriter().write(
            String.format("{\"message\": \"%s\"}", generateLoremIpsum()));
      }
    }

    private String generateLoremIpsum() {
      // Use an appropriate library for real-world scenarios
      return new RandomStringGenerator().generateLettersWithSpaces(100);
    }
  }
}
