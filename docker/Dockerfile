FROM lambci/lambda:build-nodejs8.10 

COPY . /task

RUN cd /task && \
  ls -la && \
  npm i --production -q --no-audit --no-save 

ENTRYPOINT /bin/bash

