"""Builds the Google Play app bundle with invented names.

1. copies assets/data aside, 2. runs tool/fictionalize.py on it,
3. runs `flutter build appbundle --release`, 4. always puts the original
data back. The bundle lands in build/app/outputs/bundle/release/.

    python -I tool/build_play.py [extra flutter build arguments]
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / 'assets' / 'data'


def main():
    backup = Path(tempfile.mkdtemp(prefix='ftm27_data_')) / 'data'
    shutil.copytree(DATA, backup)
    print('original data backed up to', backup)
    try:
        subprocess.run([sys.executable, '-I', str(ROOT / 'tool' / 'fictionalize.py'), '--in-place'], check=True)
        flutter = shutil.which('flutter') or 'flutter'
        subprocess.run([flutter, 'build', 'appbundle', '--release', *sys.argv[1:]], cwd=ROOT, check=True)
    finally:
        shutil.rmtree(DATA)
        shutil.copytree(backup, DATA)
        print('original data restored')
    print('done:', ROOT / 'build' / 'app' / 'outputs' / 'bundle' / 'release' / 'app-release.aab')


if __name__ == '__main__':
    main()
