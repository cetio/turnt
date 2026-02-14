module mutagen.mp3;

import std.conv : to;
import std.stdio : writeln, File, SEEK_CUR, SEEK_SET;
import std.string : toLower, indexOf;

int readId3PlayCount(string path)
{
    try
    {
        File f = File(path, "rb");
        ubyte[10] header;
        header = f.rawRead(new ubyte[10]);

        if (header[0..3] != cast(ubyte[])("ID3"))
            return readId3v1PlayCount(path);

        uint tagSize = syncsafeToInt(header[6..10]);
        size_t end = 10 + tagSize;
        ubyte ver = header[3];

        while (f.tell() + 10 < end)
        {
            ubyte[10] frameHeader;
            frameHeader = f.rawRead(new ubyte[10]);

            string frameId = cast(string)frameHeader[0..4];
            if (frameId[0] == 0)
                break;

            uint frameSize;
            if (ver == 4)
                frameSize = syncsafeToInt(frameHeader[4..8]);
            else
                frameSize = (cast(uint)frameHeader[4] << 24)
                    | (cast(uint)frameHeader[5] << 16)
                    | (cast(uint)frameHeader[6] << 8)
                    | cast(uint)frameHeader[7];

            if (frameSize == 0 || f.tell() + frameSize > end)
                break;

            if (frameId == "TXXX")
            {
                ubyte[] data = f.rawRead(new ubyte[frameSize]);
                string desc, val;
                parseTxxx(data, desc, val);
                if (desc.toLower() == "play_count" || desc.toLower() == "pcnt")
                    return val.to!int;
            }
            else if (frameId == "PCNT")
            {
                ubyte[] data = f.rawRead(new ubyte[frameSize]);
                return parsePopCount(data);
            }
            else
                f.seek(frameSize, SEEK_CUR);
        }
        f.close();
    }
    catch (Exception e)
        writeln("[mp3] Error reading ID3: "~e.msg);
    return 0;
}

void writeId3PlayCount(string path, int count)
{
    import std.file : read, write;
    ubyte[] data = cast(ubyte[])read(path);
    if (data.length < 10)
        return;

    if (data[0..3] != cast(ubyte[])("ID3"))
    {
        // No ID3v2 tag; prepend one with TXXX PLAY_COUNT
        ubyte[] tag = buildId3Tag(count);
        ubyte[] result = tag ~ data;
        write(path, result);
        writeln("[playcount] Wrote MP3 play count (new tag): "~count.to!string);
        return;
    }

    uint tagSize = syncsafeToInt(data[6..10]);
    ubyte ver = data[3];
    size_t pos = 10;
    size_t end = 10 + tagSize;

    while (pos + 10 < end)
    {
        string frameId = cast(string)data[pos..pos + 4];
        if (frameId[0] == 0)
            break;

        uint frameSize;
        if (ver == 4)
            frameSize = syncsafeToInt(data[pos + 4..pos + 8]);
        else
            frameSize = (cast(uint)data[pos + 4] << 24)
                | (cast(uint)data[pos + 5] << 16)
                | (cast(uint)data[pos + 6] << 8)
                | cast(uint)data[pos + 7];

        if (frameSize == 0 || pos + 10 + frameSize > end)
            break;

        if (frameId == "TXXX")
        {
            ubyte[] frameData = data[pos + 10..pos + 10 + frameSize];
            string desc, val;
            parseTxxx(frameData, desc, val);
            if (desc.toLower() == "play_count" || desc.toLower() == "pcnt")
            {
                // Replace frame data with new count
                ubyte[] newFrame = buildTxxxFrame("PLAY_COUNT", count.to!string);
                ubyte[] result;
                result ~= data[0..pos];
                result ~= newFrame;
                size_t afterFrame = pos + 10 + frameSize;
                if (afterFrame < data.length)
                    result ~= data[afterFrame..$];
                // Fix tag size
                uint newTagSize = cast(uint)(cast(long)result.length - 10 - (cast(long)data.length - cast(long)end));
                intToSyncsafe(newTagSize, result[6..10]);
                write(path, result);
                writeln("[playcount] Wrote MP3 play count: "~count.to!string);
                return;
            }
        }
        pos += 10 + frameSize;
    }

    // No existing PLAY_COUNT frame; insert one at current pos (before padding)
    ubyte[] newFrame = buildTxxxFrame("PLAY_COUNT", count.to!string);
    ubyte[] result;
    result ~= data[0..pos];
    result ~= newFrame;
    result ~= data[pos..$];
    // Fix tag size
    uint newTagSize = cast(uint)(tagSize + newFrame.length);
    intToSyncsafe(newTagSize, result[6..10]);
    write(path, result);
    writeln("[playcount] Wrote MP3 play count (inserted): "~count.to!string);
}

private void parseTxxx(ubyte[] data, out string desc, out string val)
{
    if (data.length < 2)
        return;
    ubyte encoding = data[0];
    size_t p = 1;
    size_t descEnd = p;

    if (encoding == 0 || encoding == 3) // Latin1 or UTF-8
    {
        while (descEnd < data.length && data[descEnd] != 0)
            descEnd++;
        desc = cast(string)data[p..descEnd];
        if (descEnd + 1 < data.length)
            val = cast(string)data[descEnd + 1..$];
    }
    else
    {
        desc = "";
        val = "";
    }
}

private int parsePopCount(ubyte[] data)
{
    if (data.length == 0)
        return 0;
    int result = 0;
    foreach (b; data)
        result = (result << 8) | b;
    return result;
}

private ubyte[] buildTxxxFrame(string desc, string val)
{
    ubyte[] payload;
    payload ~= 3; // UTF-8 encoding
    payload ~= cast(ubyte[])desc;
    payload ~= 0; // null terminator
    payload ~= cast(ubyte[])val;

    ubyte[] frame;
    frame ~= cast(ubyte[])("TXXX");
    uint size = cast(uint)payload.length;
    // ID3v2.3 format (big-endian)
    frame ~= cast(ubyte)((size >> 24) & 0xFF);
    frame ~= cast(ubyte)((size >> 16) & 0xFF);
    frame ~= cast(ubyte)((size >> 8) & 0xFF);
    frame ~= cast(ubyte)(size & 0xFF);
    frame ~= [cast(ubyte)0, cast(ubyte)0]; // flags
    frame ~= payload;
    return frame;
}

private ubyte[] buildId3Tag(int count)
{
    ubyte[] frame = buildTxxxFrame("PLAY_COUNT", count.to!string);
    uint tagSize = cast(uint)frame.length;

    ubyte[] header;
    header ~= cast(ubyte[])("ID3");
    header ~= [cast(ubyte)3, cast(ubyte)0]; // v2.3
    header ~= 0; // flags
    ubyte[4] ss;
    intToSyncsafe(tagSize, ss);
    header ~= ss;
    header ~= frame;
    return header;
}

private uint syncsafeToInt(ubyte[4] data)
{
    return (cast(uint)data[0] << 21)
        | (cast(uint)data[1] << 14)
        | (cast(uint)data[2] << 7)
        | cast(uint)data[3];
}

private uint syncsafeToInt(ubyte[] data)
{
    if (data.length < 4)
        return 0;
    return (cast(uint)data[0] << 21)
        | (cast(uint)data[1] << 14)
        | (cast(uint)data[2] << 7)
        | cast(uint)data[3];
}

private void intToSyncsafe(uint val, ubyte[] out_)
{
    out_[0] = cast(ubyte)((val >> 21) & 0x7F);
    out_[1] = cast(ubyte)((val >> 14) & 0x7F);
    out_[2] = cast(ubyte)((val >> 7) & 0x7F);
    out_[3] = cast(ubyte)(val & 0x7F);
}

private int readId3v1PlayCount(string)
{
    return 0;
}
