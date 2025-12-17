- Always favor domain-restricted, tightly-defined data types instead of
  open-ended types like Strings. Define enums, structs, and other custom types
  as needed.
- Always favor strict parsing and throwing errors over leniency.
- Use Location instead of latitude/longitude and/or altitude.
- When NASR objects reference each other, make sure NASRData properly sets the
  associated references.
- Do not create lists of symbols in Swift-DocC comments. Instead, create a
  @DocumentationExtension that categorizes the symbols.
- Always capitalize acronyms, even in variable and field names, unless doing so
  conflicts with a type name. "id" is not an acronym. Consecutive acronyms
  should be separated by an underscore (e.g., `VOR_DME`), but acronym + word
  does not need an underscore (e.g., `TWEBSynopses`).
- When building enums or other custom types, you MUST use live data from a
  distribution.zip downloaded by SwiftNASR_E2E to discover all possible values.
  Do NOT rely on mock data in Tests/SwiftNASRTests/Resources/MockDistribution -
  mock data is incomplete and may contain incorrect values. Run SwiftNASR_E2E
  to download real FAA data, then extract and examine the relevant files to
  find all actual values that appear in production data.
- Also use the layout TXT files in the live distribution to interpret data
  values.
- Make NASR model properties read-only. If they cannot be read-only for
  internal reasons, use private(set).
- Always use curly quotes and String(localized:) for user-facing strings such
  as from error descriptions. Your tokenizer cannot tell the difference between
  straight and curly quotes so you may need to use a tool like sed to verify.
- Use UInt (and its sized variants) for values that are never negative.
- Make the properties of NASR models read-only (let). If they must be read-write
  for initialization purposes, make them private(set) vars.
