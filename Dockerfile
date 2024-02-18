FROM alpine:latest as build

ARG SOURCE_PATH=src/api/

ARG DOWNLOAD_FILENAME=redbean-tiny-2.2.com

RUN apk add --update zip

RUN wget https://redbean.dev/${DOWNLOAD_FILENAME} -O redbean.com
RUN chmod +x redbean.com
RUN sh ./redbean.com --assimilate

COPY src/common/ src/
COPY ${SOURCE_PATH} src/
RUN cd src/ && zip ../redbean.com -r .

RUN unzip -l redbean.com

#####

FROM scratch
COPY --from=build /redbean.com /
ENTRYPOINT ["/redbean.com"]
