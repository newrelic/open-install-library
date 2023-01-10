// These OHI are timing out in validation, causing installations to report as incomplete
const ohiValidationTimeoutFiles = [
  "test/definitions/ohi/linux/cassandra-debian.json",
  "test/definitions/ohi/linux/consul-debian.json",
  "test/definitions/ohi/linux/consul-rhel.json",
  "test/definitions/ohi/linux/couchbase-debian.json",
  "test/definitions/ohi/linux/couchbase-rhel.json",
  "test/definitions/ohi/linux/elasticsearch-debian.json",
  "test/definitions/ohi/linux/elasticsearch-rhel.json",
  "test/definitions/ohi/linux/elasticsearch-suse.json",
  "test/definitions/ohi/linux/haproxy-debian.json",
  "test/definitions/ohi/linux/haproxy-rhel.json",
  "test/definitions/ohi/linux/memcached-debian.json",
  "test/definitions/ohi/linux/memcached-rhel.json",
  "test/definitions/ohi/linux/mongodb-debian.json",
  "test/definitions/ohi/linux/mysql-debian.json",
  "test/definitions/ohi/linux/nagios-debian.json",
  "test/definitions/ohi/linux/nagios-rhel.json",
  "test/definitions/ohi/linux/nginx-debian.json",
  "test/definitions/ohi/linux/nginx-linux2-ami.json",
  "test/definitions/ohi/linux/postgres-debian.json",
  "test/definitions/ohi/linux/postgres-rhel.json",
  "test/definitions/ohi/linux/redis-debian.json",
  "test/definitions/ohi/linux/varnish-debian.json",
  "test/definitions/ohi/windows/ms-sql-server2019Standard.json",
];

const ohiLookup = ohiValidationTimeoutFiles.reduce(
  (lookup, file) => lookup.set(file, true),
  new Map()
);

const isOHIValidationTimeout = (file) => ohiLookup.get(file) !== undefined;

module.exports = { isOHIValidationTimeout };
