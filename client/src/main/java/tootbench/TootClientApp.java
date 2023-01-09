package tootbench;

import com.google.gson.Gson;
import com.sys1yagi.mastodon4j.MastodonClient;
import com.sys1yagi.mastodon4j.api.Scope;
import com.sys1yagi.mastodon4j.api.Shutdownable;
import com.sys1yagi.mastodon4j.api.entity.auth.AppRegistration;
import com.sys1yagi.mastodon4j.api.exception.Mastodon4jRequestException;
import com.sys1yagi.mastodon4j.api.method.Apps;
import com.sys1yagi.mastodon4j.api.method.Follows;
import com.sys1yagi.mastodon4j.api.method.Statuses;
import com.sys1yagi.mastodon4j.api.method.Streaming;
import lombok.extern.slf4j.Slf4j;
import okhttp3.OkHttpClient;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyStore;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.security.cert.CertificateException;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Stream;

@Slf4j
public class TootClientApp {

  public static final String CLIENT_NAME = "Tootbenchamun";

  private final Map<String, RegisteredApp> hostAppClients = new HashMap<>();

  private final TootLoggingHandler userStreamHandler = new TootLoggingHandler();

  private final List<User> users = new ArrayList<>();


  public static void addCertificate() {
    try (var certFile = TootClientApp.class.getClassLoader().getResourceAsStream("minica.der")) {
      var cert = (X509Certificate) CertificateFactory.getInstance("X.509").generateCertificate(certFile);
      var keystore = KeyStore.getInstance(KeyStore.getDefaultType());
      keystore.load(new FileInputStream(System.getProperty("java.home") + "/lib/security/cacerts"), "changeit".toCharArray());
      keystore.setCertificateEntry("minica", cert);
      log.info("added cert");
    } catch (IOException e) {
      throw new UncheckedIOException(e);
    } catch (CertificateException | KeyStoreException | NoSuchAlgorithmException e) {
      throw new RuntimeException(e);
    }
  }

  public RegisteredApp register(String host, String clientName) {
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
    String host = userFile.getFileName().toString().split("\\.")[0];
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
      log.debug("User {} logged in", username);
      var userReceiver = new MastodonClient.Builder(host, new OkHttpClient.Builder(), new Gson())
        .accessToken(token.getAccessToken())
        .useStreamingApi().build();

      log.trace("create stream");
      var userStream = new Streaming(userReceiver);
      log.trace("start streaming");
      var shutdownable = userStream.federatedPublic(userStreamHandler); // todo is that the feed I want to check? do users even need to follow?
      // todo maybe userStream.user(handler) ? or maybe follow is not necessary if instances federate

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

  public static void main(String[] args) throws InterruptedException {

    addCertificate();

    var host = "localhost";

    var toot = new TootClientApp();
    var app = toot.register(host, CLIENT_NAME);

    List<Shutdownable> toBeGracefullyShutdowned = new ArrayList<>();

    var username = "user1@localhost";
    var user1 = toot.loginUser(host, username, "2e6bbb94173971027c4207af64e061c6");
    toBeGracefullyShutdowned.add(user1.feedStream);

    var user2 = toot.loginUser(host, "user2@localhost", "91c989c55a3d5e3163d6495c264c78c2");
    new Follows(user2.clientSender()).postRemoteFollow("user1@localhost");
    new Follows(user1.clientSender()).postRemoteFollow("user2@localhost");

    try {
      var userSender = new Statuses(user1.clientSender());
      log.info("start posting");
      int post = 400;
      for (int i = 0; i < post; i++) {
        var status = userSender.postStatus("my cool status " + i, null, null, false, null).execute();
        log.info("Posted status\t{}\t{}", status.getAccount().getAcct(), status.getCreatedAt());
      }

      Thread.sleep(100000L);
    } catch (Mastodon4jRequestException e) {
      log.error("Request error. Probably rate limit exceeded. Shutting down...");
      toBeGracefullyShutdowned.forEach(Shutdownable::shutdown);
      log.debug(e.getResponse().toString());
    }

    try {
      var userSender = new Statuses(user2.clientSender());
      var status = userSender.postStatus("my cool status xxx", null, null, false, null).execute();
      log.info("Posted status\t{}\t{}", status.getAccount().getAcct(), status.getCreatedAt());
    } catch (Mastodon4jRequestException e) {
      log.error("user 2 cannot post either...");
    }
  }

  public record User(Shutdownable feedStream, MastodonClient clientSender) {}
  public record RegisteredApp(Apps appClient, AppRegistration registration) {}

}
