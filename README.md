# Telegram Messenger MTProto zero-configuration proxy server

The [Telegram Messenger MTProto proxy](https://github.com/TelegramMessenger/MTProxy) is a zero-configuration container that automatically sets up a proxy server that speaks Telegram's native MTProto.

```
# update image
docker-compose pull mtproxy

# run
docker-compose up -d

# check logs
docker-compose logs -f --tail=30 mtproxy
```

Check [docker hub](https://hub.docker.com/r/telegrammessenger/proxy/) for reference.
