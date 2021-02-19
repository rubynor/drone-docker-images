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
          - sudo -E yarn install
          - sudo rm config/database.yml
          - sudo mv config/ci-database.yml config/database.yml
          - sudo gem install bundler:2.1.4
          - sudo -E bundle install --path /bundle --without production,development
          - sudo -E bundle exec rails parallel:create RAILS_ENV=test
          - sudo -E bundle exec rails db:migrate RAILS_ENV=test
          - sudo -E bundle exec rails parallel:prepare RAILS_ENV=test
          - sudo -E bundle exec rails parallel:spec RAILS_ENV=test
        volumes:
          - name: gem-cache
            path: /bundle
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

    volumes:
      - name: gem-cache
        host:
          path: /tmp/cache
      - name: tmp
        temp: {}
