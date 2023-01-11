package tootbench;

import com.sys1yagi.mastodon4j.api.Handler;
import com.sys1yagi.mastodon4j.api.entity.Account;
import com.sys1yagi.mastodon4j.api.entity.Notification;
import com.sys1yagi.mastodon4j.api.entity.Status;
import lombok.extern.slf4j.Slf4j;
import org.jetbrains.annotations.NotNull;

import java.time.LocalDateTime;
import java.util.Optional;

@Slf4j
public class TootLoggingHandler implements Handler {

  private final String username;

  TootLoggingHandler(String username) {
    this.username = username;
  }

  @Override
  public void onDelete(long l) {
    log.trace("Delete? {}", l);
  }

  @Override
  public void onNotification(@NotNull Notification notification) {
    log.trace("Notification\t{}\t{}\t{}\t{}",
      Optional.ofNullable(notification.getAccount()).map(Account::getDisplayName).orElse("null"),
      notification.getCreatedAt(),
      Optional.ofNullable(notification.getStatus()).map(Status::getAccount).map(Account::getAcct).orElse("null"),
      Optional.ofNullable(notification.getStatus()).map(Status::getCreatedAt).orElse("null")
    );
  }

  @Override
  public void onStatus(@NotNull Status status) {
    log.trace("{} received Toot\tfrom {}\t{}",
      username,
      Optional.ofNullable(status.getAccount()).map(Account::getAcct).orElse("null"),
      status.getCreatedAt()
    );
  }

  public static void logPostResponse(LocalDateTime requestedOn, Status status) {
    log.trace("{} tooted on {} and server created on {}",
      Optional.ofNullable(status.getAccount()).map(Account::getAcct).orElse("null"),
      requestedOn,
      status.getCreatedAt());
  }
}
