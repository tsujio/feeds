# Feeds

A simple feed reader for a single user

## Setup

### Setup MongoDB

Feeds uses [MongoDB](https://www.mongodb.org/) as datastore, so you need to setup MongoDB at first.

### Setup Feeds

Feeds is a sinatra application and manages required gems by Gemfile, so you need to install Ruby (>= 1.9.3) and the bundler gem library.

Clone Feeds and exec `bundle install` to install required gems.

```bash
git clone https://github.com/tsujio/feeds.git
cd feeds
bundle install
```

Then run the `tools/setup_db.rb` script.

```bash
tools/setup_db.rb --server 127.0.0.1:27017 --database feeds
```

Configure `config.yaml`.

```yaml
mongo:
  host: 127.0.0.1:27017
  database: feeds
```

Feeds authenticates a user by basic authentication. Set username and password by environment variables (`admin:admin` is used by default).

```bash
export FEEDS_AUTH_USERNAME=foo
export FEEDS_AUTH_PASSWORD=bar
```

Finally, launch Feeds by `rackup`.

```bash
rackup
```

You can register your favorite feed sources and subscribe them.

## Thirdparty Libraries

Feeds uses protonet's [jquery.inview](https://github.com/protonet/jquery.inview) library, and it is stored at `public/js/jquery.inview.min.js`.

This library realizes auto marking articles as read by scrolling.
