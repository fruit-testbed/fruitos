FROM arm32v6/alpine

ENV MASTER_ADDRESS localhost
ENV WORKER_NAME example-worker
ENV WORKER_PASSWORD pass

WORKDIR /root

RUN apk update && apk upgrade
RUN apk add python3 python3-dev build-base
RUN pip3 install --upgrade pip
RUN pip3 install buildbot-worker setuptools-trial

COPY worker.sh /usr/bin/worker.sh
RUN chmod +x /usr/bin/worker.sh

CMD ["/usr/bin/worker.sh"]
