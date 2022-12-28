FROM google/cloud-sdk:412.0.0-alpine

RUN apk update && apk add terraform

ENTRYPOINT ["/bin/bash", "-c", "chown -R cloudsdk /home/cloudsdk/.config && su -s /bin/bash cloudsdk"]
