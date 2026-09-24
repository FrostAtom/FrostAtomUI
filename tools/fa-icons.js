// Usage: node tools/fa-icons.js <fontawesome-free-web>/metadata/icons.json
const fs = require("fs");
const path = require("path");

const source = process.argv[2];
if (!source) {
	console.error("usage: node tools/fa-icons.js <path to metadata/icons.json>");
	process.exit(1);
}

const icons = JSON.parse(fs.readFileSync(source, "utf8"));
const lines = [];
for (const name of Object.keys(icons).sort()) {
	const icon = icons[name];
	if (!(icon.free || []).includes("solid")) continue;
	lines.push(`\t["${name}"] = 0x${icon.unicode},`);
}

const out = path.join(__dirname, "..", "FrostAtomUI", "Core", "GlyphData.lua");
fs.writeFileSync(out, `local _, ns = ...\n\nns.GlyphCodes = {\n${lines.join("\n")}\n}\n`);
console.log(`${lines.length} icons -> ${out}`);
