module mutagen.opus;

import std.base64 : Base64;
import std.stdio : File, SEEK_CUR, SEEK_SET;
import std.string : split, toUpper;

private uint readLE32(ubyte[4] data)
{
    return (cast(uint)data[0])
        | (cast(uint)data[1] << 8)
        | (cast(uint)data[2] << 16)
        | (cast(uint)data[3] << 24);
}

private uint readBe32(ubyte[] data, ref size_t pos)
{
    if (pos + 4 > data.length)
        return 0;
    uint ret = (cast(uint)data[pos + 0] << 24)
        | (cast(uint)data[pos + 1] << 16)
        | (cast(uint)data[pos + 2] << 8)
        | cast(uint)data[pos + 3];
    pos += 4;
    return ret;
}

struct Comment
{
    string vendor;
    string[string] tags;

    this(File file)
    {
        ubyte[4] lenBuf = file.rawRead(new ubyte[4]);
        uint vendorLen = readLE32(lenBuf);
        if (vendorLen > 0)
            vendor = cast(string)file.rawRead(new char[](vendorLen));

        lenBuf = file.rawRead(new ubyte[4]);
        uint commentCount = readLE32(lenBuf);

        foreach (i; 0..commentCount)
        {
            lenBuf = file.rawRead(new ubyte[4]);
            uint cLen = readLE32(lenBuf);
            if (cLen == 0)
                continue;
            string comment = cast(string)file.rawRead(new char[](cLen));
            string[] parts = comment.split('=');
            if (parts.length > 1)
                tags[parts[0].toUpper()] = parts[1];
        }
    }
}

final class Opus
{
public:
    string path;
    File file;
    Comment comment;
    string[string] tags;
    ubyte[] image;

    this(string path)
    {
        this.path = path;
        parse();
    }

private:
    void parse()
    {
        try
        {
            file = File(path, "rb");
            long fileSize = file.size();

            while (file.tell() + 27 < fileSize)
            {
                ubyte[4] magic = file.rawRead(new ubyte[4]);
                if (magic != cast(ubyte[])("OggS"))
                {
                    file.seek(-3, SEEK_CUR);
                    continue;
                }

                file.seek(22, SEEK_CUR);
                ubyte[1] segmentCount = file.rawRead(new ubyte[1]);
                ubyte[] segments = file.rawRead(new ubyte[](segmentCount[0]));

                uint pageDataSize = 0;
                foreach (s; segments)
                    pageDataSize += s;

                long pageDataStart = file.tell();
                if (pageDataSize < 8)
                {
                    file.seek(pageDataSize, SEEK_CUR);
                    continue;
                }

                ubyte[8] sig = file.rawRead(new ubyte[8]);
                bool isOpusTags = sig[0..8] == cast(ubyte[])("OpusTags");
                bool isVorbis = sig[0..7] == cast(ubyte[])("\x03vorbis");

                if (!isOpusTags && !isVorbis)
                {
                    file.seek(pageDataStart + pageDataSize, SEEK_SET);
                    continue;
                }

                if (isVorbis)
                    file.seek(pageDataStart + 7, SEEK_SET);

                comment = Comment(file);
                tags = comment.tags;
                if (string* picture = "METADATA_BLOCK_PICTURE" in tags)
                    image = decodePicture(*picture);

                file.close();
                return;
            }

            file.close();
        }
        catch (Exception)
        {
        }
    }

    ubyte[] decodePicture(string encoded)
    {
        ubyte[] ret;
        ubyte[] raw;
        try
        {
            raw = Base64.decode(encoded);
        }
        catch (Exception)
        {
            return ret;
        }

        if (raw.length < 32)
            return ret;

        size_t p = 0;
        uint ignored = readBe32(raw, p);

        uint mimeLen = readBe32(raw, p);
        if (p + mimeLen > raw.length)
            return ret;
        p += mimeLen;

        uint descLen = readBe32(raw, p);
        if (p + descLen > raw.length)
            return ret;
        p += descLen;

        ignored = readBe32(raw, p);
        ignored = readBe32(raw, p);
        ignored = readBe32(raw, p);
        ignored = readBe32(raw, p);

        uint imageLen = readBe32(raw, p);
        if (p + imageLen > raw.length)
            return ret;

        ret = raw[p..p + imageLen].dup;
        return ret;
    }
}

string[string] readOpusTags(string path)
{
    Opus opus = new Opus(path);
    return opus.tags;
}
