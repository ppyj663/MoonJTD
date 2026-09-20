# Third-party notices and source provenance

MoonJTD is an independent MoonBit implementation based on RFC 8927, JSON Type
Definition, published by the RFC Editor in November 2020. RFC text and examples
are specifications and reference material; MoonJTD does not copy an existing
implementation.

The conformance runner downloads `tests/validation.json` and
`tests/invalid_schemas.json` from the `jsontypedef/json-typedef-spec`
repository at commit `71ca275847318717c36f5a2322a8061070fe185d`. The upstream
repository does not declare a license, so these files are never vendored or
redistributed. They are downloaded into ignored build storage and accepted only
when their audited SHA-256 digests match. See `docs/conformance.md`.

The project is developed with AI assistance under human direction. All shipped
code is reviewed through tests, formatting, static checks, provenance review,
and public Git history. Generated and vendored files are identified explicitly
and excluded from authored-source metrics.
