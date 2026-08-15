#!/usr/bin/env python3
"""
Fix ID3 tags encoded in Windows-1250/CP1250 that display as garbled characters.

Usage:
    python3 fix-id3-encoding.py /path/to/music/folder
    python3 fix-id3-encoding.py /mnt/nfs/share/**/*.mp3
"""

import sys
import os
import glob
import struct


def fix_id3(filepath):
    """Fix a single MP3 file's ID3 tags from CP1250 to UTF-8."""
    with open(filepath, 'rb') as f:
        data = bytearray(f.read())

    if not data[:3] == b'ID3':
        return False

    pos = 10  # skip header
    changed = False

    while pos < len(data) - 10:
        frame = data[pos:pos+4]
        if frame[0] == 0:  # padding
            break

        size = struct.unpack('>I', data[pos+4:pos+8])[0]
        if size == 0:
            break

        frame_data = data[pos+10:pos+10+size]

        if frame in [b'TIT2', b'TPE1', b'TPE2', b'TALB']:
            encoding = frame_data[0]
            text_bytes = frame_data[1:]

            if encoding == 1:  # UTF-16 with BOM
                if text_bytes[:2] == b'\xff\xfe':
                    text_bytes = text_bytes[2:]  # strip BOM
                    try:
                        text = text_bytes.decode('utf-16-le')
                        # Re-encode as latin-1 to get original CP1250 bytes
                        raw = text.encode('latin-1')
                        # Decode as CP1250
                        correct = raw.decode('cp1250')
                        if correct != text:
                            new_text = correct.encode('utf-8')
                            new_frame_data = bytes([3]) + new_text  # 3 = UTF-8 encoding
                            data[pos+10:pos+10+size] = new_frame_data
                            changed = True
                    except:
                        pass

        pos += 10 + size

    if changed:
        with open(filepath, 'wb') as f:
            f.write(data)
        return True
    return False


def fix_corrupted_tags(filepath):
    """Fix corrupted ID3 tags with extra junk entries."""
    from mutagen.id3 import ID3, TIT2, TPE1, TALB, Encoding

    try:
        tags = ID3(filepath)
        changed = False

        # Fix TIT2 - keep only first text entry
        tit2 = tags.get('TIT2')
        if tit2 and len(tit2.text) > 1:
            tags['TIT2'] = TIT2(encoding=Encoding.UTF8, text=[tit2.text[0]])
            changed = True

        # Fix TPE1 - keep only first text entry
        tpe1 = tags.get('TPE1')
        if tpe1 and len(tpe1.text) > 1:
            tags['TPE1'] = TPE1(encoding=Encoding.UTF8, text=[tpe1.text[0]])
            changed = True

        # Fix TALB - keep only first text entry
        talb = tags.get('TALB')
        if talb and len(talb.text) > 1:
            tags['TALB'] = TALB(encoding=Encoding.UTF8, text=[talb.text[0]])
            changed = True

        if changed:
            tags.save()
            return True
    except:
        pass
    return False


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <path-to-music-folder-or-file>")
        print(f"Example: {sys.argv[0]} /mnt/nfs/music/**/*.mp3")
        sys.exit(1)

    path = sys.argv[1]

    if os.path.isfile(path):
        files = [path]
    else:
        files = glob.glob(os.path.join(path, '**/*.mp3'), recursive=True)

    if not files:
        print("No MP3 files found.")
        sys.exit(1)

    count = 0
    for mp3 in files:
        try:
            if fix_id3(mp3) or fix_corrupted_tags(mp3):
                count += 1
                print(f"Fixed: {mp3}")
        except Exception as e:
            print(f"Error: {mp3}: {e}")

    print(f"\nFixed {count} files")


if __name__ == '__main__':
    main()
