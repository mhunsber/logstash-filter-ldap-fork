# Logstash Plugin

[![Travis Build Status](https://travis-ci.org/mhunsber/logstash-filter-ldap.svg)](https://travis-ci.org/mhunsber/logstash-filter-ldap)

This is a plugin for [Logstash](https://github.com/elastic/logstash).

It is fully free and fully open source. The license is Apache 2.0, meaning you are pretty much free to use it however you want in whatever way.

## Documentation

Logstash provides infrastructure to automatically generate documentation for this plugin. We use the asciidoc format to write documentation so any comments in the source code will be first converted into asciidoc and then into html. All plugin documentation are placed under one [central location](http://www.elastic.co/guide/en/logstash/current/).

- For formatting code or config example, you can use the asciidoc `[source,ruby]` directive
- For more asciidoc formatting tips, see the excellent reference here <https://github.com/elastic/docs#asciidoc-guide>

## Example

### Basic sample

#### Input event

```ruby
{
    "@timestamp" => 2018-02-25T10:04:22.338Z,
    "@version" => "1",
    "myUid" => "u501565"
}
```

#### Logstash filter

```ruby
filter {
  ldap {
    host => "my_ldap_server.com"
    port => "389"
    bind_dn => "cn=read-only-admin"
    bind_password => "password123"
    base_dn => "ou=users,dc=example,dc=com"
    ldap_filter => "uid=%{myUid}"
  }
}
```

#### Output event

```ruby
{
    "@timestamp" => 2018-02-25T10:04:22.338Z,
    "@version" => "1",
    "myUid" => "u501565",
    "ldap" => {
        "givenName" => [ "VALENTIN" ],
        "sn" => [ "BOURDIER" ]
    }
}
```

## Need Help?

Need help? Try #logstash on freenode IRC or the <https://discuss.elastic.co/c/logstash> discussion forum.

## Developing

### 1. Plugin Developement and Testing

#### Code

- To get started, you'll need JRuby with the Bundler gem installed.

- Create a new plugin or clone and existing from the GitHub [logstash-plugins](https://github.com/logstash-plugins) organization. We also provide [example plugins](https://github.com/logstash-plugins?query=example).

- Install dependencies

```sh
bundle install
```

#### Test

- Update your dependencies

```sh
bundle install
```

- Run tests

```sh
bundle exec rspec
```

### 2. Running your unpublished Plugin in Logstash

#### 2.1 Run in a local Logstash clone

- Edit Logstash `Gemfile` and add the local plugin path, for example:

```ruby
gem "logstash-filter-awesome", :path => "/your/local/logstash-filter-awesome"
```

- Install plugin

```sh
# Logstash 2.3 and higher
bin/logstash-plugin install --no-verify

# Prior to Logstash 2.3
bin/plugin install --no-verify

```

- Run Logstash with your plugin

```sh
bin/logstash -e 'filter {awesome {}}'
```

At this point any modifications to the plugin code will be applied to this local Logstash setup. After modifying the plugin, simply rerun Logstash.

#### 2.2 Run in an installed Logstash

You can use the same **2.1** method to run your plugin in an installed Logstash by editing its `Gemfile` and pointing the `:path` to your local plugin development directory or you can build the gem and install it using:

- Build your plugin gem

```sh
gem build logstash-filter-awesome.gemspec
```

- Install the plugin from the Logstash home

```sh
# Logstash 2.3 and higher
bin/logstash-plugin install --no-verify

# Prior to Logstash 2.3
bin/plugin install --no-verify

```

- Start Logstash and proceed to test the plugin

## Contributing

All contributions are welcome: ideas, patches, documentation, bug reports, complaints, and even something you drew up on a napkin.

Programming is not a required skill. Whatever you've seen about open source and maintainers or community members  saying "send patches or die" - you will not see that here.

It is more important to the community that you are able to contribute.

For more information about contributing, see the [CONTRIBUTING](https://github.com/elastic/logstash/blob/master/CONTRIBUTING.md) file.

## Attributions

This plugin was strongly inspired by the [logstash_filter_LDAPresolve](https://github.com/EricDeveaud/logstash_filter_LDAPresolve), made by [EricDeveaud](https://github.com/EricDeveaud).

This repository is a fork of [AtlasPlato/logstash-filter-ldap](https://github.com/AtlasPlato/logstash-filter-ldap), originally authored by [Transrian](https://github.com/Transrian).
