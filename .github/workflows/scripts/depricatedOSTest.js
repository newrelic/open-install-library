// List of deprecated test files for the US
const deprecatedOSTestFilesUS = [
    "test/definitions/logging/amazonlinux2018-logs-unsupported.json",
    "test/definitions/otel/rhel/centos7-otel.json",
    "test/definitions/otel/rhel/centos8-otel.json",
    "test/definitions/otel/rhel/centos8arm64-otel.json",
  ];
  
  // List of deprecated test files for the EU
  const deprecatedOSTestFilesEU = [
    "test/definitions-eu/infra-agent/rhel/centos7-infra.json",
    "test/definitions-eu/infra-agent/rhel/centos8-infra.json",
    "test/definitions-eu/infra-agent/rhel/centos8arm64-infra.json",
    "test/definitions-eu/logging/rhel/centos8-arm64-logs.json",
    "test/definitions-eu/otel/rhel/centos7-otel.json",
    "test/definitions-eu/otel/rhel/centos8-otel.json",
    "test/definitions-eu/otel/rhel/centos8arm64-otel.json",
  ];
  
  // Create a lookup map for US deprecated tests
  const deprecatedLookupUS = deprecatedOSTestFilesUS.reduce(
    (lookup, file) => lookup.set(file, true),
    new Map()
  );
  
  // Create a lookup map for EU deprecated tests
  const deprecatedLookupEU = deprecatedOSTestFilesEU.reduce(
    (lookup, file) => lookup.set(file, true),
    new Map()
  );
  
  // Function to check if a file is a deprecated test for the US
  const isDeprecatedOSTestUS = (file) => deprecatedLookupUS.get(file) !== undefined;
  
  // Function to check if a file is a deprecated test for the EU
  const isDeprecatedOSTestEU = (file) => deprecatedLookupEU.get(file) !== undefined;
  
  // Export both functions
  module.exports = { isDeprecatedOSTestUS, isDeprecatedOSTestEU };