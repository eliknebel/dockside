import dockside/docker
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn normalises_blank_values_test() {
  should.equal(docker.normalise_api_version(""), docker.default_api_version)
}

pub fn normalises_numeric_values_test() {
  should.equal(docker.normalise_api_version("1.44"), "v1.44")
}

pub fn normalises_prefixed_values_test() {
  should.equal(docker.normalise_api_version("v1.42"), "v1.42")
}

pub fn ignores_auto_sentinel_test() {
  should.equal(docker.normalise_api_version("auto"), docker.default_api_version)
  should.equal(
    docker.normalise_api_version(" AUTO "),
    docker.default_api_version,
  )
}
