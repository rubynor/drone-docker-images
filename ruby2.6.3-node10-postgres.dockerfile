FROM ruby:2.6.3
LABEL maintainer="oma@rubynor.com"
# Allow apt to work with https-based sources
RUN apt-get update -yqq && apt-get install -yqq --no-install-recommends \
  apt-transport-https \
  apt-utils
# Ensure we install an up-to-date version of Node
# See https://github.com/yarnpkg/yarn/issues/2888
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash -
# Ensure latest packages for Yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -  
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | \
  tee /etc/apt/sources.list.d/yarn.list
# Install packages
RUN apt-get update -yqq && apt-get install -yqq --no-install-recommends \
  libpq-dev \
  postgresql-common \
  postgresql-client \
  nodejs \
  yarn \
  pgtop
