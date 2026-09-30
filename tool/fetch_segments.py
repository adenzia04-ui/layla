"""Builds assets/quran/timing/<voice>.json: when each word of each ayah is
heard, for the voices whose recordings match everyayah's.

Source: quran.com's recitation API, whose per-word segments were made on
the same files everyayah serves (byte-identical; Husary's is a 64 kbps
encode of the same take, aligned within ~40 ms). A raw segment is

    [from, to, start_ms, end_ms]

meaning quran.com words `from`..`to - 1` (0-based) are heard between the
two times. The output is dense and ordered, one entry per word of *our*
text (lone pause marks are not words), 1-based:

    {"2:255": [[1, 50, 980], [2, 990, 1770], ...], ...}

The raw data has faults, and every one is repaired here so the app never
has to sort, parse text, or guess. Where the data is silent, the other
seven voices decide: how long each of them takes over the same words,
scaled to this voice's own pace, is the best available evidence of where
an untimed word falls.

  * Numbers are parsed as numbers before anything is ordered. Sudais sends
    them all as strings; sorted as strings, "10" came before "2" and every
    long ayah of his was scrambled.
  * quran.com's word list is not ours: it joins "بَعْدَ مَا" (2:181, 8:6,
    13:37). Its words are aligned to ours by letters. Where the segments
    themselves count our words (37:130, "إِلْ يَاسِينَ"), they are taken as
    ours.
  * Some voices number a word that is not there at the opening letters of
    Yunus to Al-Hijr. An index no segment uses, pushing the count past the
    ayah's words, is dropped and the rest close up.
  * A segment spanning several words is shared among them in the other
    voices' rhythm (letters only when no other voice has them).
  * A word no segment covers — or whose segment is broken — is placed by
    trying the silence before it, the word before, the word after, and
    both, and keeping whichever gives every word the length the other
    voices give it.
  * A run of words at the end with no timing, or an ayah with none, is
    spread to the end of the actual recording, measured from the file.
  * A word lit far longer than any other voice takes over it is an
    untimed repeat of an earlier phrase; it is ended at a natural length,
    and the app lets the light go out rather than sit on the wrong word.
  * Every word is on screen for at least MIN_WORD ms, taken from the end
    of the word before. Times never run backwards; a word ends no later
    than the next begins.
  * Last, tool/timing_overrides.json replaces the few ayahs whose timings
    were measured by hand from the recording.

    python3 tool/fetch_segments.py              # fetch everything and build
    python3 tool/fetch_segments.py --raw DIR    # rebuild from DIR/<voice>.raw.json
                                                #   and DIR/qc_words.json
"""
import concurrent.futures as cf
import json
import math
import os
import re
import statistics
import subprocess
import sys
import time
import urllib.request

VOICES = {
    # voice: (quran.com recitation id, everyayah folder the app plays)
    'alafasy': (7, 'Alafasy_128kbps'),
    'abdulbasit': (2, 'Abdul_Basit_Murattal_192kbps'),
    'sudais': (3, 'Abdurrahmaan_As-Sudais_192kbps'),
    'husary': (6, 'Husary_128kbps'),
    'shuraym': (10, 'Saood_ash-Shuraym_128kbps'),
    'minshawi': (9, 'Minshawy_Murattal_128kbps'),
    'shatri': (4, 'Abu_Bakr_Ash-Shaatree_128kbps'),
    'rifai': (5, 'Hani_Rifai_192kbps'),
}

# Silence after the last word, typical of each voice's files (measured).
TAIL = {'alafasy': 576, 'abdulbasit': 491, 'sudais': 280, 'husary': 600,
        'shuraym': 323, 'minshawi': 593, 'shatri': 422, 'rifai': 311}

MARK = re.compile(r'^[؀-؟ۖ-ࣰٰۭ-ࣿ]+$')
NOT_LETTER = re.compile(
    r'[\sؐ-ًؚ-ٰٟۖ-ۭ࣓-ࣿـ]')
CACHE = os.path.expanduser('~/.cache/layla-segcache')
OVERRIDES = os.path.join('tool', 'timing_overrides.json')
MIN_WORD = 80
# A word this much longer than the others take over it, and this long, is
# an untimed repeat.
REPEAT_FACTOR = 4.0
REPEAT_MIN_MS = 8000


def words_of(arabic):
    return [w for w in arabic.split(' ') if w and not MARK.match(w)]


def skeleton(word):
    return NOT_LETTER.sub('', word)


def letters(word):
    return max(1, len(skeleton(word)))


# ── Word lists ────────────────────────────────────────────────────────────

def qc_to_ours(qc_words, ours):
    """For each quran.com word, the range [a, b) of our words it covers."""
    m, n = len(qc_words), len(ours)
    if m == n or m == 0:
        return [(i, i + 1) for i in range(n)]
    qs = [len(skeleton(w)) or 1 for w in qc_words]
    os_ = [len(skeleton(w)) or 1 for w in ours]
    scale = sum(qs) / sum(os_)
    bounds, acc = [], 0
    for q in qs:
        acc += q
        bounds.append(acc)
    owner, at = [], 0.0
    for length in os_:
        mid = (at + length / 2) * scale
        owner.append(next((k for k, b in enumerate(bounds) if mid < b), m - 1))
        at += length
    ranges = []
    for j in range(m):
        mine = [i for i in range(n) if owner[i] == j]
        if mine:
            ranges.append((mine[0], mine[-1] + 1))
        else:  # quran.com splits what we join: share the containing word
            mid = (sum(qs[:j]) + qs[j] / 2) / scale
            at, i = 0.0, 0
            while i < n - 1 and at + os_[i] <= mid:
                at += os_[i]
                i += 1
            ranges.append((i, i + 1))
    return ranges


def parse_segments(raw, m, n, log, tag):
    """(segments over the word list they count, whether that list is ours).

    Segments are numeric (from, to, start, end); broken ones are dropped.
    """
    segs = []
    for s in raw:
        try:
            fr, to, st, en = (int(float(x)) for x in s[-4:])
        except (TypeError, ValueError):
            continue
        if to <= fr or en <= st:
            continue
        segs.append([fr, to, st, en])
    if not segs:
        return [], False
    segs.sort(key=lambda s: (s[2], s[0]))
    # A first word "heard" for a few ms, then silence: a placeholder.
    first = segs[0]
    if (first[0] == 0 and first[1] == 1 and first[3] - first[2] <= 60 and
            len(segs) > 1 and segs[1][2] - first[3] > 100):
        segs = segs[1:]
    mx = max(s[1] for s in segs)
    ours = False
    if mx > m:
        if mx == n:
            ours = True  # the segments count our words (37:130)
        else:
            covered = set()
            for fr, to, _, _ in segs:
                covered.update(range(fr, to))
            unused = [i for i in range(mx) if i not in covered]
            if len(unused) > mx - m:
                log.append(f'{tag}: {len(unused)} unused indices for '
                           f'{mx - m} phantom(s); dropped the first')
            unused = unused[: mx - m]

            def shift(i):
                return i - sum(1 for u in unused if u < i)
            segs = [[shift(fr), shift(to), st, en] for fr, to, st, en in segs]
    limit = n if ours else m
    out = []
    for fr, to, st, en in segs:
        fr, to = max(0, fr), min(limit, to)
        if to > fr:
            out.append((fr, to, st, en))
    return out, ours


def first_pass(raw, qc_words, ours, log, tag):
    """What the segments say, before anything is guessed.

    span: per word (start, end) or None; exact: True where one segment
    times exactly that word; groups: segments shared by several words.
    """
    n = len(ours)
    qc = qc_words if qc_words else ours
    segs, counts_ours = parse_segments(raw, len(qc), n, log, tag)
    ranges = ([(i, i + 1) for i in range(n)] if counts_ours
              else qc_to_ours(qc, ours))
    span, exact, groups = [None] * n, [False] * n, []
    for fr, to, st, en in segs:
        a = min(r[0] for r in ranges[fr:to])
        b = max(r[1] for r in ranges[fr:to])
        ws = list(range(a, b))
        if len(ws) == 1:
            i = ws[0]
            if span[i] is None or st < span[i][0]:
                span[i], exact[i] = (st, en), True
            continue
        groups.append((ws, st, en))
        for i in ws:  # a placeholder until the rhythm is known
            if span[i] is None:
                span[i] = (st, en)
    return {'span': span, 'exact': exact, 'groups': groups}


# ── Evidence from the other voices ────────────────────────────────────────

class Rhythm:
    """How long words take, from every voice's exactly-timed words."""

    def __init__(self, first, text):
        self.first, self.text = first, text
        self.ms_per_letter, self.pace = {}, {}
        for v, ayahs in first.items():
            rates = []
            for k, fp in ayahs.items():
                for i, ok in enumerate(fp['exact']):
                    if ok:
                        s, e = fp['span'][i]
                        rates.append((e - s) / letters(text[k][i]))
            self.ms_per_letter[v] = statistics.median(rates)
        for v in first:
            ratios = []
            for k in list(first[v])[::7]:
                p = self._ayah_pace(v, k)
                if p:
                    ratios.append(p)
            self.pace[v] = statistics.median(ratios) if ratios else 1.0

    def others(self, v, k, i):
        durs = []
        for o, ayahs in self.first.items():
            if o == v:
                continue
            fp = ayahs[k]
            if fp['exact'][i]:
                s, e = fp['span'][i]
                durs.append(e - s)
        return statistics.median(durs) if durs else None

    def _ayah_pace(self, v, k):
        fp = self.first[v][k]
        ratios = []
        for i, ok in enumerate(fp['exact']):
            if ok:
                o = self.others(v, k, i)
                if o:
                    s, e = fp['span'][i]
                    ratios.append((e - s) / o)
        return statistics.median(ratios) if len(ratios) >= 2 else None

    def ayah_pace(self, v, k):
        return self._ayah_pace(v, k) or self.pace[v]

    def expected(self, v, k, i, pace):
        """How long word i should take in this voice, in ms."""
        o = self.others(v, k, i)
        if o is not None:
            return max(MIN_WORD, o * pace)
        return max(MIN_WORD, letters(self.text[k][i]) * self.ms_per_letter[v])


def spread(group, lo, hi, weights):
    out, at, total = {}, float(lo), sum(weights)
    for j, k in enumerate(group):
        share = (hi - lo) * weights[j] / total
        e = hi if j == len(group) - 1 else round(at + share)
        out[k] = (round(at), e)
        at += share
    return out


def misfit(placed, est):
    """How far a placement is from what the words should take."""
    err = 0.0
    for k, (s, e) in placed.items():
        d = max(1, e - s)
        err += abs(math.log(d / est[k]))
        if d < MIN_WORD:
            err += 2.0
    return err


# ── The recording ─────────────────────────────────────────────────────────

def duration_ms(folder, key):
    """Length of the app's own recording of [key]. Fails loudly: without it
    a trailing run cannot be placed honestly."""
    s, a = (int(x) for x in key.split(':'))
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, f'{folder}_{s:03d}{a:03d}.mp3')
    if not os.path.exists(path):
        url = f'https://everyayah.com/data/{folder}/{s:03d}{a:03d}.mp3'
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        data = urllib.request.urlopen(req, timeout=60).read()
        with open(path, 'wb') as fh:
            fh.write(data)
    out = subprocess.run(['afinfo', path], capture_output=True, text=True,
                         check=True).stdout
    m = re.search(r'estimated duration: ([\d.]+)', out)
    if not m:
        raise RuntimeError(f'no duration for {path}')
    return round(float(m.group(1)) * 1000)


# ── Building one ayah ─────────────────────────────────────────────────────

def build(v, k, fp, rhythm, lead, log):
    ours = rhythm.text[k]
    n = len(ours)
    if n == 0:
        return []
    pace = rhythm.ayah_pace(v, k)
    est = {i: rhythm.expected(v, k, i, pace) for i in range(n)}
    span = list(fp['span'])
    exact = fp['exact']

    # Segments shared by several words: in the others' rhythm.
    for ws, st, en in fp['groups']:
        # A word that also has a segment of its own keeps it; the shared
        # segment is split among the rest.
        free = [i for i in ws if not exact[i]]
        if not free:
            continue
        before = free[0] - 1
        after = free[-1] + 1
        if before >= 0 and exact[before]:
            st = max(st, span[before][1])
        if after < n and exact[after]:
            en = min(en, span[after][0])
        en = max(en, st + MIN_WORD * len(free))
        for i, sp in spread(free, st, en, [est[i] for i in free]).items():
            span[i] = sp

    # Words nothing covers.
    dur = None
    i = 0
    while i < n:
        if span[i] is not None:
            i += 1
            continue
        j = i
        while j < n and span[j] is None:
            j += 1
        run = list(range(i, j))
        prev = i - 1 if i > 0 else None
        nxt = j if j < n else None
        if nxt is None:
            dur = dur or duration_ms(VOICES[v][1], k)
            end_of_speech = dur - TAIL[v]
        cands = []
        lo_gap = span[prev][1] if prev is not None else min(
            lead, span[nxt][0] - MIN_WORD * len(run) if nxt is not None
            else lead)
        lo_gap = max(0, lo_gap)
        hi_gap = span[nxt][0] if nxt is not None else end_of_speech
        if hi_gap > lo_gap:
            cands.append((run, lo_gap, hi_gap))
        if prev is not None:
            hi = hi_gap if nxt is not None else max(span[prev][1],
                                                    end_of_speech)
            cands.append(([prev] + run, span[prev][0], hi))
        if nxt is not None:
            cands.append((run + [nxt], lo_gap, span[nxt][1]))
        if prev is not None and nxt is not None:
            cands.append(([prev] + run + [nxt], span[prev][0], span[nxt][1]))
        best = None
        for group, lo, hi in cands:
            if hi - lo < len(group):
                continue
            placed = spread(group, lo, hi, [est[g] for g in group])
            score = misfit(placed, est)
            if best is None or score < best[0]:
                best = (score, placed, group)
        if best is None:  # nowhere sensible: give each word MIN_WORD
            at = span[prev][1] if prev is not None else 0
            best = (0, {r: (at + MIN_WORD * q, at + MIN_WORD * (q + 1))
                        for q, r in enumerate(run)}, run)
        for g, sp in best[1].items():
            span[g] = sp
        if nxt is None:
            log.append(f'{v} {k}: words {best[2][0] + 1}-{j} spread to '
                       f'{best[1][best[2][-1]][1]} ms (recording {dur} ms)')
        i = j

    # Untimed repeats: a word far longer than the others take over it.
    for q in range(n):
        s, e = span[q]
        limit = est[q] * REPEAT_FACTOR
        if e - s > max(REPEAT_MIN_MS, limit):
            new_end = s + round(max(est[q] * 1.5, 600))
            log.append(f'{v} {k}: word {q + 1} held {e - s} ms against '
                       f'~{round(est[q])}; ended at {new_end - s} ms')
            span[q] = (s, new_end)

    # Order, minimum on-screen time, no overlap.
    starts = [span[q][0] for q in range(n)]
    for q in range(1, n):
        if starts[q] <= starts[q - 1]:
            starts[q] = starts[q - 1] + 1
    for q in range(1, n):
        window = (starts[q + 1] if q + 1 < n else span[q][1]) - starts[q]
        room = starts[q] - starts[q - 1] - MIN_WORD
        if window < MIN_WORD and room > 0:
            starts[q] -= min(MIN_WORD - window, room)
    out = []
    for q in range(n):
        e = span[q][1]
        if q + 1 < n:
            e = min(e, starts[q + 1])
        out.append([q + 1, starts[q], max(e, starts[q] + 1)])
    return out


# ── Fetching ──────────────────────────────────────────────────────────────

def get(url):
    err = None
    for i in range(5):
        try:
            req = urllib.request.Request(
                url, headers={'User-Agent': 'Mozilla/5.0',
                              'Accept': 'application/json'})
            return json.load(urllib.request.urlopen(req, timeout=60))
        except Exception as e:  # noqa: BLE001
            err = e
            time.sleep(2 * (i + 1))
    raise err


def fetch_raw(qid):
    out = {}
    for ch in range(1, 115):
        d = get(f'https://api.quran.com/api/v4/recitations/{qid}'
                f'/by_chapter/{ch}?fields=segments&per_page=300')
        for f in d['audio_files']:
            out[f['verse_key']] = {'url': f['url'],
                                   'segments': f.get('segments') or []}
    return out


def fetch_words():
    out = {}
    for ch in range(1, 115):
        page = 1
        while True:
            d = get(f'https://api.quran.com/api/v4/verses/by_chapter/{ch}'
                    f'?words=true&word_fields=text_uthmani&per_page=50'
                    f'&page={page}')
            for v in d['verses']:
                out[v['verse_key']] = [
                    w['text_uthmani']
                    for w in sorted(v['words'], key=lambda w: w['position'])
                    if w['char_type_name'] == 'word']
            page = d['pagination'].get('next_page')
            if not page:
                break
    return out


def main():
    quran = json.load(open('assets/quran/quran.json'))
    text = {f'{s}:{a["a"]}': words_of(a['ar'])
            for s, ayahs in quran['verses'].items() for a in ayahs}
    raw_dir = sys.argv[2] if len(sys.argv) > 2 and sys.argv[1] == '--raw' else None
    if raw_dir:
        raws = {v: json.load(open(f'{raw_dir}/{v}.raw.json')) for v in VOICES}
        qc_words = json.load(open(f'{raw_dir}/qc_words.json'))
    else:
        with cf.ThreadPoolExecutor(8) as ex:
            raws = dict(zip(VOICES, ex.map(lambda v: fetch_raw(VOICES[v][0]),
                                           VOICES)))
        qc_words = fetch_words()

    log = []
    first = {v: {k: first_pass(raws[v].get(k, {}).get('segments', []),
                               qc_words.get(k), text[k], log, f'{v} {k}')
                 for k in text}
             for v in VOICES}
    rhythm = Rhythm(first, text)
    overrides = json.load(open(OVERRIDES)) if os.path.exists(OVERRIDES) else {}

    for v in VOICES:
        starts = sorted(fp['span'][0][0] for fp in first[v].values()
                        if fp['exact'] and fp['exact'][0])
        lead = starts[len(starts) // 2]
        built = {k: build(v, k, first[v][k], rhythm, lead, log) for k in text}
        for k, entry in overrides.get(v, {}).items():
            built[k] = entry['words']
            log.append(f'{v} {k}: hand-timed override ({entry["why"]})')
        with open(f'assets/quran/timing/{v}.json', 'w') as fh:
            json.dump(built, fh, separators=(',', ':'))
        print(v, 'pace', round(rhythm.pace[v], 2), 'ms/letter',
              round(rhythm.ms_per_letter[v]), flush=True)
    with open(os.path.join('tool', 'timing_build.log'), 'w') as fh:
        fh.write('\n'.join(log) + '\n')
    print(len(log), 'notes in tool/timing_build.log')


if __name__ == '__main__':
    main()
