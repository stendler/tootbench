package tootbench;

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
import java.time.Instant;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;


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

  public static void login(Tootbench client) {
    Duration loginDuration = Duration.ofSeconds(20);
    Instant beforeLogin = Instant.now();
    try (ExecutorService loginPool = Executors.newCachedThreadPool()) {

      // find files/Path[s] to createUsers from
      var dir = new File("users");
      try (var dirs = Files.newDirectoryStream(dir.toPath())) {
        for (Path hostDir : dirs) {
          try (var users = Files.newDirectoryStream(hostDir)) {
            if (users != null) {
              users.forEach(userFile -> {
                if (userFile.getFileName().toString().equals("users.txt")) {
                  loginPool.submit(() -> client.createUsersFromFile(userFile));
                }
              });
            }
          }
        }
      } catch (IOException e) {
        throw new UncheckedIOException(e);
      }
      // todo safe user token, and registered client id and secret to file
      loginPool.shutdown();
      var terminatedInTime = loginPool.awaitTermination(loginDuration.getSeconds(), TimeUnit.SECONDS);
      log.info("Finished all logins. Sleeping now for the leftover duration until {}", beforeLogin.plus(loginDuration));
      Instant afterLogin = Instant.now();
      Thread.sleep(loginDuration.minus(Duration.between(beforeLogin, afterLogin)));
      if (!terminatedInTime) {
        log.warn("Could not finish all logins in duration of {}s",loginDuration.toSeconds());
      }
    } catch (InterruptedException e) {
      Runtime.getRuntime().exit(2);
    }
  }

  public static void main(String[] args) {

    addCertificate();

    if (args.length > 0) {
      var tootbench = new Tootbench();
      switch (args[0]) {
        case "--run" -> {
          try {
            log.info("Start logins");
            login(tootbench);
            Thread.sleep(Duration.ofSeconds(10));
            log.info("Start follows");
            tootbench.makeEachUserFollowEachOther();
            Thread.sleep(Duration.ofSeconds(10));
            log.info("Starting benchmark");
            tootbench.start();
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
