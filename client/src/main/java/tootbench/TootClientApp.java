package tootbench;

import com.google.gson.Gson;
import com.sys1yagi.mastodon4j.MastodonClient;
import com.sys1yagi.mastodon4j.api.Scope;
import com.sys1yagi.mastodon4j.api.Shutdownable;
import com.sys1yagi.mastodon4j.api.entity.auth.AccessToken;
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
import java.security.KeyStore;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.security.cert.CertificateException;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.util.ArrayList;
import java.util.List;

@Slf4j
public class TootClientApp {

  public static final String CLIENT_NAME = "Tootbenchamun";

  private final String host;
  private final MastodonClient clientAnon;
  private final Apps apps;

  private final TootLoggingHandler userStreamHandler = new TootLoggingHandler();

  public TootClientApp(String host) {
    this.clientAnon = new MastodonClient.Builder(host, new OkHttpClient.Builder(), new Gson()).build();
    this.apps = new Apps(clientAnon);
    this.host = host;
  }


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

  public AppRegistration register(String clientName) {
    try {
      log.debug("registering...");
      var registration = apps.createApp(clientName, "urn:ietf:wg:oauth:2.0:oob", new Scope(Scope.Name.ALL)).execute();
      log.debug("app created: {} - {}", clientName, registration.getClientId());
      return registration;

    } catch (Mastodon4jRequestException e) {
      log.error("Could not connect.");
      throw new RuntimeException(e);
    }
  }

  public AccessToken login(AppRegistration app, String username, String password) throws Mastodon4jRequestException {
    try {
      return apps.postUserNameAndPassword(app.getClientId(), app.getClientSecret(), new Scope(Scope.Name.ALL), username, password).execute();
    } catch (Mastodon4jRequestException e) {
      log.error(e.getResponse().toString(), e);
      throw e;
    }
  }

  public User runUser(AppRegistration app, String username, String password) throws Mastodon4jRequestException {
    try {
      var token = login(app, username, password);
      log.info("User {} logged in", username);
      var userReceiver = new MastodonClient.Builder(host, new OkHttpClient.Builder(), new Gson())
        .accessToken(token.getAccessToken())
        .useStreamingApi().build();

      log.info("create stream");
      var userStream = new Streaming(userReceiver);
      log.info("start streaming");
      var shutdownable = userStream.federatedPublic(userStreamHandler);

      var userSender = new MastodonClient.Builder(host, new OkHttpClient.Builder(), new Gson())
        .accessToken(token.getAccessToken()).build();

      return new User(shutdownable, userSender);
    } catch (Mastodon4jRequestException e) {
      log.error("Failed to create user {}", username);
      throw e;
    }
  }

  public static void main(String[] args) throws Mastodon4jRequestException, InterruptedException {

    addCertificate();

    var host = "localhost";

    var toot = new TootClientApp(host);
    var app = toot.register(CLIENT_NAME);

    // todo do we need a registered client app per user? is the rate limit per user or per client or per ip?

    List<Shutdownable> toBeGracefullyShutdowned = new ArrayList<>();

    var username = "user1@localhost";
    var user1 = toot.runUser(app, username, "2e6bbb94173971027c4207af64e061c6");
    toBeGracefullyShutdowned.add(user1.feedStream);

    var user2 = toot.runUser(app, "user2@localhost", "91c989c55a3d5e3163d6495c264c78c2");
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

}
