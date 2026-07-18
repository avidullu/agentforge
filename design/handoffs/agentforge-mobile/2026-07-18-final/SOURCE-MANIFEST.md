# Source manifest

**Acquired:** 2026-07-18

**Hash:** SHA-256 over exact source bytes

**Selected source:**
`App building assistance/Final-App building assistance/design_handoff_agentforge_mobile`

The selected source was read-only during intake. Only `tokens.json` was copied,
without transformation, as `tokens.visual-source.json`. Every binary below is
inventory-only and remains quarantined outside Git pending disclosure and
provenance clearance.

## Quarantined visual source inventory

| Source path | Bytes | Dimensions | SHA-256 |
|---|---:|---:|---|
| `screenshots/01-home.png` | 30,615 | 924×540 | `75DA598C80F58C6AFAFF05C76CD35A5F76CF1565AACA869BAC2250BF50CA21EB` |
| `screenshots/02-pr-conversation.png` | 29,705 | 924×540 | `50197E96AA096B5C775BE89E5B0268439F8662FECF45E57E10FECAE991C4C798` |
| `screenshots/03-pr-agent-context.png` | 33,922 | 924×540 | `468D8F603BEE2B613D7BAC6AF2B6597AED5149E15EF6FC402125186A8D2BF00F` |
| `screenshots/04-pr-commits.png` | 31,125 | 924×540 | `32476C524A8CA3503AA305D9BA48400CD357E29829DE0AADA8562FE8448E2ED0` |
| `screenshots/05-pr-files.png` | 30,030 | 924×540 | `79EE5F23E7D5D7FE51A247C9988E52ACB5B51FAED345EF8C9B0CAC9366192828` |
| `screenshots/06-summary.png` | 29,825 | 924×540 | `3E72D202CC9AAE0035EECA7F2B280632CC963A995842B9F085E2DCC30654E24E` |
| `screenshots/07-agents.png` | 27,635 | 924×540 | `279FDA578C61AE89CA62FE6E3D08C158F132A7BFA51D021CB3345E47136CF6FB` |
| `screenshots/08-agent-detail.png` | 30,425 | 924×540 | `B72C2573957C7F8F8144EB391507FEB04F5CD37048AAFF95201C72739E068ED8` |
| `screenshots/09-settings.png` | 32,380 | 924×540 | `E6838FCF6B18963611F67ED4D2BBF1839AF8C0C9469BD5FB514A8B3A9C1E7620` |
| `screenshots/10-add-agent-sheet.png` | 37,412 | 924×540 | `D83FF8023FC2075DC6B5368EF256A531B745D7797C89EBA2D8B52B2018F73E1C` |
| `screenshots/11-pairing.png` | 37,412 | 924×540 | `D83FF8023FC2075DC6B5368EF256A531B745D7797C89EBA2D8B52B2018F73E1C` |
| `mocks/UI Mock - Settings (Agents).png` | 110,568 | 784×1168 | `CE4361D09A6F7845187AC7964CF664A8EACC967F50C15F5C1037BAD6069CEAA3` |
| `mocks/UI Mock v2 - Home Dashboard.png` | 154,112 | 784×1168 | `5C99BC29A9F5538B371828D9B5860F4ECB130D1EB771ACE4CCBB1403934CFE01` |
| `mocks/UI Mock v2 - PR Detail Conversation.png` | 174,027 | 784×1168 | `B9D771A7224ED43698951CC075899028AD95330E4BED3E8FD649B41FF52FEC0C` |

`10-add-agent-sheet.png` and `11-pairing.png` are byte-identical. This is a
source defect, not deduplication performed during intake.

The three `mocks/*.png` entries contain JPEG payloads despite their `.png`
extensions. Screenshots `01`, `08`, and `09` visibly disclose private
namespace/host details. None of the binaries above is tracked by this intake.

## Tracked source datum

| Source path | Tracked path | Bytes | SHA-256 |
|---|---|---:|---|
| `tokens.json` | `tokens.visual-source.json` | 2,476 | `0BD39DB7EF066495EADD855172B21A058CB10E1982E603AD9E8E2D4CA067EC2D` |

## Quarantined source material

| Source path | Bytes | SHA-256 | Reason not tracked |
|---|---:|---|---|
| `AgentForge App.dc.html` | 63,583 | `906CEE7C5C61F528196CB0E2E5BD295EDA8001AB6C7AA4A525212595AEA7FFFA` | Private examples, unsafe actions, non-semantic prototype behavior |
| `support.js` | 66,404 | `C60C49083997F51A592DF118C0068475337AFD20B8CFD8E1CD9D5EB0C7E254F6` | Loads React/ReactDOM/Babel from `unpkg.com`; design runtime only |
| `ios-frame.jsx` | 16,326 | `41DB48D21F5AB75ADB0E00FF2830BBE5CB5135F895F9DD4D3DD2B70F8A45D971` | Presentation shell, not production Flutter code |
| `README.md` | 12,390 | `C75CE6E0DAEE36B8FC67C2976A526716BF212208E951AB76F51808AE6215730A` | Mixed visual intent, private defaults, and non-normative contracts |
| `CLAUDE-CODE-PROMPT.md` | 1,965 | `53EC9C642E2C2C0B4B31CB572561ABDC65AFDBCEDD9CD971A503912B57C51C78` | Wrong implementation stack and unsafe defaults |
| `mock-data.json` | 12,010 | `7CD77FB190698D20B0E053C67C9104594EABCDAC10D0F932F681E634FB669804` | Private examples and incomplete identities |
| `types.ts` | 3,364 | `FE2B288C60D2515BC9A5717CBB269C2044CA9E25736D952DE1E2908FB0C8BAFC` | Design-only model conflicts with normative app model |
| `docs/agentforge-mcp.md` | 2,871 | `83F5B02530CC430A5EADFEEF6FC7E05E3B6FFA4A94710DF81DF71AB0CE049E80` | Incorrectly claims compliant MCP; private endpoint |
| `docs/forgejo-api.md` | 2,517 | `FE944168DB146C01366E0D4F7F2DCFD5B1D3B9D341FBA19D218EB4A326F2D6EC` | Private host and unsafe dual-write guidance |

## Integrity check

From this package directory on PowerShell, assert the tracked token datum
against the recorded digest:

```powershell
$expected = "0BD39DB7EF066495EADD855172B21A058CB10E1982E603AD9E8E2D4CA067EC2D"
$actual = (Get-FileHash -Algorithm SHA256 `
  -LiteralPath .\tokens.visual-source.json).Hash
if ($actual -ne $expected) {
  throw "tokens.visual-source.json hash mismatch: $actual"
}
"tokens.visual-source.json: verified $actual"
```

The quarantined binaries are intentionally off-tree. Their digests can only be
rechecked against the selected owner-provided source folder; AF-006-A1 verified
all 24 source entries before publication.

The manifest records provenance, not licensing approval. Reuse beyond this
owner-provided repository remains gated by AF-008.
