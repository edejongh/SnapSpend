#!/usr/bin/env python3
"""
Patch Mach-O fat binaries containing ar archives for iOS Simulator arm64 compatibility.
Changes LC_BUILD_VERSION platform from IOS(2) to IOSSIMULATOR(7) in place.
Handles BSD ar extended names (#1/N format).
"""
import struct
import sys
import os

FAT_MAGIC = 0xCAFEBABE
MH_MAGIC_64 = 0xFEEDFACF
AR_MAGIC = b'!<arch>\n'
LC_BUILD_VERSION = 0x32
PLATFORM_IOS = 2
PLATFORM_IOSSIMULATOR = 7


def patch_macho_in_buffer(data, offset, length):
    """Patch LC_BUILD_VERSION IOS->IOSSIMULATOR within a Mach-O region. Returns patch count."""
    if offset + 32 > len(data):
        return 0
    magic = struct.unpack_from('<I', data, offset)[0]
    if magic != MH_MAGIC_64:
        return 0
    ncmds = struct.unpack_from('<I', data, offset + 16)[0]
    cmd_offset = offset + 32  # sizeof(mach_header_64)
    patched = 0
    for _ in range(ncmds):
        if cmd_offset + 8 > offset + length:
            break
        cmd = struct.unpack_from('<I', data, cmd_offset)[0]
        cmdsize = struct.unpack_from('<I', data, cmd_offset + 4)[0]
        if cmdsize < 8:
            break
        if cmd == LC_BUILD_VERSION and cmd_offset + 12 <= offset + length:
            platform = struct.unpack_from('<I', data, cmd_offset + 8)[0]
            if platform == PLATFORM_IOS:
                struct.pack_into('<I', data, cmd_offset + 8, PLATFORM_IOSSIMULATOR)
                patched += 1
        cmd_offset += cmdsize
    return patched


def patch_ar_archive(data):
    """Patch all Mach-O members within an ar archive buffer. Returns patch count."""
    if data[:8] != AR_MAGIC:
        return 0
    patched = 0
    offset = 8  # skip !<arch>\n magic
    while offset + 60 <= len(data):
        # ar_hdr: name[16] date[12] uid[6] gid[6] mode[8] size[10] fmag[2]
        try:
            name = data[offset:offset + 16].decode('ascii', errors='replace')
            size_str = data[offset + 48:offset + 58].decode('ascii').strip()
            member_size = int(size_str)
        except (ValueError, UnicodeDecodeError):
            break

        member_data_start = offset + 60  # right after the 60-byte header

        # BSD ar extended name: "#1/N" means N bytes of filename are prepended to data
        actual_data_start = member_data_start
        actual_data_size = member_size
        if name.startswith('#1/'):
            try:
                name_len = int(name[3:].strip())
                actual_data_start = member_data_start + name_len
                actual_data_size = member_size - name_len
            except ValueError:
                pass

        if actual_data_start + actual_data_size <= len(data) and actual_data_size >= 32:
            patched += patch_macho_in_buffer(data, actual_data_start, actual_data_size)

        # Advance: member data is padded to even boundary
        next_offset = member_data_start + member_size
        if next_offset % 2 != 0:
            next_offset += 1
        offset = next_offset
    return patched


def patch_fat_binary(filepath):
    """Patch a fat binary (universal) containing ar archives or Mach-O slices."""
    with open(filepath, 'r+b') as f:
        data = bytearray(f.read())

    magic = struct.unpack_from('>I', data, 0)[0]  # fat magic is big-endian
    if magic != FAT_MAGIC:
        return 0

    nfat_arch = struct.unpack_from('>I', data, 4)[0]
    patched = 0
    for i in range(nfat_arch):
        arch_offset = 8 + i * 20
        offset = struct.unpack_from('>I', data, arch_offset + 8)[0]
        size = struct.unpack_from('>I', data, arch_offset + 12)[0]

        if offset + size > len(data):
            continue

        slice_magic_bytes = bytes(data[offset:offset + 8])
        if slice_magic_bytes == AR_MAGIC:
            # Static framework: ar archive — patch members in place
            slice_data = bytearray(data[offset:offset + size])
            count = patch_ar_archive(slice_data)
            if count:
                data[offset:offset + size] = slice_data
                patched += count
        elif len(data) >= offset + 4:
            slice_magic = struct.unpack_from('<I', data, offset)[0]
            if slice_magic == MH_MAGIC_64:
                count = patch_macho_in_buffer(data, offset, size)
                patched += count

    if patched:
        with open(filepath, 'wb') as f:
            f.write(data)
    return patched


if __name__ == '__main__':
    for path in sys.argv[1:]:
        if not os.path.exists(path):
            print(f'MISSING: {path}')
            continue
        count = patch_fat_binary(path)
        print(f"{'PATCHED(' + str(count) + ')' if count else 'skipped'}: {path}")
