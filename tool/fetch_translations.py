"""Adds four more translations and each chapter's revelation order to
assets/quran/quran.json. Translations: Hilali & Khan (203), Pickthall (19),
Yusuf Ali (22), Abdel Haleem (85); Saheeh International (20) is already the
`en` field. Footnote markup is stripped as before."""
import html, json, re, sys, time, urllib.request, urllib.parse
API = "https://api.quran.com/api/v4"
IDS = [203, 19, 22, 85]
def get(path, **params):
    url = f"{API}/{path}?{urllib.parse.urlencode(params)}"
    for attempt in range(6):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "LaylaPro/1.0 (build tool)", "Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.load(r)
        except Exception as e:
            last = e; time.sleep(2 * (attempt + 1))
    raise SystemExit(f"failed: {url}: {last}")
tag = re.compile(r'<[^>]+>')
def clean(s):
    s = re.sub(r'<sup[^>]*>.*?</sup>', '', s)
    s = tag.sub('', s); s = html.unescape(s)
    return re.sub(r'[ \t]+', ' ', s).strip()
p = sys.argv[1]
d = json.load(open(p, encoding="utf-8"))
chapters = {c["id"]: c for c in get("chapters", language="en")["chapters"]}
for ch in d["chapters"]:
    ch["order"] = chapters[ch["n"]]["revelation_order"]
    n = ch["n"]; verses = d["verses"][str(n)]; page = 1; got = {}
    while True:
        r = get(f"verses/by_chapter/{n}", language="en", words="false",
                translations=",".join(map(str, IDS)), per_page=50, page=page)
        for v in r["verses"]:
            got[v["verse_number"]] = {str(t["resource_id"]): clean(t["text"]) for t in v["translations"]}
        if r["pagination"]["next_page"] is None: break
        page = r["pagination"]["next_page"]
    for v in verses:
        v["tr"] = got.get(v["a"], {})
        assert all(str(i) in v["tr"] and v["tr"][str(i)] for i in IDS), (n, v["a"], v["tr"].keys())
    print(n, file=sys.stderr)
json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
print("done")
