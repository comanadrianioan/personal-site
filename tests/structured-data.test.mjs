// Checks the JSON-LD in a built site: Person + WebSite on home and About, ProfilePage on About,
// nothing on other pages, and no employer in the data.
// Usage: node tests/structured-data.test.mjs <build dir>... — exits 1 on the first failed assertion.
import { readFileSync } from "node:fs";
import assert from "node:assert/strict";

const PROFILES = ["https://www.linkedin.com/in/adrian-ioan-coman/", "https://github.com/comanadrianioan"];

// Minified builds drop the quotes around the type attribute.
function jsonld(file) {
  const html = readFileSync(file, "utf8");
  const blocks = [...html.matchAll(/<script type="?application\/ld\+json"?>([\s\S]*?)<\/script>/g)];
  return blocks.map((m) => JSON.parse(m[1]));
}

function nodes(file) {
  const docs = jsonld(file);
  assert.equal(docs.length, 1, `${file}: exactly one JSON-LD block`);
  return docs[0]["@graph"];
}

for (const dir of process.argv.slice(2)) {
  for (const page of ["index.html", "about/index.html"]) {
    const file = `${dir}/${page}`;
    const graph = nodes(file);
    const person = graph.find((n) => n["@type"] === "Person");
    const site = graph.find((n) => n["@type"] === "WebSite");
    assert.ok(person && site, `${file}: has Person and WebSite`);
    assert.equal(person["@id"], "https://comanadrian.ro/#person", `${file}: Person @id`);
    assert.equal(person.name, "Adrian Coman", `${file}: Person name`);
    for (const alt of ["Adrian-Ioan Coman", "Coman Adrian"]) {
      assert.ok(person.alternateName.includes(alt), `${file}: alternateName has ${alt}`);
    }
    assert.deepEqual(person.sameAs, PROFILES, `${file}: sameAs is the two profiles`);
    assert.equal(person.url, "https://comanadrian.ro/", `${file}: Person url`);
    assert.ok(person.knowsAbout.includes("Go"), `${file}: knowsAbout lists the skills`);
    assert.equal(site.name, "Adrian Coman", `${file}: WebSite name`);
    const text = JSON.stringify(graph);
    assert.ok(!/worksFor|CrowdStrike/i.test(text), `${file}: no employer in the structured data`);
    assert.ok(!/@[a-z0-9.-]+\.[a-z]{2,}|email/i.test(text.replace(/"@(id|type|graph|context)"/g, "")), `${file}: no email`);
  }
  const profile = nodes(`${dir}/about/index.html`).find((n) => n["@type"] === "ProfilePage");
  assert.deepEqual(profile?.mainEntity, { "@id": "https://comanadrian.ro/#person" }, `${dir}: About is the Person's ProfilePage`);
  assert.equal(nodes(`${dir}/index.html`).some((n) => n["@type"] === "ProfilePage"), false, `${dir}: home is not a ProfilePage`);
  assert.equal(jsonld(`${dir}/writing/index.html`).length, 0, `${dir}: no JSON-LD on Writing`);
}

console.log("structured data: all assertions passed");
