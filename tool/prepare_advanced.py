#!/usr/bin/env python3
"""Resolve ALL-324/325/329/330 fixtures for the real package-media runner.

No downloads. Generate discs/HDR10+ with the format pack's
build_advanced.py; download licensed DV samples into external/ALL-325.
"""
import argparse, fnmatch, hashlib, importlib.util, json, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--pack', type=pathlib.Path, default=ROOT.parent/'materials/playback')
p.add_argument('--out', type=pathlib.Path, required=True)
p.add_argument('--only', default='', help='comma separated sample id globs')
a = p.parse_args()
spec = importlib.util.spec_from_file_location('prepare', ROOT/'tool/prepare_samples.py')
prepare = importlib.util.module_from_spec(spec); spec.loader.exec_module(prepare)
pack = a.pack.resolve(); advanced = pack/'fixtures/advanced'
items = [('hdr10plus', 'ALL-324', advanced/'hdr10plus.mp4', None)]
for profile in ('P5','P8.1','P8.4'):
    items.append((f'dovi-{profile.lower()}', 'ALL-325', pack/'external/ALL-325'/f'Test Jellyfin 1080p DV {profile}.mp4', None))
items += [('bluray','ALL-329',advanced/'bluray/BDMV/STREAM/00000.m2ts', 'bluray'),
          ('dvd','ALL-330',advanced/'dvd/VIDEO_TS/VTS_01_1.VOB','dvd')]
items.append(('web-baseline','ALL-331',pack/'fixtures/common/baseline.mp4',None))
samples = []
patterns = [x for x in a.only.split(',') if x]
records = json.loads((pack/'advanced-manifest.json').read_text())
for name, issue, path, disc in items:
    if patterns and not any(fnmatch.fnmatch(f'advanced-{name}', pat) for pat in patterns):
        continue
    record = records.get(issue, {})
    files = record.get('files', []) if disc else [record, *record.get('files', [])]
    for f in files:
        if f.get('sha256') and (disc or f.get('path') == str(path.relative_to(pack))):
            assert prepare.sha256(pack/f['path']) == f['sha256'], f"checksum mismatch: {f['path']}"
    info = prepare.probe(path)
    uri = f'{disc}://{advanced}/{name}' if disc else str(path)
    entry = dict(id=f'advanced-{name}', linear=[issue], ext=disc or 'mp4',
                 path=uri, status='ok', probe=info, note=name,
                 sha256=prepare.sha256(path), bytes=path.stat().st_size,
                 expect=dict(video=True,audio=bool(info['audio_codec']),seek=True,
                             duration_ms=info['duration_ms'],play_to_end=info['duration_ms'] <= 20000,
                             frame=None,tone_hz=440 if disc else None))
    if issue == 'ALL-325':
        reference = record.get('color_reference')
        if not reference:
            raise SystemExit('Generate/download the official SDR colour reference first')
        assert prepare.sha256(pack/reference['path']) == reference['sha256']
        entry['expect'].update(mean_chroma=reference['chroma'],chroma_tolerance=0.12)
    samples.append(entry)
a.out.parent.mkdir(parents=True,exist_ok=True)
if not samples:
    raise SystemExit('No advanced samples selected')
a.out.write_text(json.dumps({'samples':samples},indent=2)+'\n')
print(a.out)
