import json,re,os
from pathlib import Path
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
 browser=p.chromium.launch(executable_path=os.environ.get('CHROME_BINARY',r'C:\Program Files\Google\Chrome\Application\chrome.exe'),headless=True,args=['--enable-unsafe-swiftshader'])
 page=browser.new_page(viewport={'width':1200,'height':900},device_scale_factor=1)
 errors=[];external=[];console_errors=[]
 page.on('pageerror',lambda error:errors.append(str(error)))
 page.on('console',lambda message:console_errors.append(message.text) if message.type=='error' else None)
 def route(request):
  if request.request.url.startswith(('http://127.0.0.1:8787/','blob:','data:')):request.continue_()
  else:external.append(request.request.url);request.abort()
 page.route('**/*',route)
 try:
  page.goto('http://127.0.0.1:8787/',wait_until='networkidle',timeout=60000)
  page.wait_for_selector('flutter-view',state='attached')
  page.locator('flt-semantics-placeholder').evaluate('el => el.click()')
  page.get_by_role('button',name='Davom etish',exact=True).wait_for()
  page.screenshot(path='artifacts/qa/web-onboarding-desktop.png')
  page.get_by_role('textbox').first.fill('Web Menejer')
  page.get_by_role('textbox').first.press('Tab')
  for step,title in [(1,'O‘z portretingiz'),(2,'O‘yin falsafasi'),(3,'Klubingizni tanlang')]:
   page.get_by_role('button',name='Davom etish',exact=True).evaluate('el => el.click()')
   page.get_by_text(title,exact=True).wait_for()
   page.wait_for_timeout(200)
   page.screenshot(path=f'artifacts/qa/web-onboarding-step-{step+1}.png')
  page.get_by_text(re.compile('^MAVJUD TOP KLUBNI TANLASH')).evaluate('el => el.click()')
  page.get_by_role('button',name='REAL MADRIDNI BOSHQARISH',exact=True).evaluate('el => el.click()')
  page.get_by_text(re.compile('^Sezon markazi')).wait_for()
  page.screenshot(path='artifacts/qa/web-dashboard-desktop.png')
  page.get_by_role('button',name='Boshlash',exact=True).evaluate('el => el.click()')
  page.get_by_role('button',name='Tezkor',exact=True).wait_for()
  def minute():
   found=re.search(r"(\d+)'",page.locator('body').inner_text())
   assert found,page.locator('body').inner_text()
   return int(found.group(1))
  page.wait_for_timeout(1200)
  first=minute()
  page.wait_for_timeout(1400)
  second=minute()
  assert 1<=second-first<=3,(first,second)
  page.screenshot(path='artifacts/qa/web-match-live.png')
  page.get_by_role('button',name='Tezkor',exact=True).evaluate('el => el.click()')
  page.get_by_role('button',name='BOSHQARUV PANELIGA QAYTISH',exact=True).wait_for(timeout=30000)
  page.screenshot(path='artifacts/qa/web-match-result.png')
  page.get_by_role('button',name='BOSHQARUV PANELIGA QAYTISH',exact=True).evaluate('el => el.click()')
  page.get_by_role('button',name='Keyingi turga o‘tish',exact=True).evaluate('el => el.click()')
  page.wait_for_function("document.body.innerText.includes('2 / 14 tur')")
  page.set_viewport_size({'width':390,'height':844})
  page.wait_for_timeout(300)
  page.screenshot(path='artifacts/qa/web-dashboard-mobile.png')
  result={'passed':not errors and not external,'clockSamples':[first,second],'pageErrors':errors,'consoleErrors':list(dict.fromkeys(console_errors)),'externalRequests':sorted(set(external))}
  assert not errors,result
  assert not external,result
  Path('artifacts/qa/web-report.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
  print(json.dumps(result,ensure_ascii=False))
 except Exception:
  page.screenshot(path='artifacts/qa/web-failed.png')
  print('BODY',page.locator('body').inner_text()[:4000]);print('ERRORS',errors[:5],'CONSOLE',console_errors[:5],'EXTERNAL',sorted(set(external))[:5])
  raise
 finally:browser.close()
