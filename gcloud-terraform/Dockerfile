FROM google/cloud-sdk:412.0.0-alpine

WORKDIR /home/cloudsdk/

VOLUME /home/cloudsdk/.config
RUN chown -R cloudsdk /home/cloudsdk/.config

RUN apk update && apk add terraform rsync ansible make openssl docker-cli-compose ruby-dev ruby-bundler build-base libpq-dev libidn-dev icu-dev libzip-dev

USER cloudsdk

ENTRYPOINT [ "terraform" ]
CMD [ "-version" ]
