FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update
RUN apt-get -yqq install git lsb-release sudo vim gnupg openjdk-11-jdk verilator curl make gcc g++ python3-pip

RUN echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" | tee /etc/apt/sources.list.d/sbt.list
RUN echo "deb https://repo.scala-sbt.org/scalasbt/debian /" | tee /etc/apt/sources.list.d/sbt_old.list
RUN curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | apt-key add
RUN apt-get update
RUN apt-get -yqq install sbt

WORKDIR /spinalcrypto
COPY SpinalCrypto .
RUN sbt publishLocal

WORKDIR /proteus
COPY ProteusCore .
RUN make -C sim CORE=riscv.plugins.cheri.CoreExtMem

CMD /bin/bash
