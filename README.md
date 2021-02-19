# Drone CI docker images for project runtimes

These aren't images for running drone, but for running project builds on drone.

Different Rails projects might need different Ruby version, node version and postgresql. 

## Recipe

Clone this repo and navigate to it in terminal

Register for account on hub.docker.com

locally, run

    docker login
   
Build the images you want to build (images in this repo for example)

    docker build -t YOURDOCKERHUBUSERNAME/YOURREPO:TAG -f a_dockerfile .   
    docker push YOURDOCKERHUBUSERNAME/YOURREPO:TAG

    # e.g:
    docker build -t oleamundsen/drone-ci-rails-env-images:2.6.3-node10-postgres -f ruby2.6.3-node10-postgres.dockerfile .
    docker push oleamundsen/drone-ci-rails-env-images:2.6.3-node10-postgres

In your project .drone.yml link to it

Here's an example .drone.yml for a Rails app

    kind: pipeline
    type: docker
    name: default

    steps:
      - name: build
        image: oleamundsen/drone-ci-rails-env-images:2.6.3-node10-postgres
        commands:
          - yarn install
          - gem install bundler:2.1.4
          - bundle install --path /bundle --without production,development
          - rm config/database.yml
          - mv config/ci-database.yml config/database.yml
          - bundle exec rails parallel:create RAILS_ENV=test
          - bundle exec rails db:migrate RAILS_ENV=test
          - bundle exec rails parallel:prepare RAILS_ENV=test
          - bundle exec rails parallel:spec RAILS_ENV=test
        volumes:
          - name: gem-cache
            path: /bundle
          - name: node_modules-cache
            path: /drone/src/node_modules
          - name: tmp
            path: /drone/src/tmp
        environment:
          RAILS_ENV: test
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          DATABASE_HOST: database
          PARALLEL_TEST_PROCESSORS: 15

    services:
      - name: database
        image: str1fe/postgres_nor
        environment:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
      - name: chrome
        image: selenium/standalone-chrome-debug
        logging:
          driver: none
        shm_size: 1024000000
        environment:
          xpack.security.enabled: false
          discovery.type: single-node

    volumes:
      - name: gem-cache
        host:
          path: /tmp/cache
      - name: node_modules-cache
        host:
          path: /tmp/node_modules-cache
      - name: tmp
        temp: {}

