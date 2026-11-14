"""Export standalone support pages from the app's ES/EN/CA content. No publishing."""
from pathlib import Path
import ast, html, json, re
root = Path(__file__).resolve().parents[1]
source = (root / 'lib/support_page.dart').read_text(encoding='utf-8')
catalog = (root / 'lib/l10n/ui_messages.dart').read_text(encoding='utf-8')
translations = {}
# Dart string literals here are JSON-compatible double-quoted strings.
for match in re.finditer(r'("(?:\\.|[^"\\])*")\s*:\s*\[\s*("(?:\\.|[^"\\])*")\s*,\s*("(?:\\.|[^"\\])*")\s*,?\s*\]', catalog):
    es, en, ca = map(json.loads, match.groups())
    translations[es] = [es, en, ca]
literal = r"(\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*')"
sections = re.findall(r'_section\(\s*context,\s*' + literal + r',\s*' + literal + r',?\s*\)', source)
sections = [(ast.literal_eval(title), ast.literal_eval(body)) for title, body in sections]
if len(sections) < 11:
    raise SystemExit(f'Disclosure sections are missing: {len(sections)}')
privacy_end = next(i for i, (title, _) in enumerate(sections) if title == 'Condiciones de uso')
contacts = dict(re.findall(r"const (automotors\w+) = '([^']*)';", source))
e = html.escape
def translated(text, code):
    if code == 'es': return text
    return translations.get(text, [text, text, text])[1 if code == 'en' else 2]
def content(code, pairs):
    return ''.join(f'<section><h2>{e(translated(title,code))}</h2><p>{e(translated(body,code))}</p></section>' for title, body in pairs)
def page(name, title, pairs):
    blocks = []
    for code, label in [('es','Español'),('en','English'),('ca','Català')]:
        blocks.append(f'<article id="{code}" lang="{code}"><h1>{e(translated(title,code))}</h1><p class="date">AUTOMOTORS · 14/11/2026 · {label}</p><address>{e(contacts["automotorsLegalOwner"])}<br>{e(contacts["automotorsLegalAddress"])}<br><a href="mailto:{e(contacts["automotorsSupportEmail"])}">{e(contacts["automotorsSupportEmail"])}</a><br><a href="tel:+34{e(contacts["automotorsContactPhone"])}">{e(contacts["automotorsContactPhone"])}</a></address>{content(code,pairs)}</article>')
    css=':root{color-scheme:dark}*{box-sizing:border-box}body{margin:0;background:#0d0d0f;color:#f4f4f4;font:17px/1.7 system-ui,sans-serif}main,nav{max-width:860px;margin:auto;padding:24px}nav{display:flex;gap:18px;flex-wrap:wrap;border-bottom:1px solid #39352c}a{color:#e8c45c;overflow-wrap:anywhere}h1{font-size:clamp(28px,6vw,44px);line-height:1.2;color:#e8c45c}h2{font-size:21px;margin-top:32px}address{font-style:normal;padding:20px;background:#1a1a1d;border-radius:16px}.date{color:#aaa}article{padding:20px 0 48px;border-bottom:1px solid #39352c}p{overflow-wrap:anywhere}:target{scroll-margin-top:20px}'
    document='<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>AUTOMOTORS · '+e(title)+'</title><style>'+css+'</style></head><body><nav><a href="support.html">Soporte</a><a href="privacy.html">Privacidad</a><a href="terms.html">Condiciones</a><a href="#es">ES</a><a href="#en">EN</a><a href="#ca">CA</a></nav><main>'+''.join(blocks)+'<p><a href="https://apps.apple.com/account/subscriptions">Apple: gestionar suscripciones</a> · <a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/">Apple EULA</a></p></main></body></html>'
    (root / 'web' / name).write_text(document,encoding='utf-8')
page('privacy.html','Política de privacidad',sections[:privacy_end])
page('terms.html','Condiciones de uso',sections[privacy_end:])
page('support.html','Ayuda y privacidad',[sections[privacy_end],sections[-1]])
print('Exported support.html, privacy.html and terms.html in ES/EN/CA. Not published.')
