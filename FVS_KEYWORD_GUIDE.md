# Important FVS Ontario Keywords

This is a practical shortlist of FVS keywords that most often affect a simulation. They are grouped by what they change, not by the order in the FVS Keyword Guide.

Use a keyword only when its value has a defensible silvicultural or calibration basis. Several of these controls can materially change yield projections.

## Stand Density And Mortality

| Keyword | What it changes | Use with care |
| --- | --- | --- |
| `SDIMAX` | Species-level maximum Stand Density Index (SDI). It influences density-related mortality, normal stocking, and some thinning calculations. | FVS provides Ontario species defaults when it is absent. For the planted spruce example, BP is 815 and SP is 861. Changing it can substantially change yields. |
| `BAMAX` | Maximum basal area and associated density/mortality pattern. | Do not combine it with `SDIMAX`: `BAMAX` causes FVS to ignore separate `SDIMAX` records. |
| `MORTMULT` | Multiplies predicted mortality for a chosen species and DBH range. | A multiplier of `1.1` increases modeled mortality by 10%. It remains active until replaced. It may not affect density-related mortality in every FVS variant. |
| `FIXMORT` | Specifies fixed mortality rather than relying on the normal mortality model. | Advanced calibration only. It can override mortality behavior controlled by `SDIMAX` and `BAMAX`. |

The R workflow currently exposes `SDIMAX` through `fvs_sdimax()` and `stand_modifiers` in `fvs_run()`.

## Growth And Productivity

| Keyword | What it changes | Use with care |
| --- | --- | --- |
| `SITECODE` | Site species and site index, which drive stand productivity. | This is one of the most important model inputs. The R workflow sets it from `site_species` and `site_index`. |
| `STDINFO` | Forest location/type and stand metadata used by the variant. | The R workflow currently uses forest type 915 for generated scenarios. |
| `HTGMULT` | Multiplies predicted large-tree height growth by species. | `0.9` means 90% of default height growth. It stays active until another `HTGMULT` replaces it. |
| `BAIMULT` | Modifies basal-area increment. | A high-leverage calibration control: changing basal-area increment changes many other predictions. |
| `FIXDG` | Specifies fixed diameter growth. | Advanced calibration only; avoid using it as a general scenario setting. |
| `FIXHTG` | Specifies fixed height growth. | Advanced calibration only; avoid using it as a general scenario setting. |

## Regeneration And Establishment

| Keyword | What it changes | Use with care |
| --- | --- | --- |
| `INVYEAR` | Establishes simulation year zero for the stand inventory. | The R workflow sets it from `inventory_year`. |
| `ESTAB` | Starts the FVS Ontario establishment/regeneration block. | It must be paired with the correct block-ending `END` keyword. |
| `PLANT` | Adds planted regeneration with a species code, density, and establishment details. | The R workflow writes this when `origin = "planted"`. |
| `NATURAL` | Adds natural regeneration with species and density. | The R workflow writes this when `origin = "natural"`. In this Ontario version, planted and natural regeneration currently produce the same modeled results. |
| `STOCKADJ` | Adjusts stocking in the establishment model. | The R workflow uses `-1.0`, matching the existing FVS Ontario examples. Change only with model-specific justification. |

## Timing And Treatments

| Keyword | What it changes | Use with care |
| --- | --- | --- |
| `TIMEINT` | Projection cycle length and cycle timing. | FVS treatments occur at the beginning of a cycle. Use a shorter or adjusted interval when a treatment must occur in a specific year. |
| `NUMCYCLE` | Number of projection cycles. | Together with `TIMEINT`, determines the projection duration. The R workflow derives it from `projection_years / time_step_years`. |
| `THINBBA` / `THINABA` | Thin from below / above to a residual basal-area target. | The targets apply only to the eligible DBH and height range. |
| `THINBTA` / `THINATA` | Thin from below / above to a residual stem-density target. | Same range limitation applies. |
| `THINDBH` | Thin a selected species and DBH class to a residual stem or basal-area target. | Appropriate for species- and size-specific removals; FVS removes uniformly within the eligible class. |
| `THINSDI` | Thin to a residual Stand Density Index target. | Depends directly on `SDIMAX`; do not interpret it independently of the maximum-density assumption. |
| `THINAUTO` | Applies automatic density control between management thresholds. | Requires careful interpretation of the SDI thresholds and can lead to repeated treatments. |
| `CUTEFF` | Fraction of a selected tree record removed by following thinning requests. | Useful when a treatment is deliberately partial. |
| `SPECPREF` / `TCONDMLT` | Adjust species or tree-condition removal priority for applicable thinning keywords. | They do not affect `THINDBH`; use them only when the thinning method uses FVS's removal-priority logic. |
| `MINHARV` | Rejects a thinning if it fails minimum removal-volume, basal-area, or other harvest criteria. | Helps stop operationally implausible small entries. |

The R workflow currently exposes the `THINBBA`, `THINABA`, `THINBTA`, and `THINATA` family through `fvs_thin()`.

## Volume Reporting And Outputs

| Keyword | What it changes | Use with care |
| --- | --- | --- |
| `VOLUME` | Merchantability limits and volume-calculation settings. | It changes reported merchantable volume, not biological tree growth. Keep limits consistent when comparing scenarios. |
| `TREELIST` | Writes detailed tree-list output. | Required by the R yield extractor, which uses `.lst` output for species-level results. |
| `CUTLIST` | Writes a list of trees removed by a treatment. | It is output, not a treatment prescription. |
| `ECHOSUM` | Requests a summary file. | Useful for checking a run, but `.sum` is not the source for species-level yield extraction. |

## Recommended Scenario Sequence

For most scenario analysis, change inputs in this order:

1. Confirm inventory, `SITECODE`, site index, regeneration density, and volume limits.
2. Define the treatment schedule and residual target.
3. Compare alternative `SDIMAX` values only as an explicit sensitivity analysis.
4. Use growth and mortality multipliers only when calibrating against observed data.
5. Keep the same output interval and merchantability limits across scenarios being compared.

The current R wrapper intentionally exposes only the safer scenario controls (`fvs_run()`, `fvs_thin()`, and `fvs_sdimax()`). Add specialized R helpers only after deciding exactly how a keyword should be parameterized and validated for the Ontario variant.
