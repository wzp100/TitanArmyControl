#!/usr/bin/env python3
"""Exercise the installed HAL component using a quiet, generated stereo tone.

Never writes DDC. Restores the software volume/mute in a finally block.
Requires the Titan Army output to have been explicitly selected first.
"""
import argparse
import datetime
import json
import math
import pathlib
import struct
import subprocess
import tempfile
import time
import wave
from zoneinfo import ZoneInfo

ROOT = pathlib.Path(__file__).resolve().parents[1]
CLI = ROOT / 'build/TitanArmy.app/Contents/MacOS/titanarmyctl'
UID = 'TitanArmyAudio_Device_v1'


def command(*args):
    return subprocess.check_output([str(CLI), 'audio', *args], text=True)


def status():
    return json.loads(command('status'))


def proxy(data):
    return next(item for item in data['endpoints'] if item['uid'] == UID)


def require(value, message):
    if not value:
        raise RuntimeError(message)


parser = argparse.ArgumentParser()
parser.add_argument('--quit-panel', action='store_true', help='Also verify playback with the control panel closed.')
args = parser.parse_args()
initial = status()
original = proxy(initial)
require(original['default'], 'Select Titan Army Audio before running playback validation.')
require(original['alive'], 'The display audio route is not ready.')
report = {'time': datetime.datetime.now(ZoneInfo('Asia/Shanghai')).isoformat(), 'checks': []}
player = None


def record(name, data):
    report['checks'].append({'name': name, 'volume': data.get('volume'), 'muted': data.get('muted'),
                             'diagnostics': data.get('diagnostics', {})})
    print('PASS: ' + name, flush=True)


try:
    with tempfile.TemporaryDirectory(prefix='titanarmy-audio-test-') as directory:
        path = pathlib.Path(directory) / 'quiet-stereo.wav'
        rate = 48000
        with wave.open(str(path), 'wb') as stream:
            stream.setnchannels(2)
            stream.setsampwidth(2)
            stream.setframerate(rate)
            pcm = bytearray()
            for frame in range(rate * 12):
                # 2.5% full-scale, brief fades; this is a low-level test signal.
                fade = min(1, frame / (rate * .05), (rate * 12 - frame) / (rate * .05))
                l = int(32767 * .025 * fade * math.sin(2 * math.pi * 440 * frame / rate))
                r = int(32767 * .025 * fade * math.sin(2 * math.pi * 660 * frame / rate))
                pcm.extend(struct.pack('<hh', l, r))
            stream.writeframes(pcm)
        command('volume', '25')
        player = subprocess.Popen(['/usr/bin/afplay', str(path)])
        time.sleep(.6)
        low = proxy(status())
        require(abs(low['volume'] - .25) < .02, 'Native volume did not read back at 25%.')
        require(low['diagnostics']['sourceFrames'] > 0, 'Core Audio did not deliver PCM to the component.')
        require(low['diagnostics']['renderedFrames'] > 0, 'The component did not forward PCM to the display.')
        require(low['diagnostics']['peakL'] > 0 and low['diagnostics']['peakR'] > 0, 'Both output channels must carry audio.')
        record('software volume 25% / stereo forwarding', low)

        command('volume', '75')
        time.sleep(.25)
        high = proxy(status())
        require(abs(high['volume'] - .75) < .02, 'Native volume did not read back at 75%.')
        require(high['diagnostics']['renderedFrames'] > low['diagnostics']['renderedFrames'], 'The output stream stopped.')
        require(high['diagnostics']['peakL'] > low['diagnostics']['peakL'], 'Software gain did not increase.')
        record('software volume 75% / gain increase', high)

        command('mute', 'on')
        time.sleep(.25)
        silent = proxy(status())
        require(silent['muted'], 'System mute did not read back.')
        require(silent['diagnostics']['sourceFrames'] > high['diagnostics']['sourceFrames'], 'The source must still be playing during the mute check.')
        require(silent['diagnostics']['peakL'] == 0 and silent['diagnostics']['peakR'] == 0, 'Mute did not produce digital silence.')
        record('system mute produces digital silence', silent)

        command('mute', 'off')
        time.sleep(.25)
        resumed = proxy(status())
        require(resumed['diagnostics']['peakL'] > 0 and resumed['diagnostics']['peakR'] > 0, 'Unmute did not resume audio.')
        record('system unmute resumes audio', resumed)

        if args.quit_panel:
            expected = str(ROOT / 'build/TitanArmy.app/Contents/MacOS/TitanArmy')
            for line in subprocess.check_output(['ps', '-axo', 'pid=,args='], text=True).splitlines():
                parts = line.strip().split(None, 1)
                if len(parts) == 2 and (parts[1] == expected or parts[1].startswith(expected + ' ')):
                    subprocess.run(['/bin/kill', '-TERM', parts[0]], check=True)
            time.sleep(.3)
            independent = proxy(status())
            require(independent['diagnostics']['renderedFrames'] > resumed['diagnostics']['renderedFrames'], 'Playback must survive closing the app.')
            record('playback continues with the control panel closed', independent)

        command('disable')
        time.sleep(.2)
        disabled = proxy(status())
        require(not disabled['default'], 'Previous output was not restored.')
        record('restore previous sound output', disabled)
        command('enable')
        time.sleep(.2)
        enabled = proxy(status())
        require(enabled['default'] and enabled['systemDefault'], 'Display output was not restored for media and alerts.')
        require(abs(enabled['volume'] - .75) < .02, 'Software volume must survive output switching.')
        record('return to display / retain volume', enabled)
        report['success'] = True
except Exception as error:
    report['success'] = False
    report['error'] = str(error)
    raise
finally:
    if player is not None:
        player.terminate()
        player.wait(timeout=5)
    try:
        command('volume', str(original['volume'] * 100))
        command('mute', 'on' if original['muted'] else 'off')
    finally:
        destination = ROOT / 'build/Diagnostics'
        destination.mkdir(parents=True, exist_ok=True)
        (destination / 'SystemAudioValidation.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
        if args.quit_panel:
            subprocess.run(['open', str(ROOT / 'build/TitanArmy.app')])
