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
            Thread.sleep(Duration.ofSeconds(10)); // todo make duration configurable - seems to not stop after main thread exit currently anyway
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
      log.error("Missing command: --run or --login");
      System.exit(1);
    }

  }
}
