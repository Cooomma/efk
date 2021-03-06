FROM ubuntu:16.04

###############################################################################
#                                INSTALLATION
###############################################################################

### install prerequisites (cURL, gosu, JDK)

ENV GOSU_VERSION 1.8

ARG DEBIAN_FRONTEND=noninteractive
RUN set -x \
 && apt-get update -qq \
 && apt-get install -qqy --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/* \
 && curl -L -o /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
 && curl -L -o /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
 && export GNUPGHOME="$(mktemp -d)" \
 && gpg --keyserver hkp://ha.pool.sks-keyservers.net:80 --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
 && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
 && rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
 && chmod +x /usr/local/bin/gosu \
 && gosu nobody true \
 && apt-get update -qq \
 && apt-get install -qqy openjdk-8-jdk \
 && apt-get install -y python3-pip \
 && apt-get clean \
 && set +x


### install FluentD
ENV FLUENTD_HOME /opt/td-agent

RUN mkdir ${FLUENTD_HOME} \
 && curl https://packages.treasuredata.com/GPG-KEY-td-agent | apt-key add - \
 && echo "deb http://packages.treasuredata.com/2/ubuntu/xenial/ xenial contrib" > /etc/apt/sources.list.d/treasure-data.list \
 && apt-get update \
 && apt-get install -y td-agent \
 && /etc/init.d/td-agent stop

ADD ./fluentd/td-agent.conf /etc/td-agent/td-agent.conf
RUN apt-get install make libcurl4-gnutls-dev --yes \
 && ${FLUENTD_HOME}/embedded/bin/fluent-gem install fluent-plugin-elasticsearch \
 && ${FLUENTD_HOME}/embedded/bin/fluent-gem install fluent-plugin-record-reformer \
 && groupadd -r fluentd -g 992 \
 && useradd -r -s /usr/sbin/nologin -M -c "fluentd service user" -u 992 -g fluentd fluentd \
 && mkdir -p /var/log/fluentd \
 && chown -R fluentd:fluentd ${FLUENTD_HOME} /var/log/fluentd \
 && /etc/init.d/td-agent start


ENV ELK_VERSION 5.4.0

### install Elasticsearch

ENV ES_VERSION ${ELK_VERSION}
ENV ES_HOME /opt/elasticsearch
ENV ES_PACKAGE elasticsearch-${ES_VERSION}.tar.gz
ENV ES_GID 991
ENV ES_UID 991

RUN mkdir ${ES_HOME} \
 && curl -O https://artifacts.elastic.co/downloads/elasticsearch/${ES_PACKAGE} \
 && tar xzf ${ES_PACKAGE} -C ${ES_HOME} --strip-components=1 \
 && rm -f ${ES_PACKAGE} \
 && groupadd -r elasticsearch -g ${ES_GID} \
 && useradd -r -s /usr/sbin/nologin -M -c "Elasticsearch service user" -u ${ES_UID} -g elasticsearch elasticsearch \
 && mkdir -p /var/log/elasticsearch /etc/elasticsearch /etc/elasticsearch/scripts /var/lib/elasticsearch \
 && chown -R elasticsearch:elasticsearch ${ES_HOME} /var/log/elasticsearch /var/lib/elasticsearch

ADD ./elasticsearch/elasticsearch-init /etc/init.d/elasticsearch
RUN sed -i -e 's#^ES_HOME=$#ES_HOME='$ES_HOME'#' /etc/init.d/elasticsearch \
 && chmod +x /etc/init.d/elasticsearch

### install Kibana

ENV KIBANA_VERSION ${ELK_VERSION}
ENV KIBANA_HOME /opt/kibana
ENV KIBANA_PACKAGE kibana-${KIBANA_VERSION}-linux-x86_64.tar.gz
ENV KIBANA_GID 993
ENV KIBANA_UID 993

RUN mkdir ${KIBANA_HOME} \
 && curl -O https://artifacts.elastic.co/downloads/kibana/${KIBANA_PACKAGE} \
 && tar xzf ${KIBANA_PACKAGE} -C ${KIBANA_HOME} --strip-components=1 \
 && rm -f ${KIBANA_PACKAGE} \
 && groupadd -r kibana -g ${KIBANA_GID} \
 && useradd -r -s /usr/sbin/nologin -d ${KIBANA_HOME} -c "Kibana service user" -u ${KIBANA_UID} -g kibana kibana \
 && mkdir -p /var/log/kibana \
 && chown -R kibana:kibana ${KIBANA_HOME} /var/log/kibana

ADD ./kibana/kibana-init /etc/init.d/kibana
RUN sed -i -e 's#^KIBANA_HOME=$#KIBANA_HOME='$KIBANA_HOME'#' /etc/init.d/kibana \
 && chmod +x /etc/init.d/kibana

###############################################################################
#                               CONFIGURATION
###############################################################################

######
### configure FluentD
######
ADD ./fluentd/td-agent.conf /opt/td-agent/etc/td-agent/td-agent.conf


######
### configure Elasticsearch
######

ADD ./elasticsearch/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml
ADD ./elasticsearch/elasticsearch-log4j2.properties /etc/elasticsearch/log4j2.properties
ADD ./elasticsearch/elasticsearch-jvm.options /etc/elasticsearch/jvm.options
ADD ./elasticsearch/elasticsearch-default /etc/default/elasticsearch
RUN chmod -R +r /etc/elasticsearch

######
### configure logrotate
######

ADD ./elasticsearch/elasticsearch-logrotate /etc/logrotate.d/elasticsearch
ADD ./kibana/kibana-logrotate /etc/logrotate.d/kibana
RUN chmod 644 /etc/logrotate.d/elasticsearch \
 && chmod 644 /etc/logrotate.d/kibana

######
### configure Kibana
######

ADD ./kibana/kibana.yml ${KIBANA_HOME}/config/kibana.yml

###############################################################################
#                                   START
###############################################################################

ADD ./start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

EXPOSE 5601 9200 9300 24230 9527
VOLUME /var/lib/elasticsearch

CMD [ "/usr/local/bin/start.sh" ]
