package tootbench;

import com.sys1yagi.mastodon4j.api.Shutdownable;
import com.sys1yagi.mastodon4j.api.exception.Mastodon4jRequestException;
import com.sys1yagi.mastodon4j.api.method.Statuses;
import lombok.extern.slf4j.Slf4j;

import java.io.File;
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
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;


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
    var app = toot.register(host);

    List<Shutdownable> toBeGracefullyShutdowned = new ArrayList<>();

    var username = "user1@localhost";
    var user1 = toot.loginUser(host, username, "2e6bbb94173971027c4207af64e061c6");
    toBeGracefullyShutdowned.add(user1.feedStream());

    var user2 = toot.loginUser(host, "user2@localhost", "91c989c55a3d5e3163d6495c264c78c2");

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
  public static void login(Tootbench client) {
    // find files/Path[s] to createUsers from
    var dir = new File("users");
    try (var dirs = Files.newDirectoryStream(dir.toPath())) {
      for (Path hostDir : dirs) {
        try (var users = Files.newDirectoryStream(hostDir)) {
          if (users != null) {
            users.forEach(userFile -> {
              if (userFile.getFileName().toString().equals("users.txt")) {
                try {
                  client.createUsersFromFile(userFile);
                } catch (IOException e) {
                  log.warn("IO error on reading file {}", userFile);
                }
              }
            });
          }
        }
      }
    } catch (IOException e) {
      throw new UncheckedIOException(e);
    }
    // todo safe user token, and registered client id and secret to file
  }

  public static void main(String[] args) {

    addCertificate();

    if (args.length > 0) {
      var tootbench = new Tootbench();
      switch (args[0]) {
        case "--run" -> {
          login(tootbench);
          tootbench.start();
          log.info("Started");
          try {
            Thread.sleep(Duration.ofSeconds(10)); // todo make duration configurable
            log.info("Sleeping done");
          } catch (InterruptedException e) {
            log.info("Sleeping cancelled");
            tootbench.shutdown();
          }
        }
        case "--login" -> login(tootbench);
        default -> {
          log.error("Unknown parameters.");
          System.exit(1);
        }
      }

    } else {
      test();
    }

  }
}
