import { test } from "node:test";
import assert from "node:assert/strict";
import { aliasStubs, floorOf } from "../../.github/scripts/validate-modules.mjs";

test("floorOf reads the lower bound of required_version", () => {
  assert.equal(floorOf('terraform {\n  required_version = ">= 1.3.0"\n}\n'), "1.3.0");
  assert.equal(floorOf('terraform {\n  required_version = ">= 1.5.7, < 2.0.0"\n}\n'), "1.5.7");
  assert.equal(floorOf('terraform {\n  required_version = ">=1.10.0"\n}\n'), "1.10.0");
});

test("floorOf rejects a constraint with no exact lower bound", () => {
  assert.equal(floorOf('terraform {\n  required_providers {}\n}\n'), null);
  assert.equal(floorOf('terraform {\n  required_version = "~> 1.3"\n}\n'), null);
  assert.equal(floorOf('terraform {\n  required_version = ">= 1.3"\n}\n'), null);
  assert.equal(floorOf('terraform {\n  required_version = ">= 1.3.0-rc1"\n}\n'), null);
  assert.equal(floorOf('terraform {\n  # required_version = ">= 1.3.0"\n}\n'), null);
});

test("floorOf ignores a provider version constraint", () => {
  const src = 'terraform {\n  required_providers {\n    aws = {\n      version = ">= 6.0.0"\n    }\n  }\n}\n';
  assert.equal(floorOf(src), null);
});

test("aliasStubs writes one provider block per configuration alias", () => {
  const src = "aws = {\n  configuration_aliases = [aws.virginia, aws.replica]\n}\n";
  assert.equal(
    aliasStubs(src),
    'provider "aws" {\n  alias = "virginia"\n}\n\nprovider "aws" {\n  alias = "replica"\n}\n',
  );
});

test("aliasStubs returns nothing for a module with no aliases", () => {
  assert.equal(aliasStubs('aws = {\n  source = "hashicorp/aws"\n}\n'), "");
});
