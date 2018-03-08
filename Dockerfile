FROM alpine:edge AS mozjpeg
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
RUN apk add --no-cache alpine-sdk
RUN adduser -s /bin/sh -D -G abuild abuild
RUN echo "%abuild ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/abuild
USER abuild
RUN abuild-keygen -a -i -n -q

# Buildind mozjpeg and installing it
WORKDIR /tmp/mozjpeg
COPY --chown=abuild:abuild alpine/mozjpeg/APKBUILD ./
RUN sudo chown abuild:abuild ./ && abuild checksum
RUN abuild -r -i || abuild -r -i

# Building tiff and installing it
WORKDIR /tmp/tiff
COPY --chown=abuild:abuild alpine/tiff/* ./
RUN sudo chown abuild:abuild ./ && abuild checksum
RUN abuild -r -i || abuild -r -i

# Building lcms2 and installing it
WORKDIR /tmp/lcms2
COPY --chown=abuild:abuild alpine/lcms2/* ./
RUN sudo chown abuild:abuild ./ && abuild checksum
RUN abuild -r -i || abuild -r -i

# Building libvips
WORKDIR /tmp/vips
COPY --chown=abuild:abuild alpine/vips/APKBUILD ./
RUN sudo chown abuild:abuild ./ && abuild checksum
RUN abuild -r || abuild -r

# Building libimagequant
WORKDIR /tmp/libimagequant
COPY --chown=abuild:abuild alpine/libimagequant/APKBUILD ./
RUN sudo chown abuild:abuild ./ && abuild checksum
RUN abuild -r || abuild -r


# Building reImage
FROM alpine:edge AS go
WORKDIR /go/src/reImage
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
COPY --from=mozjpeg /home/abuild/packages/tmp/x86_64/*.apk /tmp/
RUN apk add --allow-untrusted /tmp/*.apk && apk add --no-cache go git fftw-dev musl-dev
ENV GOPATH /go
COPY *.go ./
RUN go get
RUN go build -o reImage *.go


# Create Release image without dev dependencies
FROM alpine:edge AS release
WORKDIR /usr/local/bin/
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
COPY --from=go /go/src/reImage/reImage .
COPY --from=mozjpeg /home/abuild/packages/tmp/x86_64/mozjpeg-3.2-r0.apk /tmp/
COPY --from=mozjpeg /home/abuild/packages/tmp/x86_64/vips-8.6.1-r0.apk /tmp/
COPY --from=mozjpeg /home/abuild/packages/tmp/x86_64/lcms2-2.8-r2.apk /tmp/
COPY --from=mozjpeg /home/abuild/packages/tmp/x86_64/tiff-4.0.9-r1.apk /tmp/
COPY --from=mozjpeg /home/abuild/packages/tmp/x86_64/libimagequant-2.11.10-r0.apk /tmp/
ENV CFG_LISTEN ":7075"
RUN apk add --allow-untrusted /tmp/*.apk && apk add --no-cache ca-certificates
CMD ["./reImage"]
