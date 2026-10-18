"""Check plugin UI/validator message coverage and translation placeholders."""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
literal = r'"(?:[^"\\]|\\.)*"'
catalog = root / 'addons/map_event_kit/core/localization.gd'
messages = {}
for line in catalog.read_text(encoding='utf-8').splitlines():
    match = re.fullmatch(r'\s*(' + literal + r'): (\[.*\]),?', line)
    if match:
        key, values = match.groups()
        key, values = json.loads(key), json.loads(values)
        assert key not in messages, f'Duplicate key: {key}'
        assert len(values) == 3 and all(values), f'Missing translation: {key}'
        for value in values:
            assert re.findall(r'%[sd]', key) == re.findall(r'%[sd]', value), key
        messages[key] = values

for relative in ['editor/event_editor.gd', 'core/event_data.gd', 'plugin.gd']:
    source = (root / 'addons/map_event_kit' / relative).read_text(encoding='utf-8')
    for match in re.finditer(literal, source):
        value = json.loads(match.group())
        if re.search(r'[\u4e00-\u9fff]', value):
            assert value in messages, f'Untranslated message in {relative}: {value}'
print(f'PASS: {len(messages)} messages, four languages, UI/validator coverage and placeholders')
