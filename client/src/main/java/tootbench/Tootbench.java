package tootbench;

import com.google.gson.Gson;
import com.sys1yagi.mastodon4j.MastodonClient;
import com.sys1yagi.mastodon4j.MastodonRequest;
import com.sys1yagi.mastodon4j.Parameter;
import com.sys1yagi.mastodon4j.api.Scope;
import com.sys1yagi.mastodon4j.api.Shutdownable;
import com.sys1yagi.mastodon4j.api.entity.Account;
import com.sys1yagi.mastodon4j.api.entity.auth.AppRegistration;
import com.sys1yagi.mastodon4j.api.exception.Mastodon4jRequestException;
import com.sys1yagi.mastodon4j.api.method.Accounts;
import com.sys1yagi.mastodon4j.api.method.Apps;
import com.sys1yagi.mastodon4j.api.method.Statuses;
import com.sys1yagi.mastodon4j.api.method.Streaming;
import lombok.extern.slf4j.Slf4j;
import okhttp3.OkHttpClient;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.stream.Collectors;
import java.util.stream.Stream;

import static java.util.concurrent.TimeUnit.MILLISECONDS;
import static java.util.concurrent.TimeUnit.SECONDS;

@Slf4j
public class Tootbench {

  public static final String CLIENT_NAME = "Tootbenchamun";
  private final String clientName;

  private final Map<String, RegisteredApp> hostAppClients = new HashMap<>();

  private final List<User> users = new ArrayList<>();

  private ScheduledExecutorService threadPool;

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

  public void createUsersFromFile(Path userFile) {
    final String host;
    try (Stream<String> lines = Files.lines(userFile)) {
      host = lines.findFirst().orElseThrow().split(" ")[1].split("@")[1];
    } catch (IOException e) {
      log.error("IO error on reading file {}", userFile);
      Runtime.getRuntime().exit(1);
      return;
    }
    hostAppClients.putIfAbsent(host, register(host)); // todo maybe create client per user --> move to loginUser. Does not seem to matter.
    log.debug("Logging in users of host {}", host);
    try (Stream<String> lines = Files.lines(userFile)) {
      lines.map(s -> s.split(" "))
        .filter(strings -> strings.length >= 3) // make sure the format is appropriate
        .forEach(strings -> loginUser(host, strings[1], strings[2]));
    } catch (IOException e) {
      log.error("IO error on reading file {}", userFile);
      Runtime.getRuntime().exit(1);
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

      var user = new User(shutdownable, userSender, username); // todo email may not be equal to user@host in the future (to speed up user creation)
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

  void makeEachUserFollowEachOther() {
    Map<String, List<User>> usersPerInstance = users.stream().collect(Collectors.groupingBy(user -> user.username.substring(user.username.indexOf("@"))));
    Duration followDuration = Duration.ofMinutes(2);
    Instant beforeFollows = Instant.now();
    try (ExecutorService followsPool = Executors.newCachedThreadPool()) {
      for (Map.Entry<String, List<User>> instanceUsers : usersPerInstance.entrySet()) {
        log.info("Starting follows of users on {}", instanceUsers.getKey());
        followsPool.submit(() -> {
          for (User user : instanceUsers.getValue()) {
            for (User followed : users) {
              user.follow(followed.username());
            }
          }
        });
      }
      followsPool.shutdown();
      var terminatedInTime = followsPool.awaitTermination(followDuration.getSeconds(), TimeUnit.SECONDS);
      log.info("Finished all follows. Sleeping now for the lefover duration until {}", beforeFollows.plus(followDuration));
      Instant afterFollows = Instant.now();
      Thread.sleep(followDuration.minus(Duration.between(beforeFollows, afterFollows)));
      if (!terminatedInTime) {
        log.warn("Could not finish all follows in duration of {}s", followDuration.toSeconds());
      }
    } catch (InterruptedException e) {
      Runtime.getRuntime().exit(2);
    }
  }

  Runnable post(Statuses user, String username, Random messageRandomizer) {
    return () -> {
      try {
        byte[] bytes = new byte[100];
        messageRandomizer.nextBytes(bytes);
        String message = Base64.getEncoder().encodeToString(bytes);
        TootLoggingHandler.logPostResponse(LocalDateTime.now(), username, user.postStatus(message, null, null, false, null).execute());
      } catch (Mastodon4jRequestException e) {
        log.warn("User post error. The user may be rate limited?");
      }
    };
  }

  public void start() {
    log.info("Starting run loop");

    log.info("Cores: {}", Runtime.getRuntime().availableProcessors());

    // to mitigate that the load per instance does not decrease per total number of instances
    int instances = (int) users.stream().map(User::username).map(s -> s.substring(s.indexOf("@"))).distinct().count();
    log.info("Instances: {}", instances);
    int poolSize = 2*instances*Runtime.getRuntime().availableProcessors();
    log.info("Posting thread pool size: {}", poolSize);

    // should never occur, but just as a safety measure
    if (threadPool != null) {
      log.warn("There is already a threadpool running. Shutting it down before starting a new one.");
      threadPool.shutdownNow();
    }

    threadPool = Executors.newScheduledThreadPool(poolSize,
      runnable -> { var t = new Thread(runnable, CLIENT_NAME); t.setDaemon(true); return t; });

    Duration postIntervall = Duration.ofMillis(5500);
    Random initialJitter = new Random(5318008);
    Random messageRandomizer = new Random(5318008);

    for (User user : users) {
      threadPool.scheduleWithFixedDelay(post(new Statuses(user.clientSender), user.username, messageRandomizer), initialJitter.nextLong(postIntervall.toMillis()), postIntervall.toMillis(), MILLISECONDS);
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
  public record User(Shutdownable feedStream, MastodonClient clientSender, String username) {

    public void follow(String remoteUser) {
      if (username.equals(remoteUser)) {
        return;
      }

      try {
        // search for remote username to let the server webfinger and then retrieve the local id
        // https GET https://debug-0.europe-west1-b.c.cloud-service-benchmarking-22.internal/api/v1/accounts/search "q==user7@debug-1.europe-west1-b.c.cloud-service-benchmarking-22.internal" "resolve==true" "Authorization:Bearer 13FnXRtu9pHyxfBWRAXvm78IuC_44SnvY5J5ARXUjvY"
        log.debug("Searching for account {}", remoteUser);
        long id = new MastodonRequest<List<Account>>(() -> clientSender.get("accounts/search",
          new Parameter()
            .append("q", remoteUser)
            .append("resolve", true)), // trigger webfinger if user is unknown on home instance
          s -> clientSender.getSerializer().fromJson(s, Account.class)
        ).execute().get(0).getId();
        // follow
        // https POST https://debug-0.europe-west1-b.c.cloud-service-benchmarking-22.internal/api/v1/accounts/109796052517514405/follow "Authorization:Bearer 13FnXRtu9pHyxfBWRAXvm78IuC_44SnvY5J5ARXUjvY"
        log.debug("User {} tries to follow {} {}", username, id, remoteUser);
        new Accounts(clientSender).postFollow(id).execute();
      } catch (Mastodon4jRequestException e) {
        if (e.getResponse() != null) {
          log.error(" {} - {} ", e.getResponse().code(), e.getResponse().message());
          log.error("Ratelimit {} / {}. Reset in {}",
            e.getResponse().header("X-RateLimit-Remaining"),
            e.getResponse().header("X-RateLimit-Limit"),
            e.getResponse().header("X-RateLimit-Reset")
          );
          e.getResponse().close();
        }
        throw new RuntimeException(e);
      }
    }

  }
  public record RegisteredApp(Apps appClient, AppRegistration registration) {}

}
