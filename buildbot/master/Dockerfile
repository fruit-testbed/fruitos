FROM alpine

ENV WORKER_PASSWORD pass
ENV TOTAL_WORKERS 2

WORKDIR /root

RUN apk update && apk upgrade
RUN apk add python3 python3-dev build-base
RUN pip3 install --upgrade pip
RUN pip3 install buildbot[bundle]
RUN buildbot create-master master

COPY master.cfg /root/master/master.cfg

EXPOSE 8010/tcp

CMD ["/usr/bin/buildbot", "start", "--nodaemon", "master"]
