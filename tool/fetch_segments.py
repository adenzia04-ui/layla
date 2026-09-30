"""Fetches word timings for the voices whose files match everyayah's.

quran.com's recitation API carries per-word segments made on the same
recordings everyayah serves (verified byte for byte, except Husary, a
lower-bitrate encode of the same take). One JSON per voice:

    {"1:1": [[position, start_ms, end_ms], ...], ...}

    python3 tool/fetch_segments.py
"""
import concurrent.futures as cf
import json
import time
import urllib.request

VOICES = {
    'alafasy': 7, 'abdulbasit': 2, 'sudais': 3, 'husary': 6,
    'shuraym': 10, 'minshawi': 9, 'shatri': 4, 'rifai': 5,
}


def get(url):
    err = None
    for i in range(4):
        try:
            req = urllib.request.Request(
                url, headers={'User-Agent': 'Mozilla/5.0',
                              'Accept': 'application/json'})
            return json.load(urllib.request.urlopen(req, timeout=60))
        except Exception as e:  # noqa: BLE001
            err = e
            time.sleep(2 * (i + 1))
    raise err


def fetch(voice, qid):
    out = {}
    for ch in range(1, 115):
        d = get(f'https://api.quran.com/api/v4/recitations/{qid}'
                f'/by_chapter/{ch}?fields=segments&per_page=300')
        for f in d['audio_files']:
            segs = sorted(f.get('segments') or [], key=lambda s: s[1])
            out[f['verse_key']] = [[s[1], s[2], s[3]] for s in segs]
    with open(f'assets/quran/timing/{voice}.json', 'w') as fh:
        json.dump(out, fh, separators=(',', ':'))
    return voice, len(out)


with cf.ThreadPoolExecutor(4) as ex:
    for r in ex.map(lambda kv: fetch(*kv), VOICES.items()):
        print(r, flush=True)
