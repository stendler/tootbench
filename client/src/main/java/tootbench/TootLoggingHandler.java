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
  public void onDelete(long l) { }

  @Override
  public void onNotification(@NotNull Notification notification) { }

  @Override
  public void onStatus(@NotNull Status status) {
    // status,username (sender),receive timestamp, server timestamp, username (receiver),url,uri,acct,account_url
    log.trace("status,{},{},{},{},{},{},{},{}",
      Optional.ofNullable(status.getAccount()).map(Account::getUserName).orElse("null"),
      LocalDateTime.now(),
      status.getCreatedAt(),
      username,
      status.getUrl(),
      status.getUri(),
      status.getAccount().getAcct(),
      status.getAccount().getUrl()
      );
  }

  public static void logPostResponse(LocalDateTime requestedOn, String username, Status status) {
    // post,username (sender),sent timestamp, server timestamp
    log.trace("post,{},{},{}",
      username,
      requestedOn,
      status.getCreatedAt());
  }
}
