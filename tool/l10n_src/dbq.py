import sqlite3, sys
sys.stdout.reconfigure(encoding="utf-8")
c = sqlite3.connect('file:C:/Users/user/Downloads/Telegram Desktop/2026.db?mode=ro', uri=True)
c.text_factory = lambda b: b.decode('utf-8', 'replace')
for q in sys.argv[1:]:
    for r in c.execute(q).fetchall():
        print(r)
    print('---')
