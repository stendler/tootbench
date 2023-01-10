package tootbench;

import com.sys1yagi.mastodon4j.api.Shutdownable;
import com.sys1yagi.mastodon4j.api.exception.Mastodon4jRequestException;
import com.sys1yagi.mastodon4j.api.method.Follows;
import com.sys1yagi.mastodon4j.api.method.Statuses;
import lombok.extern.slf4j.Slf4j;

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
import java.util.Arrays;
import java.util.List;

import static tootbench.Tootbench.CLIENT_NAME;

@Slf4j
public class TootbenchApp {

  public static void addCertificate() {
    try (var certFile = Tootbench.class.getClassLoader().getResourceAsStream("minica.der")) {
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

  public static void test() {
    var host = "mstdn-single-instance";

    var toot = new Tootbench();
    var app = toot.register(host, CLIENT_NAME);

    List<Shutdownable> toBeGracefullyShutdowned = new ArrayList<>();

    var username = "user1@localhost";
    var user1 = toot.loginUser(host, username, "2e6bbb94173971027c4207af64e061c6");
    toBeGracefullyShutdowned.add(user1.feedStream());

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
    } catch (InterruptedException e) {
      log.error("Sending interrupted.");
    }

    try {
      var userSender = new Statuses(user2.clientSender());
      var status = userSender.postStatus("my cool status xxx", null, null, false, null).execute();
      log.info("Posted status\t{}\t{}", status.getAccount().getAcct(), status.getCreatedAt());
    } catch (Mastodon4jRequestException e) {
      log.error("user 2 cannot post either...");
    }
  }

  /**
   * todo Log users in and safe tokens and client id & secret to file
   */
  public static void login() {
    throw new UnsupportedOperationException("Not yet implemented");
  }

  public static void run() {

  }

  public static void main(String[] args) {

    addCertificate();

    var argBuffer = new StringBuilder();
    Arrays.stream(args).forEach(arg -> argBuffer.append(arg).append(" "));
    switch (argBuffer.toString()) {
      case String s when s.contains("--run") -> run();
      case String s when s.contains("--login") -> login();
      case default -> test();
    }

  }
}
