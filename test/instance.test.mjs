// What only this instance can assert: facts of CompanyGraph's own model, which the shared tests
// cannot hold because every instance's differ, and the one fact of this deployment's place in
// the family: the model's MCP surface is built by mcp.companygraph.io, not by this host.
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { getEntity } from "companygraph-mcp-server/model";
import { jsonld } from "companygraph-mcp-server/deploy";

const s = JSON.parse(fs.readFileSync(path.join(process.cwd(), "dist/snapshot.json"), "utf8"));

test("the root is CompanyGraph", () => {
  assert.equal(s.root, "CompanyGraph");
});

test("the product the company makes resolves by its type and name", () => {
  // get_entity answers with the id alone; the literal path this pins is an address, so it is
  // checked against the address the snapshot carries for that id, not against the id itself,
  // and it still holds once a backfill gives the product an id its address does not spell.
  const resolved = getEntity(s, "product", "CompanyGraph Core").entity;
  const entity = s.entities.find((e) => e.id === resolved.id);
  assert.equal(entity.address ?? entity.id, "products/companygraph-core");
});

// The shared crawler test only implies this: it computes what jsonld() builds and asks the page
// to agree. This says why the answer is nothing. The model names one MCP surface, built by
// companygraph/mcp-companygraph-io, so this host claims no surface rather than the sibling's.
test("no surface names this repository, so the page carries no structured data", () => {
  const d = JSON.parse(fs.readFileSync(path.join(process.cwd(), "deployment.json"), "utf8"));
  assert.equal(jsonld(s, { repository: d.repository }), null);
});
