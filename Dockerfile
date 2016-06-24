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
ENV MEDIAWIKI_VERSION REL1_27

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
  echo "extensions exists, removing" && rm -rf /usr/src/mediawiki/extensions/*; fi
#RUN git clone --depth 1 https://gerrit.wikimedia.org/r/p/mediawiki/extensions.git
RUN if [ -d "/usr/src/mediawiki/skins"  -a $(ls /usr/src/mediawiki/skins) = "README" ]; then \
   echo "skins exists, removing" && rm -rf /usr/src/mediawiki/skins; fi
RUN git clone --depth 1 https://gerrit.wikimedia.org/r/p/mediawiki/skins.git


WORKDIR /usr/src/mediawiki/vendor
RUN git submodule update --init --recursive \
        && git submodule foreach 'git checkout $(MEDIAWIKI_VERSION) || :'
WORKDIR /usr/src/mediawiki/extensions
RUN git clone https://gerrit.wikimedia.org/r/p/mediawiki/extensions/Wikibase.git \
  && git clone https://gerrit.wikimedia.org/r/p/mediawiki/extensions/UniversalLanguageSelector.git \
  && git clone https://gerrit.wikimedia.org/r/p/mediawiki/extensions/Babel.git \
  && git clone https://gerrit.wikimedia.org/r/p/mediawiki/extensions/cldr.git \
  && git clone https://gerrit.wikimedia.org/r/p/mediawiki/extensions/CategoryTree.git
RUN for i in Wikibase UniversalLanguageSelector Babel cldr CategoryTree; do cd $i; git checkout -b $(MEDIAWIKI_VERSION) origin/$(MEDIAWIKI_VERSION); cd ..; done
#RUN git submodule update --init --recursive \
#        && git submodule foreach 'git checkout $(MEDIAWIKI_VERSION) || :'
WORKDIR /usr/src/mediawiki/skins
RUN git submodule update --init --recursive \
        && git submodule foreach 'git checkout -b $(MEDIAWIKI_VERSION) origin/$(MEDIAWIKI_VERSION) || :'

WORKDIR /usr/src/mediawiki/
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
  && php -r "if (hash_file('SHA384', 'composer-setup.php') === 'bf16ac69bd8b807bc6e4499b28968ee87456e29a3894767b60c2d4dafa3d10d045ffef2aeb2e78827fa5f024fbe93ca2') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" \
  && php composer-setup.php \
  && php -r "unlink('composer-setup.php');" \
  && mv composer.phar /usr/local/bin/composer \
  && composer update

COPY apache/mediawiki.conf /etc/apache2/sites-available/
RUN rm -rf /etc/apache2/sites-enabled/000-default.conf && \
    ln -s /etc/apache2/sites-available/mediawiki.conf /etc/apache2/sites-enabled/mediawiki.conf

#COPY php.ini /etc/php5/conf.d/local.ini

COPY entrypoint.sh /entrypoint.sh

EXPOSE 80 443
ENTRYPOINT ["/entrypoint.sh"]
CMD ["apachectl", "-e", "info", "-D", "FOREGROUND"]
