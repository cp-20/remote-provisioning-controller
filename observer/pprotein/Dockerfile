FROM golang

RUN apt-get update && apt-get install -y graphviz npm git zip percona-toolkit

WORKDIR /app

RUN \
  wget https://github.com/tkuchiki/alp/releases/download/v1.0.21/alp_linux_amd64.zip -q -O /tmp/alp.zip && \
  unzip /tmp/alp.zip -d /tmp && \
  mv /tmp/alp /usr/local/bin

RUN \
  wget https://github.com/tkuchiki/slp/releases/download/v0.2.1/slp_linux_amd64.zip -q -O /tmp/slp.zip && \
  unzip /tmp/slp.zip -d /tmp && \
  mv /tmp/slp /usr/local/bin

RUN \
  wget https://github.com/kaz/pprotein/releases/download/v1.2.3/pprotein_1.2.3_linux_amd64.tar.gz -q -O /tmp/pprotein.tar.gz && \
  tar -zxvf /tmp/pprotein.tar.gz -C /tmp && \
  mv /tmp/pprotein /app/pprotein

ENTRYPOINT [ "./pprotein" ]
