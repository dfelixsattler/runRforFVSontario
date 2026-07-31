# Packaged Inventory Examples

These are existing FVS Ontario tree-list inventories intended for testing the R workflow with the modern ESSA Ontario executable. They contain tree records, not complete stand metadata; choose an inventory year, site species, and site index appropriate to the stand being modeled.

| File | Stand type | Validated test site species and index |
| --- | --- | --- |
| `RedOak.tre` | Red oak and maple mixed hardwood | Red oak, $16\ \mathrm{m}$ |
| `Tolhwd.tre` | Sugar-maple tolerant hardwood | Sugar maple, $14\ \mathrm{m}$ |
| `WhPine.tre` | White-pine/red-pine mixedwood | White pine, $15\ \mathrm{m}$ |
| `Mxwd.tre` | Aspen-spruce-jack-pine boreal mixedwood | Trembling aspen, $18\ \mathrm{m}$ |

All four files completed a 10-year smoke test with `C:/fvs_essa/FVSon.exe` through `run_fvs_ontario_scenario()`.