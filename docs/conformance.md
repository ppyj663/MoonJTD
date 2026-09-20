# RFC 8927 conformance

MoonJTD checks its behavior against the canonical data files maintained with
the JSON Type Definition specification. The files are fetched from:

- Repository: `https://github.com/jsontypedef/json-typedef-spec`
- Revision: `71ca275847318717c36f5a2322a8061070fe185d`
- `tests/validation.json` SHA-256:
  `CA2EE582044051A690E0A5B79E81F26F4A51623D8A5B73F7A1D488B6E7B11994`
- `tests/invalid_schemas.json` SHA-256:
  `96AC0AB36D73389F2BCA1F64896213CF4D30BFC88BE8DE7B6F1A633CC07BE26D`

The upstream repository does not declare a license. MoonJTD therefore does not
vendor or redistribute either data file. `scripts/conformance.ps1` downloads
them on demand into the ignored `_build/conformance/` directory and rejects any
content whose digest differs from the reviewed revision.

Run the complete suite with:

```powershell
pwsh ./scripts/conformance.ps1
```

`cmd/conformance` parses every schema with the same public API used by library
consumers. It compares validation error pairs as an unordered multiset of RFC
6901 `instancePath` and `schemaPath` values, then verifies that every schema in
the invalid-schema corpus is rejected. The current pinned revision contains
316 validation cases and 49 invalid-schema cases; all 365 pass.

The corpus is also a required GitHub Actions check. Updating the revision
requires reviewing the upstream diff, replacing both expected hashes, running
the complete suite, and updating the counts in this document and the README.
