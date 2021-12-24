FROM golang:latest

RUN go get -u github.com/cosmtrek/air

WORKDIR /go/src
CMD ["air", "-c", ".air.toml"]
