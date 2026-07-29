import re, html, json
from collections import Counter

h = open('relics_list.html', encoding='utf-8').read()
parts = re.split(r'(?=<div class="relic-box")', h)
parts = [p for p in parts if p.startswith('<div class="relic-box"')]

def attr(p, a):
    m = re.search(a + r'="([^"]*)"', p)
    return m.group(1) if m else ''

def clean(s):
    s = re.sub(r'<br\s*/?>', ' ', s)
    s = re.sub(r'<[^>]+>', '', s)
    s = html.unescape(s)
    s = re.sub(r'\s+', ' ', s).strip()
    return s

rows = []
for p in parts:
    rarity = attr(p, 'data-rarity')
    char = attr(p, 'data-character')
    seq = attr(p, 'data-sequel')
    title = re.search(r'class="relic-title">.*?>([^<]+)</a>', p)
    if not title:
        title = re.search(r'class="relic-title">([^<]+)<', p)
    name = html.unescape(title.group(1)).strip() if title else '?'
    dm = re.search(r'<div class="relic-desc">(.*?)<div class="relic-flavor">', p, re.S)
    desc = clean(dm.group(1)) if dm else ''
    fm = re.search(r'<div class="relic-flavor">(.*?)</div>', p, re.S)
    flavor = clean(fm.group(1)) if fm else ''
    rows.append(dict(name=name, rarity=rarity, character=char, sequel=seq, desc=desc, flavor=flavor))

print('parsed', len(rows))
print('by sequel', Counter(r['sequel'] for r in rows))
print('by rarity', Counter(r['rarity'] for r in rows))
print('by character', Counter(r['character'] for r in rows))
json.dump(rows, open('parsed_relics.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
for r in rows[:3]:
    print(r)
