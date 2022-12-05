FROM golang:1.17-alpine as builder

RUN go install github.com/jsha/minica@latest

FROM alpine

ENTRYPOINT ["minica"]
CMD ["--help"]

VOLUME /cert
WORKDIR /cert
RUN adduser -S -h /cert minica && chown -R minica /cert

USER minica
COPY --from=builder /go/bin/minica /bin/minica
