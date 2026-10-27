"""Release smoke test with a fresh browser profile (does not touch user saves)."""
import json
import os
import re
from pathlib import Path
from playwright.sync_api import sync_playwright

expected_version = re.search(r'^version:\s*([\d.]+)', Path('pubspec.yaml').read_text(encoding='utf-8'), re.M).group(1)

with sync_playwright() as p:
    browser = p.chromium.launch(
        executable_path=os.environ.get('CHROME_BINARY', r'C:\Program Files\Google\Chrome\Application\chrome.exe'),
        headless=True, args=['--enable-unsafe-swiftshader'])
    page = browser.new_page(viewport={'width': 1200, 'height': 900})
    errors = []
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.add_init_script("localStorage.setItem('flutter.ftm27_lang', JSON.stringify('uz'))")
    try:
        page.goto('http://127.0.0.1:8787/', wait_until='networkidle', timeout=60000)
        page.locator('flutter-view').wait_for(state='attached')
        placeholder = page.locator('flt-semantics-placeholder')
        if placeholder.count():
            placeholder.evaluate('e => e.click()')
        page.wait_for_timeout(1200)
        welcome = page.get_by_role('button', name='Boshladik', exact=True)
        if welcome.count():
            welcome.evaluate('e => e.click()')
            page.wait_for_timeout(500)
        page.get_by_role('textbox').first.fill('Web Manager')
        page.get_by_role('textbox').first.press('Tab')
        page.get_by_text(re.compile('^Millatingiz')).evaluate('e => e.click()')
        page.get_by_text('O‘zbekiston', exact=True).last.evaluate('e => e.click()')
        for title in ['O‘z portretingiz', 'O‘yin falsafasi', 'Klubingizni tanlang']:
            page.get_by_role('button', name='Davom etish', exact=True).evaluate('e => e.click()')
            page.get_by_text(title, exact=True).wait_for()
        page.get_by_text(re.compile('^MAVJUD TOP KLUBNI TANLASH')).evaluate('e => e.click()')
        page.wait_for_timeout(500)
        page.get_by_role('button', name=re.compile('^ARSENALNI BOSHQARISH')).evaluate('e => e.click()')
        profile = page.get_by_role('button', name=re.compile('^Menejer profili'))
        profile.wait_for()
        page.screenshot(path=f'artifacts/qa/release-{expected_version}-dashboard-light.png')
        profile.evaluate('e => e.click()')
        page.get_by_role('button', name='Qorong‘i rejim', exact=True).evaluate('e => e.click()')
        page.get_by_role('button', name='Yorug‘ rejim', exact=True).wait_for()
        page.wait_for_timeout(350)
        page.screenshot(path=f'artifacts/qa/release-{expected_version}-manager-dark.png')
        assert page.evaluate("JSON.parse(localStorage.getItem('flutter.darkMode'))") is True
        page.get_by_role('button', name='Back', exact=True).evaluate('e => e.click()')
        page.get_by_text('Jamoa', exact=True).evaluate('e => e.click()')
        page.get_by_role('button', name='Rating', exact=False).first.evaluate('e => e.click()')
        page.get_by_role('button', name='Holat', exact=False).first.wait_for()
        page.screenshot(path=f'artifacts/qa/release-{expected_version}-tactics-condition.png')
        page.set_viewport_size({'width':390, 'height':844})
        page.wait_for_timeout(400)
        page.screenshot(path=f'artifacts/qa/release-{expected_version}-tactics-mobile-dark.png')
        page.get_by_text('Boshqaruv', exact=True).evaluate('e => e.click()')
        page.get_by_role('button', name='Boshlash', exact=True).evaluate('e => e.click()')
        page.get_by_text(re.compile('Asosiy tarkib va taktika bilan')).evaluate('e => e.click()')
        page.wait_for_timeout(1700)
        page.screenshot(path=f'artifacts/qa/release-{expected_version}-match-mobile-dark.png')
        assert not errors, errors
        version = page.request.get('http://127.0.0.1:8787/version.json').json()
        assert version['version'] == expected_version, version
        Path(f'artifacts/qa/release-{expected_version}-web-report.json').write_text(
            json.dumps({'passed': True, 'version': version, 'darkModePersisted': True,
                        'lineupConditionToggle': True, 'liveMatch': True, 'pageErrors': errors}, indent=2), encoding='utf-8')
        print(f'Release {expected_version} web smoke test passed.')
    except Exception:
        Path('artifacts/qa/release-web-dom.txt').write_text(page.locator('body').inner_text(), encoding='utf-8')
        page.screenshot(path='artifacts/qa/release-web-failed.png')
        raise
    finally:
        browser.close()
