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

## Example .drone.yml

Here's an example .drone.yml for a Rails app

    kind: pipeline
    type: docker
    name: default

    steps:
      - name: build
        image: oleamundsen/drone-ci-rails-env-images:2.6.3-node10-postgres-pgtop
        commands:
          - yarn install
          - gem install bundler:2.1.4
          - bundle install --path /bundle --without production,development
          - cp config/ci-database.yml config/database.yml
          - cp config/email.yml.example config/email.yml
          - cp .rspec_parallel_ci .rspec_parallel
          - bundle exec rails parallel:create RAILS_ENV=test
          - bundle exec rails db:test:prepare
          - bundle exec rails runner 'puts Time.zone; puts Time.zone.now; puts Time.now'
          - bundle exec rake webpacker:compile
          - bundle exec rails parallel:prepare RAILS_ENV=test
    #      - cat keep/parallel_runtime_rspec.log
    #      - cat .rspec_parallel
          - bundle exec parallel_rspec spec -t rspec --runtime-log keep/parallel_runtime_rspec.log
        volumes:
          - name: gem-cache
            path: /bundle
          - name: node_modules-cache
            path: /drone/src/node_modules
          - name: tmp
            path: /drone/src/tmp
          - name: keep
            path: /drone/src/keep

        environment:
          RAILS_ENV: test
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          DATABASE_HOST: database
          PARALLEL_TEST_PROCESSORS: 15
          CI: true
          TZ: Europe/Oslo  # may disable this to test how a different timezone for Time.now affect things

    services:
      - name: database
        image: str1fe/postgres_nor
        environment:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
      - name: chrome
        image: selenium/standalone-chrome
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
      - name: keep
        host:
          path: /tmp/keep
      - name: tmp
        temp: {}


### Example .rspec_parallel_ci using runtime logger to distribute the specs on threads

This is copied to .rspec_parallel in the setup. The parallel runtime logs are put in keep/ instead of default tmp volume as that's cleaned out for each run.

    --format progress
    --format ParallelTests::RSpec::RuntimeLogger --out keep/parallel_runtime_rspec.log
    # Do not change runtime logger destination without also updating runner command. Using the default tmp/ is recommended locally

To run with the new log, the build also needs to specify it

    bundle exec parallel_rspec spec -t rspec --runtime-log keep/parallel_runtime_rspec.log
    
### Example rails_helper.rb with Capybara and VCR

      Webdrivers.cache_time = 86_400
      port = 9887 + ENV.fetch('TEST_ENV_NUMBER', '1').to_i
      VCR.configure do |config|
        config.cassette_library_dir = "spec/support/vcr"
        config.hook_into :webmock # or :fakeweb
        config.ignore_localhost = true
        config.ignore_hosts 'chromedriver.storage.googleapis.com'
        if ENV['CI']
          config.ignore_request do |request|
            # Webmock will block attemts to reach chrome:4444
            URI(request.uri).port == 4444 || URI(request.uri).port == port
          end
        end
      end

      Capybara.server = :puma, { Silent: true }
      if ENV['CI']
        Capybara.server_host         = '0.0.0.0'
        Capybara.raise_server_errors = false
        Capybara.threadsafe          = true
        Capybara.server_port = port

        Capybara.register_driver :headless_selenium_chrome_in_container do |app|
          Capybara::Selenium::Driver.new app,
                                         browser: :remote,
                                         url: "http://chrome:4444/wd/hub",
                                         desired_capabilities: Selenium::WebDriver::Remote::Capabilities.chrome(
                                           chromeOptions: { args: %w(headless disable-gpu no-sandbox disable-dev-shm-usage window-size=1920,1080) }
                                         )
        end
        Capybara.javascript_driver = :headless_selenium_chrome_in_container
        Capybara.app_host = "http://build:#{port}"
      else
        Capybara.register_driver :chrome do |app|
          Capybara::Selenium::Driver.new app, browser: :chrome,
                                         options: Selenium::WebDriver::Chrome::Options.new(args:  %w(headless disable-gpu window-size=1920,1080))
        end
        Capybara.javascript_driver = :chrome
      end
