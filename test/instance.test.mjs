// What only this instance can assert: facts of CompanyGraph's own model, which the shared tests
// cannot hold because every instance's differ, and this host's own place in it: the surface the
// model names as built by this repository.
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

// The shared page test holds the served graph to what the build wrote, which compares the
// generator with itself. This holds what the build wrote to the model, field by field, so a
// change to the server's jsonld() that alters the organization's keys, the addresses or a
// pointer fails here rather than reaching a crawler. The surface is this host's own since the
// model named it, built by this repository and not the sibling's.
test("a crawler is told the organization and the endpoint the model names for this host", () => {
  const graph = JSON.parse(fs.readFileSync(path.join(process.cwd(), "dist/jsonld.json"), "utf8"))["@graph"];
  const d = JSON.parse(fs.readFileSync(path.join(process.cwd(), "deployment.json"), "utf8"));

  const identity = s.entities.find((e) => e.id === s.rootId);
  const surface = s.entities.find((e) => e.type === "surface"
    && String(e.fields?.["built-by"] ?? "").endsWith(`/${d.repository}`) && e.name.includes("MCP server"));
  assert.ok(surface, "the model names an MCP surface built by this repository");
  const origin = surface.fields.url.replace(/\/$/, "");
  assert.equal(origin, `https://${d.domain}`, "the surface's url is this deployment's domain");

  const organization = graph.find((n) => n["@type"] === "Organization");
  assert.equal(organization["@id"], `${origin}/#organization`, "the organization is this host's copy, not a pointer elsewhere");
  assert.equal(organization.name, identity.name, "the name is the identity's");
  assert.equal(organization.url, identity.fields.url, "the url is the identity's");
  assert.deepEqual(Object.keys(organization).sort(), ["@id", "@type", "name", "sameAs", "url"]);

  const table = identity.sections.find((x) => x.heading === "Also at").tables[0];
  const want = table.rows.map((r) => r[table.columns.indexOf("URL")])
    .filter((u) => !u.startsWith(origin) && u.replace(/\/$/, "") !== identity.fields.url.replace(/\/$/, ""));
  assert.deepEqual(organization.sameAs, want, "every address is one the identity's Also at holds");

  const api = graph.find((n) => n["@type"] === "WebAPI");
  assert.equal(api.url, `${origin}/mcp`, "the API is the endpoint the model names");
  assert.equal(api.description, surface.tagline, "its description is the surface's own tagline");
  assert.equal(api.provider["@id"], organization["@id"], "its provider is the organization in this document");

  const ids = graph.map((n) => n["@id"]);
  assert.equal(new Set(ids).size, ids.length, `two nodes share an @id: ${ids.join(", ")}`);
});
