"""Import make/model names only from the official 2026 BOE reference.

Download https://www.boe.es/eli/es/o/2025/12/17/hac1501/dof/spa/html
to tool/catalog-cache/boe-2026.html first. No fiscal values are imported.
The fixed table boundaries are deliberately specific to this annual edition.
"""
import json
from html.parser import HTMLParser
from pathlib import Path
from import_vehicle_catalogue import display, key

ROOT = Path(__file__).resolve().parents[1]


class Tables(HTMLParser):
    def __init__(self):
        super().__init__()
        self.tables, self.table, self.row, self.cell = [], None, None, None

    def handle_starttag(self, tag, attrs):
        if tag == 'table': self.table = []
        elif tag == 'tr': self.row = []
        elif tag in ('td', 'th'): self.cell = []

    def handle_data(self, data):
        if self.cell is not None: self.cell.append(data)

    def handle_endtag(self, tag):
        if tag in ('td', 'th') and self.cell is not None:
            if self.row is not None: self.row.append(' '.join(''.join(self.cell).split()))
            self.cell = None
        elif tag == 'tr' and self.row is not None:
            if self.table is not None: self.table.append(self.row)
            self.row = None
        elif tag == 'table' and self.table is not None:
            self.tables.append(self.table)
            self.table = None


def main():
    parser = Tables()
    parser.feed((ROOT/'tool/catalog-cache/boe-2026.html').read_text(encoding='utf-8'))
    tables = parser.tables
    assert tables[0][0] == ['Marca: ABARTH']
    assert tables[111][0] == ['Marca: ZHIDOU']
    assert tables[112][0] == ['Marca: ACE']  # Motorhomes start here: excluded.
    assert tables[193][0][:2] == ['Fabricante/Marca', 'Modelo']
    references = {'car': {}, 'boat': {}}
    for table in tables[:112]:
        brand = display(table[0][0].removeprefix('Marca: '))
        references['car'].setdefault(brand, set()).update(
            row[0] for row in table[3:] if len(row) >= 9 and 0 < len(row[0]) <= 100)
    for table in tables[193:197]:
        for row in table:
            if len(row) < 10 or not row[0] or not row[1]: continue
            brand, model = display(row[0].rstrip('.')), row[1].rstrip('.')
            if 0 < len(brand) <= 80 and 0 < len(model) <= 100:
                references['boat'].setdefault(brand, set()).add(model)
    assert sum(map(len, references['car'].values())) > 50000
    assert sum(map(len, references['boat'].values())) > 3000
    for filename in ['vehicle_catalogue_seed.json', 'vehicle_catalogue.json']:
        path = ROOT/'assets'/filename
        data = json.loads(path.read_text(encoding='utf-8'))
        for category, brands in references.items():
            for brand, models in brands.items():
                canonical = next((b for b in data[category] if key(b) == key(brand)), brand)
                merged = {key(m): m for m in models}
                merged.update({key(m): m for m in data[category].get(canonical, [])})
                data[category][canonical] = sorted(merged.values(), key=key)
        path.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    print({c: {'brands':len(d), 'models_and_versions':sum(map(len,d.values()))} for c,d in data.items()})


if __name__ == '__main__': main()
