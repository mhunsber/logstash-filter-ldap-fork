# Changelog

## 0.3.1

- cloned from <https://github.com/Transrian/logstash-filter-ldap>.
- made ldap querying more flexible
  - removed `identifier_value`, `identifier_key` and `identifier_type`
  - added `ldap_filter` which can be passed as a sprintf string.
- changed `no_tag_on_failure` boolean to use the more common `tag_on_failure` array setting
- tests don't require an ldap server
- combined `ldap_port` and `ldaps_port` to a single `port` setting
- renamed several other connection/authentication settings
- improvements for Microsoft AD
  - decodes the `objectGuid` attribute from its binary representation
  - decode the `objectSid` attribute from its binary representation
- result set is always an array
- supports matching multiple entries

## 0.2.4

- Fix non atomic cache operation when getting a cache result
  - Updated net-ldap library version
  - We can periodicly save buffer to disk

## 0.2.3

- avoid hash computation if the cache is not required
- we now use [LRU Cache](https://github.com/SamSaffron/lru_redux) as default memory caching algorithm
- memory cache is enabled by default

## 0.2.2

- Added a no_tag_on_failure option

## 0.2.1

- Changed library for ldap queries
- Fixed bugs concerning LDAPs connections

## 0.2.0

- Rename of some config fields

## 0.1.0

- Plugin created with the logstash plugin generator
