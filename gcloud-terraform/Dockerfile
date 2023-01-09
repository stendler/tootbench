FROM google/cloud-sdk:412.0.0-alpine

WORKDIR /home/cloudsdk/

VOLUME /home/cloudsdk/.config
RUN chown -R cloudsdk /home/cloudsdk/.config

RUN apk update && apk add terraform rsync ansible

USER cloudsdk

ENTRYPOINT [ "terraform" ]
CMD [ "-version" ]
