#!/usr/bin/env bats

@test "Not fail when testing a service with a warning" {
  run ./conftest test -p examples/kubernetes/policy examples/kubernetes/service.yaml
  [ "$status" -eq 0 ]
}

@test "Not fail when passed an explicit blank filename" {
  run ./conftest test -p examples/kubernetes/policy examples/kubernetes/service.yaml ""
  [ "$status" -eq 0 ]
}

@test "Fail when testing a deployment with root containers" {
  run ./conftest test -p examples/kubernetes/policy examples/kubernetes/deployment.yaml
  [ "$status" -eq 1 ]
}

@test "Fail when testing a service with warnings" {
  run ./conftest test --fail-on-warn -p examples/kubernetes/policy examples/kubernetes/service.yaml
  [ "$status" -eq 1 ]
}

@test "Fail when testing with no policies path" {
  run ./conftest test -p internal/ examples/kubernetes/deployment.yaml
  [ "$status" -eq 1 ]
}

@test "Pass when testing a blank namespace" {
  run ./conftest test --namespace notpresent -p examples/kubernetes/policy examples/kubernetes/deployment.yaml
  [ "$status" -eq 0 ]
}

@test "when testing a YAML document via stdin, default parser should be yaml if no parser flag is passed" {
  run ./conftest test -p examples/kubernetes/policy - < examples/kubernetes/service.yaml
  [ "$status" -eq 0 ]
}

@test "Pass when testing a YAML document via stdin" {
  run ./conftest test --parser yaml -p examples/kubernetes/policy - < examples/kubernetes/service.yaml
  [ "$status" -eq 0 ]
}

@test "Fail due to picking up settings from configuration file" {
  cd examples/configfile
  run ../../conftest test deployment.yaml
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Containers must not run as root" ]]
}

@test "Fail due to picking up settings from config-file flag" {
  DIR="examples/configfile"
  run ./conftest -c $DIR/conftest.toml test -p $DIR/test $DIR/deployment.yaml
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Containers must not run as root" ]]
}

@test "Has version flag" {
  run ./conftest --version
  [ "$status" -eq 0 ]
}

@test "Test command with multiple input type" {
  run ./conftest test examples/traefik/traefik.toml examples/kubernetes/service.yaml -p examples/kubernetes/policy
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Found service hello-kubernetes but services are not allowed" ]]
}

@test "Test command has trace flag" {
  run ./conftest test -p examples/kubernetes/policy examples/kubernetes/service.yaml --trace
  [ "$status" -eq 0 ]
  [[ "$output" =~ "data.kubernetes.is_service" ]]
}

@test "Test command with all namespaces flag" {
  run ./conftest test -p examples/docker/policy examples/docker/Dockerfile --all-namespaces
  [ "$status" -eq 1 ]
  [[ "$output" =~ "unallowed image found [\"openjdk:8-jdk-alpine\"]" ]]
  [[ "$output" =~ "unallowed commands found [\"apk add --no-cache python3 python3-dev build-base && pip3 install awscli==1.18.1\"]" ]]
}

@test "Test command works with nested namespaces" {
  run ./conftest test --namespace main.gke -p examples/hcl1/policy/ examples/hcl1/gke.tf --no-color
  [ "$status" -eq 1 ]
  [ "${lines[1]}" = "1 test, 0 passed, 0 warnings, 1 failure, 0 exceptions" ]
}

@test "Verify command has trace flag" {
  run ./conftest verify --policy ./examples/kubernetes/policy --trace
  [ "$status" -eq 0 ]
  [[ "$output" =~ "data.kubernetes.is_service" ]]
}

@test "Fail when verifying with no policies path" {
  run ./conftest verify -p internal/
  [ "$status" -eq 1 ]
}

@test "Verify command has report flag - no failures" {
    run ./conftest verify --policy ./examples/report/policy --policy ./examples/report/success --report fails
    [ "$status" -eq 0 ]
    [[ "$output" =~ "data.main.test_no_missing_label: PASS" ]]
    [[ "$output" =~ "PASS: 1/1" ]]
}

@test "Verify command has report flag - success with print output" {
    run ./conftest verify --policy ./examples/report/policy_print --policy ./examples/report/success --report fails
    [ "$status" -eq 0 ]
    [[ "$output" =~ "data.main.test_no_missing_label: PASS" ]]
    [[ "$output" =~ "sample" ]]
    [[ "$output" =~ "PASS: 1/1" ]]
}

@test "Verify command does not support report flag with table output" {
    run ./conftest verify --policy ./examples/report/policy -o table --report fails
    [[ "$output" =~ "Error: report flag is supported with stdout only" ]]
}

@test "Verify command does not support report flag with tap output" {
    run ./conftest verify --policy ./examples/report/policy -o tap --report fails
    [[ "$output" =~ "Error: report flag is supported with stdout only" ]]
}

@test "Verify command does not support report flag with junit output" {
    run ./conftest verify --policy ./examples/report/policy -o junit --report fails
    [[ "$output" =~ "Error: report flag is supported with stdout only" ]]
}

@test "Verify command does not support report flag with json output" {
    run ./conftest verify --policy ./examples/report/policy -o json --report fails
    [[ "$output" =~ "Error: report flag is supported with stdout only" ]]
}

@test "Verify command has report flag - failure with report fails" {
    run ./conftest verify --policy ./examples/report/policy --policy ./examples/report/fail --report fails
    [ "$status" -eq 1 ]
    [[ "$output" =~ "FAILURES" ]]
    [[ "$output" =~ "data.main.test_missing_required_label_fail: FAIL" ]]
    [[ "$output" =~ "Fail input.metadata.labels[\"app.kubernetes.io/name\"]" ]]
    [[ "$output" =~ "SUMMARY" ]]
    [[ "$output" =~ "FAIL: 1/1" ]]
}

@test "Verify command has report flag - failure with report notes" {
    run ./conftest verify --policy ./examples/report/policy --policy ./examples/report/fail --report notes
    [ "$status" -eq 1 ]
    [[ "$output" =~ "FAILURES" ]]
    [[ "$output" =~ "data.main.test_missing_required_label_fail: FAIL" ]]
    [[ "$output" =~ "Note \"just testing notes flag\"" ]]
    [[ "$output" =~ "SUMMARY" ]]
    [[ "$output" =~ "FAIL: 1/1" ]]
}

@test "Verify command has report flag - failure with report full" {
    run ./conftest verify --policy ./examples/report/policy --policy ./examples/report/fail --report full
    [ "$status" -eq 1 ]
    [[ "$output" =~ "FAILURES" ]]
    [[ "$output" =~ "data.main.test_missing_required_label_fail: FAIL" ]]
    [[ "$output" =~ "Eval input.metadata.labels[\"app.kubernetes.io/name\"]" ]]
    [[ "$output" =~ "Fail input.metadata.labels[\"app.kubernetes.io/name\"]" ]]
    [[ "$output" =~ "Note \"just testing notes flag\"" ]]
    [[ "$output" =~ "SUMMARY" ]]
    [[ "$output" =~ "FAIL: 1/1" ]]
}

@test "Has help flag" {
  run ./conftest --help
  [ "$status" -eq 0 ]
}

@test "Allow .rego files in the policy flag" {
  run ./conftest test -p examples/hcl1/policy/base.rego examples/hcl1/gke-show.json
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Terraform plan will change prohibited resources in the following namespaces: google_iam, google_container" ]]
}

@test "Supports print() output" {
  run ./conftest test -p examples/report/policy_print/labels.rego examples/kubernetes/deployment.yaml --no-color
  [ "$status" -eq 1 ]
  [[ "${lines[0]}" == "PRNT   examples/report/policy_print/labels.rego:14: hello-kubernetes" ]]
}

@test "Can parse hcl1 files" {
  run ./conftest test -p examples/hcl1/policy/gke.rego examples/hcl1/gke.tf
  [ "$status" -eq 0 ]
}

@test "Can parse toml files" {
  run ./conftest test -p examples/traefik/policy examples/traefik/traefik.toml
  [ "$status" -eq 1 ]
}

@test "Can parse edn files" {
  run ./conftest test -p examples/edn/policy examples/edn/sample_config.edn
  [ "$status" -eq 1 ]
}

@test "Can parse xml files" {
  run ./conftest test -p examples/xml/policy examples/xml/pom.xml
  [ "$status" -eq 1 ]
  [[ "$output" =~ "--- maven-plugin must have the version: 3.6.1" ]]
}

@test "Can parse hocon files" {
  run ./conftest test -p examples/hocon/policy examples/hocon/hocon.conf --parser hocon
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Play http server port should be 9000" ]]
}

@test "Can parse vcl files" {
  run ./conftest test -p examples/vcl/policy examples/vcl/varnish.vcl
  [ "$status" -eq 1 ]
  [[ "$output" =~ "default backend port should be 8080" ]]
}

@test "Can parse jsonnet files" {
  run ./conftest test -p examples/jsonnet/policy examples/jsonnet/arith.jsonnet
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Concat array should be less than 3" ]]
}

@test "Can parse .dockerignore files" {
  run ./conftest test -p examples/ignore/dockerignore/policy examples/ignore/dockerignore/.dockerignore
  [ "$status" -eq 1 ]
  [[ "$output" =~ ".git directories should be ignored" ]]
}

@test "Can parse .gitignore files" {
  run ./conftest test -p examples/ignore/gitignore/policy examples/ignore/gitignore/.gitignore
  [ "$status" -eq 1 ]
  [[ "$output" =~ "id_rsa files should be ignored" ]]
}

@test "Can parse cue files" {
  run ./conftest test -p examples/cue/policy examples/cue/deployment.cue
  [ "$status" -eq 1 ]
  [[ "$output" =~ "The image port should be 8080 in deployment.cue. you have : 8081" ]]
}

@test "Can parse ini files" {
  run ./conftest test -p examples/ini/policy examples/ini/grafana.ini
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Users should verify their e-mail address" ]]
}

@test "Can parse hcl files" {
  run ./conftest test -p examples/hcl2/policy examples/hcl2/terraform.tf
  [ "$status" -eq 1 ]
  [[ "$output" =~ "ALB \`my-alb-listener\` is using HTTP rather than HTTPS" ]]
}

@test "Can parse properties files" {
  run ./conftest test -p examples/properties/policy/ examples/properties/sample.properties
  [ "$status" -eq 0 ]
}

@test "Can parse stdin with parser flag" {
  run bash -c "cat examples/ini/grafana.ini | ./conftest test -p examples/ini/policy --parser ini -"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Users should verify their e-mail address" ]]
  [[ "$output" != *"Basic auth should be enabled"* ]]
}

@test "Using --parser should force the chosen parser and fail the rego policy" {
  run ./conftest test -p examples/terraform/policy/gke.rego examples/terraform/gke.tf --parser ini
  [ "$status" -eq 1 ]
}

@test "Can verify unit tests using parse_config() and parse_config_file builtins()" {
  run ./conftest verify -p examples/hcl2/policy examples/hcl2
  [ "$status" -eq 0 ]
}

@test "Can combine configs and reference by file" {
  run ./conftest test -p examples/hcl1/policy/gke_combine.rego examples/hcl1/gke.tf --combine --parser hcl1 --all-namespaces
  [ "$status" -eq 0 ]
}

@test "Can parse docker files" {
  run ./conftest test -p examples/docker/policy examples/docker/Dockerfile
  [ "$status" -eq 1 ]
  [[ "$output" =~ "unallowed image found [\"openjdk:8-jdk-alpine\"]" ]]
}

@test "Can parse newly introduced keywords for docker" {
  run bash -c "cat <<EOF | ./conftest parse --parser dockerfile -
# syntax=docker/dockerfile:1.4
FROM alpine
COPY --link /foo /bar
EOF"
  [ "$status" -eq 0 ]
}

@test "Can disable color" {
  run ./conftest test -p examples/kubernetes/policy examples/kubernetes/service.yaml --no-color
  [ "$status" -eq 0 ]
  [[ "$output" != *"[33m"* ]]
}

@test "Output results only once" {
  run ./conftest test -p examples/kubernetes/policy examples/kubernetes/deployment.yaml
  count="${#lines[@]}"
  [ "$count" -eq 5 ]
}

@test "Can verify rego tests" {
  run ./conftest verify --policy ./examples/kubernetes/policy
  [ "$status" -eq 0 ]
  [[ "$output" =~ "4 tests, 4 passed" ]]
}

@test "Can parse inputs with 'conftest parse'" {
  run ./conftest parse examples/docker/Dockerfile
  [ "$status" -eq 0 ]
  [[ "$output" =~ "\"Cmd\": \"from\"" ]]
}

@test "Can parse single file with 'conftest parse'" {
  run bash -c "./conftest parse examples/kubernetes/deployment.yaml | jq '.kind'"
  [ "$status" -eq 0 ]
  [[ "$output" = "\"Deployment\"" ]]
}

@test "Can parse multiple files with 'conftest parse'" {
  run bash -c "./conftest parse examples/kubernetes/deployment.yaml examples/kubernetes/deployment+service.yaml | jq 'keys'"
  [ "$status" -eq 0 ]
  count="${#lines[@]}"
  [ "$count" -eq 4 ]
  [[ "$output" =~ "\"examples/kubernetes/deployment+service.yaml\"" ]]
  [[ "$output" =~ "\"examples/kubernetes/deployment.yaml\"" ]]
}

@test "Can output tap format in test command" {
  run ./conftest test -p examples/kubernetes/policy/ -o tap examples/kubernetes/deployment.yaml
  [[ "$output" =~ "not ok" ]]
}

@test "Can output tap format in verify command" {
  run ./conftest verify -p examples/kubernetes/policy/ -o tap
  [[ "$output" =~ "ok" ]]
}

@test "Can output table format in test command" {
  run ./conftest test -p examples/kubernetes/policy/ -o table examples/kubernetes/deployment.yaml
  [[ "$output" =~ "failure" ]]
}

@test "Can output table format in verify command" {
  run ./conftest verify -p examples/kubernetes/policy/ -o table
  [[ "$output" =~ "success" ]]
}

@test "Multi-file tests correctly fail when last file is fine" {
  run ./conftest test -p examples/kubernetes/policy examples/kubernetes/deployment.yaml examples/kubernetes/service.yaml
  [ "$status" -eq 1 ]
}

@test "Fail when unit test rego" {
  run ./conftest verify -p examples/traefik/policy
  [ "$status" -eq 1 ]
}

@test "Can load data along with rego policies" {
  run ./conftest test -p examples/data/policy -d examples/data/exclusions examples/data/service.yaml
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Cannot expose port" ]]
}

@test "Can load data in unit tests" {
  run ./conftest verify -p examples/data/policy -d examples/data/exclusions examples/data/service.yaml
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1 test, 1 passed, 0 warnings, 0 failures" ]]
}

@test "Can update policies in test command" {
  run ./conftest test --update https://raw.githubusercontent.com/open-policy-agent/conftest/master/examples/compose/policy/deny.rego examples/compose/docker-compose.yml
  rm -rf policy/deny.rego
  [ "$status" -eq 1 ]
  [[ "$output" =~ "No images tagged latest" ]]
}

@test "Can validate a docker-compose file that does not conform to the policy" {
  run ./conftest test -p examples/compose/policy examples/compose/docker-compose.yml --no-color
  [ "$status" -eq 1 ]
  [[ "$output" =~ "2 tests, 0 passed, 0 warnings, 2 failures, 0 exceptions" ]]
}

@test "Can validate a docker-compose file that conforms to the policy" {
  run ./conftest test -p examples/compose/policy examples/compose/docker-compose-valid.yml --no-color
  [ "$status" -eq 0 ]
  [[ "$output" =~ "2 tests, 2 passed, 0 warnings, 0 failures, 0 exceptions" ]]
}

@test "The number of tests run is accurate" {
  run ./conftest test -p examples/kubernetes/policy examples/kubernetes/service.yaml --no-color
  [ "$status" -eq 0 ]
  [ "${lines[1]}" = "5 tests, 4 passed, 1 warning, 0 failures, 0 exceptions" ]
}

@test "Exceptions reported correctly" {
  run ./conftest test -p examples/exceptions/policy examples/exceptions/deployments.yaml --no-color
  [ "$status" -eq 1 ]
  [ "${lines[2]}" = "2 tests, 0 passed, 0 warnings, 1 failure, 1 exception" ]
}

@test "Exceptions output" {
  run ./conftest test -p examples/exceptions/policy examples/exceptions/deployments.yaml --no-color
  [ "$status" -eq 1 ]
  [[ "${lines[1]}" =~ "EXCP - examples/exceptions/deployments.yaml - main - data.main.exception[_][_] == \"run_as_root\"" ]]
}

@test "Suppress exceptions output" {
  run ./conftest test -p examples/exceptions/policy examples/exceptions/deployments.yaml --no-color --suppress-exceptions
  [ "$status" -eq 1 ]
  [ "${lines[1]}" = "2 tests, 0 passed, 0 warnings, 1 failure, 1 exception" ]
}

@test "Can combine yaml files" {
  run ./conftest test -p examples/combine/policy examples/combine/team.yaml examples/combine/user1.yaml examples/combine/user2.yaml --combine

  [ "$status" -eq 1 ]
  [[ "$output" =~ "2 tests, 1 passed, 0 warnings, 1 failure" ]]
}

@test "Combining multi-document yaml file has same result" {
  run ./conftest test -p examples/combine/policy examples/combine/team.yaml examples/combine/users.yaml --combine

  [ "$status" -eq 1 ]
  [[ "$output" =~ "2 tests, 1 passed, 0 warnings, 1 failure" ]]
}

@test "Can parse SPDX file" {
  run ./conftest parse --parser spdx examples/spdx/sbom.spdx

  [ "$status" -eq 0 ]
}

@test "Can validate SPDX file" {
  run ./conftest test -p examples/spdx/policy examples/spdx/sbom.spdx

  [ "$status" -eq 0 ]
  [[ "$output" =~ "1 test, 1 passed, 0 warnings, 0 failures, 0 exceptions" ]]
}

@test "Can test cyclonedx against policy" {
  run ./conftest test --policy ./examples/cyclonedx/policy/ ./examples/cyclonedx/cyclonedx.json --parser cyclonedx
  [ "$status" -eq 0 ]
}

@test "Can parse cyclonedx JSON file" {
  run ./conftest parse --parser cyclonedx ./examples/cyclonedx/cyclonedx.json
  [ "$status" -eq 0 ]
}

@test "Can parse cyclonedx XML file" {
  run ./conftest parse --parser cyclonedx ./examples/cyclonedx/cyclonedx.xml
  [ "$status" -eq 0 ]
}

@test "Can parse .env files" {
  run ./conftest test -p examples/dotenv/policy/ examples/dotenv/sample.env
  [ "$status" -eq 0 ]
}

@test "Should fail if strict is set and there are unused variables in the policy" {
  run ./conftest test -p examples/strict-rules/policy/ examples/kubernetes/deployment.yaml --strict
  [ "$status" -eq 1 ]
  [[ "$output" =~ "rego_compile_error: assigned var b unused" ]]
  [[ "$output" =~ "rego_compile_error: assigned var x unused" ]]
  [[ "$output" =~ "rego_compile_error: assigned var c unused" ]]
  [[ "$output" =~ "rego_compile_error: unused argument y" ]]
}

@test "Should fail when verifying if strict is set and there are unused variables in the policy" {
  run ./conftest verify -p examples/strict-rules/policy/ examples/kubernetes/deployment.yaml --strict
  [ "$status" -eq 1 ]
  [[ "$output" =~ "rego_compile_error: assigned var b unused" ]]
  [[ "$output" =~ "rego_compile_error: assigned var x unused" ]]
  [[ "$output" =~ "rego_compile_error: assigned var c unused" ]]
  [[ "$output" =~ "rego_compile_error: unused argument y" ]]
}

@test "Should fail if an opa function is not defined given capabilities file" {
  run ./conftest test examples/kubernetes/deployment.yaml -p examples/kubernetes/policy/ -p examples/capabilities/malicious.rego --capabilities examples/capabilities/capabilities.json
  [ "$status" -eq 1 ]
  [[ "$output" =~ "undefined function opa.runtime" ]]
  [[ "$output" =~ "undefined function http.send" ]]
}

@test "Can verify rego tests that uses parse_combined_config_files" {
  run ./conftest verify --policy ./examples/kubernetes/combine
  [ "$status" -eq 0 ]
  [[ "$output" =~ "2 tests, 2 passed" ]]
}

@test "Should not show any output with quiet flag and all tests succeeds" {
  run ./conftest test -p examples/kubernetes/policy/deny.rego examples/kubernetes/deployment.yaml --quiet
  [ "$status" -eq 0 ]
  [[ "$output" = "" ]]
}

@test "Should show output because of failure" {
  run ./conftest test -p examples/kubernetes/policy/ examples/kubernetes/deployment.yaml  --all-namespaces --quiet
  [ "$status" -eq 1 ]
  [[ "$output" =~ "5 tests, 1 passed, 0 warnings, 4 failures, 0 exceptions" ]]
}

@test "Should fail evaluation if a builtin function returns error" {
  run ./conftest test --show-builtin-errors -p examples/builtin-errors/invalid-dns.rego examples/kubernetes/deployment.yaml
  [ "$status" -eq 1 ]
  [[ "$output" =~ "built-in error" ]]
}

@test "TextProto policy returns expected results" {
  run ./conftest test --proto-file-dirs=examples/textproto/protos -p examples/textproto/policy examples/textproto/
  [ "$status" -eq 1 ]
  [[ "$output" =~ "2 tests, 1 passed, 0 warnings, 1 failure, 0 exceptions" ]]
}

@test "TextProto policy fails when the proto messages could not be resolved" {
  run ./conftest test -p examples/textproto/policy examples/textproto/
  [ "$status" -eq 1 ]
  [[ "$output" =~ "look up message type" ]]
}

@test "Can parse files from a symlinked directory" {
  TMPDIR="$(mktemp -d -u)"
  ln -s $(pwd)/examples/hcl2 ${TMPDIR}
  run ./conftest test -p examples/hcl2/policy ${TMPDIR}
  rm -rf ${TMPDIR}
  [ "$status" -eq 1 ]
  [[ "$output" =~ "10 tests, 3 passed, 0 warnings, 7 failures, 0 exceptions" ]]
}
