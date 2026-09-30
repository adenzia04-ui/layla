"""Builds assets/quran/glyphs.json from Quran Android's ayahinfo database.

    curl -L -o ayahinfo_1260.zip \
      https://android.quran.com/data/databases/ayahinfo/ayahinfo_1260.zip
    unzip ayahinfo_1260.zip
    python3 tool/build_glyphs.py ayahinfo_1260.db

The boxes are measured on the width_1260 page renders, the same images
bundled under assets/quran/pages, so they map straight onto them.
"""
import json
import sqlite3
import sys

db = sqlite3.connect(sys.argv[1] if len(sys.argv) > 1 else 'ayahinfo_1260.db')
pages = {}
rows = db.execute(
    'select page_number, line_number, sura_number, ayah_number, position, '
    'min_x, max_x, min_y, max_y from glyphs '
    'order by page_number, sura_number, ayah_number, position'
)
for p, line, s, a, pos, x0, x1, y0, y1 in rows:
    pages.setdefault(str(p), {}).setdefault(f'{s}:{a}', []).append(
        [pos, line, x0, x1, y0, y1]
    )
with open('assets/quran/glyphs.json', 'w') as f:
    json.dump({'width': 1260, 'height': 2038, 'pages': pages}, f,
              separators=(',', ':'))
print(f'{sum(len(v) for p in pages.values() for v in p.values())} glyphs '
      f'on {len(pages)} pages')
