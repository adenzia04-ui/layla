"""Builds assets/quran/quran.json from api.quran.com (v4).

One file, bundled, so the Qur'an never depends on a signal: every ayah's
Uthmani text, Saheeh International translation (resource 20), the English
transliteration (resource 57), and its page and juz. Chapters carry their
names and the pages they span. Tafsir (Ibn Kathir, 169) is not bundled —
it is fetched per ayah on demand and cached on the device.
"""
import json, sys, time, urllib.request, urllib.parse

API = "https://api.quran.com/api/v4"

def get(path, **params):
    url = f"{API}/{path}?{urllib.parse.urlencode(params)}"
    for attempt in range(5):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "LaylaPro/1.0 (build tool)", "Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.load(r)
        except Exception as e:  # noqa: BLE001
            time.sleep(1.5 * (attempt + 1))
            last = e
    raise SystemExit(f"failed: {url}: {last}")

chapters = get("chapters", language="en")["chapters"]
out = {"chapters": [], "verses": {}}
for ch in chapters:
    n = ch["id"]
    out["chapters"].append({
        "n": n,
        "name": ch["name_simple"],
        "arabic": ch["name_arabic"],
        "meaning": ch["translated_name"]["name"],
        "place": ch["revelation_place"],
        "count": ch["verses_count"],
        "pages": ch["pages"],
        "bismillah": ch["bismillah_pre"],
    })
    verses = []
    page = 1
    while True:
        d = get(f"verses/by_chapter/{n}", language="en", words="false",
                translations="20,57", fields="text_uthmani,page_number,juz_number",
                per_page=50, page=page)
        for v in d["verses"]:
            tr = {t["resource_id"]: t["text"] for t in v["translations"]}
            verses.append({
                "a": v["verse_number"],
                "ar": v["text_uthmani"],
                "en": tr.get(20, ""),
                "tl": tr.get(57, ""),
                "p": v["page_number"],
                "j": v["juz_number"],
            })
        if d["pagination"]["next_page"] is None:
            break
        page = d["pagination"]["next_page"]
    assert len(verses) == ch["verses_count"], (n, len(verses))
    out["verses"][str(n)] = verses
    print(n, ch["name_simple"], len(verses), file=sys.stderr)

dst = sys.argv[1]
with open(dst, "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
print("wrote", dst, sum(len(v) for v in out["verses"].values()), "verses")

# Footnote markers (<sup foot_note=…>1</sup>) and any other markup are
# stripped: the footnotes themselves are not bundled, so a bare superscript
# number would point at nothing.
