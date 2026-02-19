module mutagen.format.mp3.frame;

import std.stdio;
import std.string;
import std.variant;
import std.conv;

struct Frame
{
    uint size;
    Variant data;

    this(File file, ubyte ver, out bool valid)
    {
        valid = false;
        if (file.tell() + 10 > file.size())
            return;

        ubyte[10] frameHeader = file.rawRead(new ubyte[10]);
        if (frameHeader[0] == 0)
            return;

        string id = cast(string)frameHeader[0..4];
        if (ver == 4)
            size = (cast(uint)frameHeader[0] << 21)
                | (cast(uint)frameHeader[1] << 14)
                | (cast(uint)frameHeader[2] << 7)
                | cast(uint)frameHeader[3];
        else
            size = (cast(uint)frameHeader[4] << 24)
                | (cast(uint)frameHeader[5] << 16)
                | (cast(uint)frameHeader[6] << 8)
                | cast(uint)frameHeader[7];

        if (size == 0 || file.tell() + size > file.size())
            return;

        ubyte[] payload = file.rawRead(new ubyte[](size));
        valid = true;

        if (id == "APIC")
            data = ApicFrame(payload);
        else if (id == "TXXX")
            data = TxxxFrame(payload);
        else if (id == "PCNT")
            data = PcntFrame(payload);
        else if (id.length > 0 && id[0] == 'T')
            data = TextFrame(id, payload);
    }
}

struct TextFrame
{
    string id;
    string text;

    this(string id, ubyte[] data)
    {
        this.id = id;
        if (data.length < 2)
            return;

        ubyte encoding = data[0];
        if (encoding == 0 || encoding == 3)
            text = cast(string)data[1..$];
        else
        {
            foreach (i; 1..data.length)
            {
                if (data[i] != 0)
                    text ~= cast(char)data[i];
            }
        }
    }
}

struct ApicFrame
{
    ubyte[] image;

    this(ubyte[] data)
    {
        if (data.length < 4)
            return;

        size_t p = 1;
        while (p < data.length && data[p] != 0)
            p++;
        if (p >= data.length)
            return;
        p++;

        if (p >= data.length)
            return;
        p++;

        while (p < data.length && data[p] != 0)
            p++;
        if (p < data.length)
            p++;

        if (p < data.length)
            image = data[p..$].dup;
    }
}

struct TxxxFrame
{
    string desc;
    string value;

    this(ubyte[] data)
    {
        if (data.length < 2)
            return;
        ubyte encoding = data[0];
        size_t p = 1;
        size_t descEnd = p;

        if (encoding == 0 || encoding == 3)
        {
            while (descEnd < data.length && data[descEnd] != 0)
                descEnd++;
            desc = cast(string)data[p..descEnd];
            if (descEnd + 1 < data.length)
                value = cast(string)data[descEnd + 1..$];
        }
    }
}

struct PcntFrame
{
    int count;

    this(ubyte[] data)
    {
        if (data.length == 0)
            return;
        foreach (b; data)
            count = (count << 8) | b;
    }
}
