#!/usr/bin/env bash
set -ex
export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get install -y tzdata libmysqlclient-dev
gem install bundler -v '1.16.2'
# install
bundle install --jobs=4 --retry=3 --deployment
# before_script
cp .travis/database.yml config/database.yml
touch log/test.log
bundle exec rake db:migrate:reset
# script
bundle exec rspec
