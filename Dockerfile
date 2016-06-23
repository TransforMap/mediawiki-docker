FROM debian:sid
MAINTAINER Gabriel Wicke <gwicke@wikimedia.org>

# XXX: Consider switching to nginx.
RUN set -x; \
    apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        apache2 \
        libapache2-mod-php5 \
        php5-mysql \
        php5-cli \
        php5-gd \
        php5-curl \
        imagemagick \
        netcat \
        git \
        curl \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/archives/* \
    && a2enmod rewrite \
    && a2enmod proxy \
    && a2enmod proxy_http \
    # Remove the default Debian index page.
    && rm /var/www/html/index.html

# Waiting in antiticipation for built-time arguments
# https://github.com/docker/docker/issues/14634
ENV MEDIAWIKI_VERSION master

# MediaWiki setup
RUN set -x; \
    mkdir -p /usr/src \
    && git clone \
        --depth 1 \
        -b $MEDIAWIKI_VERSION \
        https://gerrit.wikimedia.org/r/p/mediawiki/core.git \
        /usr/src/mediawiki
WORKDIR /usr/src/mediawiki
RUN ls -la && ls extensions && ls skins
RUN git clone --depth 1 https://gerrit.wikimedia.org/r/p/mediawiki/vendor.git
RUN if [ -d "/usr/src/mediawiki/extensions" -a $(ls /usr/src/mediawiki/extensions) = "README" ]; then \
  echo "extensions exists, removing" && rm -rf /usr/src/mediawiki/extensions; fi
RUN git clone --depth 1 https://gerrit.wikimedia.org/r/p/mediawiki/extensions.git
RUN if [ -d "/usr/src/mediawiki/skins"  -a $(ls /usr/src/mediawiki/skins) = "README" ]; then \
   echo "skins exists, removing" && rm -rf /usr/src/mediawiki/skins; fi
RUN git clone --depth 1 https://gerrit.wikimedia.org/r/p/mediawiki/skins.git


WORKDIR /usr/src/mediawiki/vendor
RUN git submodule update --init --recursive \
        && git submodule foreach 'git checkout $(MEDIAWIKI_VERSION) || :'
WORKDIR /usr/src/mediawiki/extensions
RUN git submodule update --init --recursive \
        && git submodule foreach 'git checkout $(MEDIAWIKI_VERSION) || :'
WORKDIR /usr/src/mediawiki/skins
RUN git submodule update --init --recursive \
        && git submodule foreach 'git checkout $(MEDIAWIKI_VERSION) || :'

COPY apache/mediawiki.conf /etc/apache2/sites-available/
RUN rm -rf /etc/apache2/sites-enabled/000-default.conf && \
    ln -s /etc/apache2/sites-available/mediawiki.conf /etc/apache2/sites-enabled/mediawiki.conf

#COPY php.ini /etc/php5/conf.d/local.ini

COPY entrypoint.sh /entrypoint.sh

EXPOSE 80 443
ENTRYPOINT ["/entrypoint.sh"]
CMD ["apachectl", "-e", "info", "-D", "FOREGROUND"]
