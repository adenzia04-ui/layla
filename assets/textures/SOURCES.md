# Earth textures

| File | Source | Licence |
|---|---|---|
| `earth_day.jpg` | NASA Visible Earth — Blue Marble Next Generation, December 2004 (`world.200412.3x5400x2700.jpg`) | Public domain |
| `earth_night.jpg` | NASA Earth Observatory — Earth at Night / VIIRS day-night band, 2012 (`dnb_land_ocean_ice.2012.3600x1800.jpg`) | Public domain |

Both downloaded directly from `eoimages.gsfc.nasa.gov`. NASA imagery is not
copyrighted and no attribution is legally required, but the credit line is
"NASA Visible Earth".

Day is downscaled 5400×2700 → 4096×2048. Night is kept at its native 3600×1800.

Both are JPEG. The night map was PNG at 1024×512 until the city lights were
judged too soft — at that size a single texel spanned roughly 40 km, so dense
regions smeared into a haze instead of resolving as points. JPEG was measured
against PNG on this exact image before switching: over open Pacific ocean both
encode to a mean of 5.00 with a maximum of 5 (no block noise in the dark), and
over India both give a mean of 5.02. Identical output for a third of the bytes.
