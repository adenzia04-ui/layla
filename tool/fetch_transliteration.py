"""Replaces each verse's transliteration in assets/quran/quran.json with
quran.com's word-by-word one, joined — "Allāhu lā ilāha illā huwal-ḥayyul-
qayyūm" rather than the older "Allahu la ilaha illahuwa alhayyu alqayyoomu",
which spells ʿayn as "AA" and is hard to read aloud."""
import json, sys, time, urllib.request, urllib.parse
API = "https://api.quran.com/api/v4"
def get(path, **params):
    url = f"{API}/{path}?{urllib.parse.urlencode(params)}"
    for attempt in range(5):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "LaylaPro/1.0 (build tool)", "Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.load(r)
        except Exception as e:
            last = e; time.sleep(1.5 * (attempt + 1))
    raise SystemExit(f"failed: {url}: {last}")
p = sys.argv[1]
d = json.load(open(p, encoding="utf-8"))
for ch in d["chapters"]:
    n = ch["n"]; verses = d["verses"][str(n)]; page = 1; got = {}
    while True:
        r = get(f"verses/by_chapter/{n}", language="en", words="true",
                word_fields="transliteration", per_page=50, page=page)
        for v in r["verses"]:
            words = [w["transliteration"]["text"] for w in v["words"]
                     if w["char_type_name"] == "word" and w["transliteration"]["text"]]
            got[v["verse_number"]] = " ".join(words)
        if r["pagination"]["next_page"] is None: break
        page = r["pagination"]["next_page"]
    for v in verses:
        if got.get(v["a"]): v["tl"] = got[v["a"]]
    print(n, file=sys.stderr)
json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
print("done")
