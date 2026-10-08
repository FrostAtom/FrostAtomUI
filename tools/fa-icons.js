// Usage: node tools/fa-icons.js <fontawesome-free-web>/metadata/icons.json
const fs = require("fs");
const path = require("path");

const source = process.argv[2];
if (!source) {
	console.error("usage: node tools/fa-icons.js <path to metadata/icons.json>");
	process.exit(1);
}

const root = path.join(__dirname, "..");
const out = path.join(root, "FrostAtomUI", "Core", "GlyphData.lua");

const used = new Set();
function scan(dir) {
	for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
		const full = path.join(dir, entry.name);
		if (entry.isDirectory()) {
			scan(full);
		} else if (entry.name.endsWith(".lua") && full !== out) {
			for (const match of fs.readFileSync(full, "utf8").matchAll(/"([a-z0-9][a-z0-9-]*)"/g)) {
				used.add(match[1]);
			}
		}
	}
}
scan(path.join(root, "FrostAtomUI"));
scan(path.join(root, "FrostAtomUI_Config"));

const icons = JSON.parse(fs.readFileSync(source, "utf8"));
const lines = [];
for (const name of Object.keys(icons).sort()) {
	const icon = icons[name];
	if (!(icon.free || []).includes("solid") || !used.has(name)) continue;
	lines.push(`\t["${name}"] = 0x${icon.unicode},`);
}

fs.writeFileSync(out, `local _, ns = ...\n\nns.GlyphCodes = {\n${lines.join("\n")}\n}\n`);
console.log(`${lines.length} icons used by the addons -> ${out}`);
