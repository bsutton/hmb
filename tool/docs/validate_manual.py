#!/usr/bin/env python3
"""Validate the staged manual; no network requests or GitBook build implied."""
from pathlib import Path
import hashlib
import json
import re
import struct
from urllib.parse import unquote, urlsplit

root = Path(__file__).resolve().parents[2]
manual = root / 'doc/manual-refresh'
errors = []
links = 0
pages = sorted(manual.rglob('*.md'))


def anchors(path):
    """GitHub-style anchors for the plain Markdown headings in this staging."""
    seen = {}
    result = set()
    for heading in re.findall(r'^#{1,6}\s+(.+?)\s*#*$', path.read_text(), re.M):
        slug = re.sub(r'[^\w\- ]', '', heading.lower()).replace(' ', '-')
        count = seen.get(slug, 0)
        seen[slug] = count + 1
        result.add(f'{slug}-{count}' if count else slug)
    return result


for page in pages:
    content = page.read_text()
    for target in re.findall(r'!\[[^\]]*\]\(([^\s)]+)', content):
        if urlsplit(target).scheme:
            errors.append(f'{page.relative_to(root)}: remote screenshot {target}')
    for target in re.findall(r'\]\(([^\s)]+)(?:\s+"[^"]*")?\)', content):
        url = urlsplit(target)
        if url.scheme or url.netloc:
            continue
        links += 1
        path = page.parent / unquote(url.path) if url.path else page
        if not path.exists():
            errors.append(f'{page.relative_to(root)}: missing {target}')
        elif url.fragment and path.suffix == '.md':
            if unquote(url.fragment) not in anchors(path):
                errors.append(f'{page.relative_to(root)}: missing fragment {target}')

manifest = json.loads((manual / 'images/manifest.json').read_text())['images']
pngs = {p.name: p for p in (manual / 'images').glob('*.png')}
if set(manifest) != set(pngs):
    errors.append('PNG inventory differs from image manifest')
for name, image in sorted(pngs.items()):
    data = image.read_bytes()
    if len(data) < 24 or data[:8] != b'\x89PNG\r\n\x1a\n':
        errors.append(f'Invalid PNG: {image}')
        continue
    dimensions = list(struct.unpack('>II', data[16:24]))
    record = manifest.get(name, {})
    for key, actual in [('sha256', hashlib.sha256(data).hexdigest()),
                        ('bytes', len(data)), ('dimensions', dimensions)]:
        if record.get(key) != actual:
            errors.append(f'{name}: manifest {key} mismatch')
    if dimensions != [860, 1864]:
        errors.append(f'{name}: unexpected capture dimensions {dimensions}')
    print(f'PNG {name}: {dimensions[0]}x{dimensions[1]}, {len(data)} bytes')

evidence = (manual / 'PRIVACY_EVIDENCE.md').read_text()
paths = set(re.findall(r'`((?:lib|assets)/[^`:]+)(?::\d+)?`', evidence))
for path in sorted(paths):
    if not (root / path).is_file():
        errors.append(f'Privacy source evidence missing: {path}')
print(f'Checked {len(pages)} Markdown files, {links} local links, '
      f'{len(paths)} source evidence paths and {len(pngs)} image hashes.')
if errors:
    print('\n'.join(errors))
    raise SystemExit(1)
print('PASS: local links/fragments, evidence paths and image manifest. '
      'Remote links and GitBook rendering require separate validation.')
