module mutagen.opus;

import std.conv : to;
import std.stdio : writeln, File, SEEK_CUR, SEEK_SET;
import std.string : toLower, toUpper, split;

string[string] readOpusTags(string path)
{
    string[string] tags;
    try
    {
        File f = File(path, "rb");
        // Skip OggS pages to find OpusTags or vorbis comment header
        ubyte[4] magic;
        long fileSize = f.size();

        while (f.tell() + 27 < fileSize)
        {
            magic = f.rawRead(new ubyte[4]);
            if (magic != cast(ubyte[])("OggS"))
            {
                f.seek(-3, SEEK_CUR);
                continue;
            }

            // Skip rest of Ogg page header
            f.seek(22, SEEK_CUR); // version, type, granule, serial, seq, crc
            ubyte[1] nSegs;
            nSegs = f.rawRead(new ubyte[1]);
            ubyte[] segTable = f.rawRead(new ubyte[nSegs[0]]);

            uint pageDataSize = 0;
            foreach (s; segTable)
                pageDataSize += s;

            long pageDataStart = f.tell();
            if (pageDataSize < 8)
            {
                f.seek(pageDataSize, SEEK_CUR);
                continue;
            }

            ubyte[8] sig;
            sig = f.rawRead(new ubyte[8]);

            bool isOpusTags = (sig[0..8] == cast(ubyte[])("OpusTags"));
            bool isVorbis = (sig[0..7] == cast(ubyte[])("\x03vorbis"));

            if (!isOpusTags && !isVorbis)
            {
                f.seek(pageDataStart + pageDataSize, SEEK_SET);
                continue;
            }

            if (isVorbis)
                f.seek(pageDataStart + 7, SEEK_SET);

            // Read vendor
            ubyte[4] lenBuf;
            lenBuf = f.rawRead(new ubyte[4]);
            uint vendorLen = readLE32(lenBuf);
            if (vendorLen > 0 && f.tell() + vendorLen < fileSize)
                f.seek(vendorLen, SEEK_CUR);

            // Read comment count
            lenBuf = f.rawRead(new ubyte[4]);
            uint commentCount = readLE32(lenBuf);

            foreach (i; 0..commentCount)
            {
                if (f.tell() + 4 >= fileSize)
                    break;
                lenBuf = f.rawRead(new ubyte[4]);
                uint cLen = readLE32(lenBuf);
                if (cLen == 0 || f.tell() + cLen > fileSize)
                    break;
                string comment = cast(string)f.rawRead(new char[cLen]);
                string[] parts = comment.split('=');
                if (parts.length > 1)
                    tags[parts[0].toUpper()] = parts[1];
            }

            f.close();
            return tags;
        }
        f.close();
    }
    catch (Exception e)
        writeln("[opus] Error reading tags: "~e.msg);
    return tags;
}

private uint readLE32(ubyte[4] data)
{
    return (cast(uint)data[0])
        | (cast(uint)data[1] << 8)
        | (cast(uint)data[2] << 16)
        | (cast(uint)data[3] << 24);
}
