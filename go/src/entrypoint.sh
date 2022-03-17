#!/bin/sh
cd /go/src
go get -u github.com/kettek/apng
go get -u github.com/pixiv/go-libjpeg/jpeg
air -c .air.toml
