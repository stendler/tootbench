package tootbench;

import com.google.gson.Gson;
import com.sys1yagi.mastodon4j.MastodonClient;
import com.sys1yagi.mastodon4j.api.Scope;
import com.sys1yagi.mastodon4j.api.Shutdownable;
import com.sys1yagi.mastodon4j.api.entity.auth.AppRegistration;
import com.sys1yagi.mastodon4j.api.exception.Mastodon4jRequestException;
import com.sys1yagi.mastodon4j.api.method.Apps;
import com.sys1yagi.mastodon4j.api.method.Streaming;
import lombok.extern.slf4j.Slf4j;
import okhttp3.OkHttpClient;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Stream;

@Slf4j
public class Tootbench {

  public static final String CLIENT_NAME = "Tootbenchamun";
  private final String clientName;

  private final Map<String, RegisteredApp> hostAppClients = new HashMap<>();

  private final TootLoggingHandler userStreamHandler = new TootLoggingHandler();

  private final List<User> users = new ArrayList<>();

  public Tootbench(String clientName) {
    this.clientName = clientName;

    Runtime.getRuntime().addShutdownHook(new Thread(this::shutdown));
  }

  public Tootbench() {
    this(CLIENT_NAME);
  }

  public RegisteredApp register(String host) {
    try {
      log.debug("registering...");
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
    String host = userFile.getName(userFile.getNameCount() - 2).toString(); // should be the folder name
    hostAppClients.putIfAbsent(host, register(host)); // todo maybe create client per user --> move to loginUser
    log.debug("Logging in users of host {}", host);
    try (Stream<String> lines = Files.lines(userFile)) {
      lines.map(s -> s.split(" "))
        .filter(strings -> strings.length >= 3)
        .forEach(strings -> loginUser(host, strings[1], strings[2]));
    }
  }

  public User loginUser(String host, String username, String password) {
    try {
      var client = hostAppClients.get(host);
      var token = client.appClient.postUserNameAndPassword(client.registration.getClientId(), client.registration.getClientSecret(), new Scope(Scope.Name.ALL), username, password).execute();
      log.debug("User {} logged into {}", username, host);
      var userReceiver = new MastodonClient.Builder(host, new OkHttpClient.Builder(), new Gson())
        .accessToken(token.getAccessToken())
        .useStreamingApi().build();

      log.trace("create stream");
      var userStream = new Streaming(userReceiver);
      log.trace("start streaming");
      var shutdownable = userStream.federatedPublic(userStreamHandler); // todo is that the feed I want to check? do users even need to follow?
      // todo maybe userStream.user(handler) ? or maybe follow is not necessary if instances federate
      // todo only open one feed per host (at least for the federatedPublic one)

      var userSender = new MastodonClient.Builder(host, new OkHttpClient.Builder(), new Gson())
        .accessToken(token.getAccessToken()).build();

      var user = new User(shutdownable, userSender);
      users.add(user);
      return user;
    } catch (Mastodon4jRequestException e) {
      log.error("Failed to login and connect user {}", username);
      throw new RuntimeException(e);
    } catch (NullPointerException e) {
      log.error("No app registered yet for host {}", host);
      throw new RuntimeException(e);
    }
  }

  public void shutdown() {
    users.forEach(user -> user.feedStream.shutdown());
  }

  public record UserCreds(AppRegistration client, String token) {}
  public record User(Shutdownable feedStream, MastodonClient clientSender) {}
  public record RegisteredApp(Apps appClient, AppRegistration registration) {}

}
