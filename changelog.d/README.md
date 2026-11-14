# Changelog fragments

One file per change. `make registry-generate` assembles them into the
`[Unreleased]` section of [`../CHANGELOG.md`](../CHANGELOG.md); a release
consumes them, and this file is what is left.

```bash
starter-kit/scripts/python.sh starter-kit/scripts/registry_tool.py new --registry changelog --title "<the change>"
make registry-generate
```

Write the bullets for someone who has the kit installed: what they will
observe after upgrading, not what was done here. The format — one
`## <category>` section per Keep a Changelog category, bullets only — is the
one the kit ships, described in
[`starter-kit/changelog.d/README.md`](../starter-kit/changelog.d/README.md).
