package tootbench;

import com.sys1yagi.mastodon4j.api.Handler;
import com.sys1yagi.mastodon4j.api.entity.Account;
import com.sys1yagi.mastodon4j.api.entity.Notification;
import com.sys1yagi.mastodon4j.api.entity.Status;
import lombok.extern.slf4j.Slf4j;
import org.jetbrains.annotations.NotNull;

import java.util.Optional;

@Slf4j
public class TootLoggingHandler implements Handler {

  @Override
  public void onDelete(long l) {
    log.debug("Delete? {}", l);
  }

  @Override
  public void onNotification(@NotNull Notification notification) {
    log.info("Notification\t{}\t{}\t{}\t{}",
      Optional.ofNullable(notification.getAccount()).map(Account::getDisplayName).orElse("null"),
      notification.getCreatedAt(),
      Optional.ofNullable(notification.getStatus()).map(Status::getAccount).map(Account::getAcct).orElse("null"),
      Optional.ofNullable(notification.getStatus()).map(Status::getCreatedAt).orElse("null")
    );
  }

  @Override
  public void onStatus(@NotNull Status status) {
    log.info("Toot\t{}\t{}",
      Optional.ofNullable(status.getAccount()).map(Account::getAcct).orElse("null"),
      status.getCreatedAt()
    );
  }
}
