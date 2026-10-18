from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import json, hashlib

root = Path(__file__).resolve().parents[1]
dist = root/'dist'
dist.mkdir(exist_ok=True)
def add(z, p): z.write(p, p.relative_to(root).as_posix())
def source_files(folder):
    return [p for p in (root/folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.suffix != '.pyc']

for name, folders, extras in [
    ('map-event-kit-0.1.1-alpha-addon.zip',['addons','docs'],['README.md','LICENSE','CHANGELOG.md']),
    ('map-event-kit-0.1.1-alpha-demo.zip',['addons','docs','demo','tests','tools'],['project.godot','README.md','LICENSE','CHANGELOG.md','Launch Demo.cmd','Open Editor.cmd','.gitignore']),
]:
    with ZipFile(dist/name, 'w', ZIP_DEFLATED) as z:
        for folder in folders:
            for p in source_files(folder): add(z,p)
        for file in extras: add(z,root/file)
        if 'demo' in folders:
            for file in ['.gdignore','demo.png','editor.png','runtime-tests.json','editor-tests.json']:
                p=root/'artifacts'/file
                if p.exists(): add(z,p)
    with ZipFile(dist/name) as z:
        assert z.testzip() is None
        assert not any('.godot/' in n or n.startswith('dist/') for n in z.namelist())
    print(name, (dist/name).stat().st_size, 'bytes')
manifest={p.name:{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in dist.glob('*.zip')}
(dist/'checksums.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
