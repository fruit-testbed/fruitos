#!/bin/sh

buildbot-worker create-worker worker $MASTER_ADDRESS $WORKER_NAME $WORKER_PASSWORD
buildbot-worker start --nodaemon worker
