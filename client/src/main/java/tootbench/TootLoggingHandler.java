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
    // status,message_len,username (sender),receive timestamp, server timestamp, username (receiver)
    log.trace("status,{},{}@{},{},{},{}",
      status.getContent().length(),
      Optional.ofNullable(status.getAccount()).map(Account::getUserName).orElse("null"),
      Optional.ofNullable(status.getAccount()).map(Account::getUrl).map(s -> s.split("/")[2]).orElse("null"), // the domain part after http://
      LocalDateTime.now(),
      status.getCreatedAt(),
      username
      );
  }

  public static void logPostResponse(LocalDateTime requestedOn, String username, Status status) {
    // post,message_len,username (sender),sent timestamp, server timestamp
    log.trace("post,{},{},{},{}",
      status.getContent().length(),
      username,
      requestedOn,
      status.getCreatedAt());
  }
}
