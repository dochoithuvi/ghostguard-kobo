#!/usr/bin/env python3
import csv, argparse, collections, pathlib

p=argparse.ArgumentParser(description='Summarize GhostGuard Kobo contacts.csv')
p.add_argument('csv_file')
a=p.parse_args()
path=pathlib.Path(a.csv_file)
rows=list(csv.DictReader(path.open(encoding='utf-8-sig', newline='')))
classes=collections.Counter(r.get('class','') for r in rows)
actions=collections.Counter(r.get('shadow_action','') for r in rows)
masks=collections.Counter(r.get('evidence_mask','') for r in rows)
print(f'contacts={len(rows)}')
print('classes=',dict(classes))
print('actions=',dict(actions))
print('top_evidence_masks=',masks.most_common(12))
