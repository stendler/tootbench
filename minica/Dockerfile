FROM golang:1.17-alpine as installer

RUN go install github.com/jsha/minica@latest

# could also be FROM scratch but alpine allows for debugging and is there anyway as the base of the builder above
FROM alpine

ENTRYPOINT ["minica"]
CMD ["--help"]

VOLUME /cert
WORKDIR /cert
RUN adduser -S -h /cert minica && chown -R minica /cert

USER minica
COPY --from=installer /go/bin/minica /bin/minica
