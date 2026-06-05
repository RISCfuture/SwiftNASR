- Use Location instead of latitude/longitude and/or altitude.
- When NASR objects reference each other, make sure NASRData properly sets the
  associated references.
- Make NASR model properties read-only (`let`). If they must be read-write for
  initialization purposes, use `private(set)`.
- When building enums or other custom types, you MUST use live data from a
  distribution.zip downloaded by SwiftNASR_E2E to discover all possible values.
  Do NOT rely on mock data in Tests/SwiftNASRTests/Resources/MockDistribution -
  mock data is incomplete and may contain incorrect values. Run SwiftNASR_E2E
  to download real FAA data, then extract and examine the relevant files to
  find all actual values that appear in production data.
- Also use the layout TXT files in the live distribution to interpret data values.
