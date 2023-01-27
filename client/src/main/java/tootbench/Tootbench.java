package tootbench;

import com.google.gson.Gson;
import com.sys1yagi.mastodon4j.MastodonClient;
import com.sys1yagi.mastodon4j.api.Scope;
import com.sys1yagi.mastodon4j.api.Shutdownable;
import com.sys1yagi.mastodon4j.api.entity.auth.AppRegistration;
import com.sys1yagi.mastodon4j.api.exception.Mastodon4jRequestException;
import com.sys1yagi.mastodon4j.api.method.Apps;
import com.sys1yagi.mastodon4j.api.method.Statuses;
import com.sys1yagi.mastodon4j.api.method.Streaming;
import lombok.extern.slf4j.Slf4j;
import okhttp3.OkHttpClient;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.stream.Stream;

import static java.util.concurrent.TimeUnit.MILLISECONDS;
import static java.util.concurrent.TimeUnit.SECONDS;

@Slf4j
public class Tootbench {

  public static final String CLIENT_NAME = "Tootbenchamun";
  private final String clientName;

  private final Map<String, RegisteredApp> hostAppClients = new HashMap<>();

  private final List<User> users = new ArrayList<>();

  private final ScheduledExecutorService threadPool = Executors.newScheduledThreadPool(2*Runtime.getRuntime().availableProcessors(), runnable -> { var t = new Thread(runnable, CLIENT_NAME); t.setDaemon(true); return t; });

  public Tootbench(String clientName) {
    this.clientName = clientName;

    Runtime.getRuntime().addShutdownHook(new Thread(this::shutdown));
  }

  public Tootbench() {
    this(CLIENT_NAME);
  }

  public RegisteredApp register(String host) {
    try {
      log.debug("registering client at {} ...", host);
      var apps = new Apps(new MastodonClient.Builder(host, new OkHttpClient.Builder(), new Gson()).build());
      var registration = apps.createApp(clientName, "urn:ietf:wg:oauth:2.0:oob", new Scope(Scope.Name.ALL)).execute();
      log.debug("app created: {} - {}", clientName, registration.getClientId());
      var ret = new RegisteredApp(apps, registration);
      hostAppClients.put(host, ret);
      return ret;

    } catch (Mastodon4jRequestException e) {
      log.error("Could not connect.");
      throw new RuntimeException(e);
    }
  }

  public void createUsersFromFile(Path userFile) throws IOException {
    String host = Files.lines(userFile).findFirst().orElseThrow().split(" ")[1].split("@")[1];
    hostAppClients.putIfAbsent(host, register(host)); // todo maybe create client per user --> move to loginUser
    log.debug("Logging in users of host {}", host);
    try (Stream<String> lines = Files.lines(userFile)) {
      lines.map(s -> s.split(" "))
        .filter(strings -> strings.length >= 3) // make sure the format is appropriate
        .forEach(strings -> loginUser(host, strings[1], strings[2]));
    }
  }

  public User loginUser(String host, String username, String password) {
    try {
      log.debug("Trying to login {} at {}", username, host);
      var client = hostAppClients.get(host);
      var token = client.appClient.postUserNameAndPassword(client.registration.getClientId(), client.registration.getClientSecret(), new Scope(Scope.Name.ALL), username, password).execute();
      log.debug("User {} logged into {}", username, host);
      var userReceiver = new MastodonClient.Builder(host, new OkHttpClient.Builder(), new Gson())
        .accessToken(token.getAccessToken())
        .useStreamingApi().build();

      log.trace("create stream");
      var userStream = new Streaming(userReceiver);
      log.trace("start streaming");
      //var shutdownable = userStream.federatedPublic(new TootLoggingHandler(username)); // todo is that the feed I want to check? do users even need to follow?
      //var shutdownable = userStream.localPublic(new TootLoggingHandler(username));
      var shutdownable = userStream.user(new TootLoggingHandler(username));
      // todo maybe userStream.user(handler) ? or maybe follow is not necessary if instances federate
      // todo only open one feed per host (at least for the federatedPublic one)

      var userSender = new MastodonClient.Builder(host, new OkHttpClient.Builder(), new Gson())
        .accessToken(token.getAccessToken()).build();

      var user = new User(shutdownable, userSender);
      users.add(user);
      return user;
    } catch (Mastodon4jRequestException e) {
      log.error("Failed to login and connect user {} at {}", username, host);
      throw new RuntimeException(e);
    } catch (NullPointerException e) {
      log.error("No app registered yet for host {}", host);
      throw new RuntimeException(e);
    }
  }

  Runnable post(Statuses user) {
    return () -> {
      try {
        TootLoggingHandler.logPostResponse(LocalDateTime.now(), user.postStatus("My cool status", null, null, false, null).execute());
      } catch (Mastodon4jRequestException e) {
        log.warn("User post error. The user may be rate limited?");
      }
    };
  }

  public void start() {
    List<Statuses> userStatus = users.stream().map(User::clientSender).map(Statuses::new).toList();
    log.info("Starting run loop");

    log.info("Cores: {}", Runtime.getRuntime().availableProcessors());
    for (Statuses user : userStatus) {
      threadPool.scheduleWithFixedDelay(post(user), 0, 1500, MILLISECONDS);
    }
  }

  public void shutdown() {
    log.info("shutting down...");
    try {
     if(!threadPool.awaitTermination(1, SECONDS)) {
       log.warn("Forcing poster shutdown...");
       threadPool.shutdownNow();
      }
    } catch (InterruptedException ignored) {}
    users.forEach(user -> user.feedStream.shutdown());
    log.info("done.");
  }

  public record UserCreds(String username, AppRegistration client, String token) {}
  public record User(Shutdownable feedStream, MastodonClient clientSender) {}
  public record RegisteredApp(Apps appClient, AppRegistration registration) {}

}
